import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReservationListPage extends StatefulWidget {
  @override
  _ReservationListPageState createState() => _ReservationListPageState();
}

class _ReservationListPageState extends State<ReservationListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> allPendingReservations = [];
  Set<String> expandedBulkOrders = Set<String>();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllPendingReservations();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllPendingReservations() async {
    List<Map<String, dynamic>> pendingReservations = [];
    setState(() {
      isLoading = true;
    });

    QuerySnapshot usersSnapshot = await _firestore.collection('users').get();

    for (var userDoc in usersSnapshot.docs) {
      String userName = userDoc['name'] ?? 'Unknown User';
      String studentId = (userDoc.data() as Map<String, dynamic>).containsKey('studentId')
          ? userDoc['studentId']
          : 'Unknown ID';

      QuerySnapshot ordersSnapshot = await _firestore
          .collection('users')
          .doc(userDoc.id)
          .collection('orders')
          .get();

      for (var orderDoc in ordersSnapshot.docs) {
        Map<String, dynamic> reservationData = orderDoc.data() as Map<String, dynamic>;

        reservationData['orderId'] = orderDoc.id;
        reservationData['userName'] = userName;
        reservationData['studentId'] = studentId;
        reservationData['userId'] = userDoc.id;
        reservationData['category'] = reservationData['category'] ?? 'Unknown Category';
        reservationData['itemLabel'] = reservationData['itemLabel'] ?? 'No Label';
        reservationData['itemSize'] = reservationData['itemSize'] ?? 'Unknown Size';
        reservationData['courseLabel'] = reservationData['courseLabel'] ?? 'Unknown Course';

        if (reservationData.containsKey('items') && reservationData['items'] is List) {
          List<dynamic> orderItems = reservationData['items'];

          double totalOrderPrice = 0.0;
          for (var item in orderItems) {
            int itemQuantity = item['quantity'] ?? 1;
            double itemPrice = item['price'] ?? 0.0;
            double itemTotalPrice = itemQuantity * itemPrice;
            item['totalPrice'] = itemTotalPrice.toStringAsFixed(2);

            totalOrderPrice += itemTotalPrice;
          }

          reservationData['totalOrderPrice'] = totalOrderPrice.toStringAsFixed(2);
        } else {
          int quantity = reservationData['quantity'] ?? 1;
          double pricePerPiece = reservationData['price'] ?? 0.0;
          double totalPrice = quantity * pricePerPiece;
          reservationData['totalPrice'] = totalPrice.toStringAsFixed(2);
        }
        pendingReservations.add(reservationData);
      }
    }

    pendingReservations.sort((a, b) {
      Timestamp aTimestamp = a['orderDate'] != null && a['orderDate'] is Timestamp
          ? a['orderDate']
          : Timestamp.now();
      Timestamp bTimestamp = b['orderDate'] != null && b['orderDate'] is Timestamp
          ? b['orderDate']
          : Timestamp.now();
      return bTimestamp.compareTo(aTimestamp);
    });

    setState(() {
      allPendingReservations = pendingReservations;
      isLoading = false;
    });
  }

  Future<void> _approveReservation(Map<String, dynamic> reservation) async {
    try {
      // Extract common reservation data
      String userId = reservation['userId'] ?? '';
      String orderId = reservation['orderId'] ?? '';
      String userName = reservation['userName'] ?? 'Unknown User';
      String studentId = reservation['studentId'] ?? 'Unknown ID';

      // Validate userId and orderId
      if (userId.isEmpty || orderId.isEmpty) {
        throw Exception('Invalid reservation data: userId or orderId is missing.');
      }

      // Fetch the order document to validate its existence
      DocumentSnapshot orderDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      Timestamp reservationDate = orderDoc['orderDate'] ?? Timestamp.now();

      // Handle bulk orders or individual items
      List<dynamic> orderItems = reservation['items'] ?? [];
      if (orderItems.isEmpty) {
        throw Exception('No items found in the reservation');
      }

      for (var item in orderItems) {
        // Extract item-specific data
        String itemLabel = (item['itemLabel'] ?? 'No Label').trim(); // Keeping the original case and just trimming whitespace
        String itemSize = (item['itemSize'] ?? 'Unknown Size').trim();
        String mainCategory = (item['category'] ?? '').trim().toLowerCase(); // Lowercase for mainCategory, assuming standardization
        String subCategory = (item['courseLabel'] ?? '').trim(); // Use courseLabel to navigate to the right sub-collection
        int quantity = item['quantity'] ?? 0;

        // Validate item data
        if (itemLabel.isEmpty || mainCategory.isEmpty || subCategory.isEmpty || quantity <= 0) {
          throw Exception('Invalid item data: missing item label, category, subCategory, or quantity.');
        }

        // Debugging logs for reservation item details
        print('Processing item with category: $mainCategory, subCategory: $subCategory, itemLabel: "$itemLabel", itemSize: $itemSize');

        // Query the inventory collection, matching itemLabel in the reservation with label in inventory
        QuerySnapshot inventoryQuery = await _firestore
            .collection('inventory_stock')
            .doc(mainCategory)  // Either 'college_items' or 'senior_high_items'
            .collection(subCategory)  // e.g., 'IT&CPE'
            .where('label', isEqualTo: itemLabel)  // Correctly match the itemLabel with the inventory 'label' field
            .get();

        if (inventoryQuery.docs.isEmpty) {
          // Detailed error log to identify if the itemLabel is the issue
          print('Item with label "$itemLabel" not found in inventory for category "$mainCategory" under "$subCategory".');
          throw Exception('Item "$itemLabel" not found in inventory for category "$mainCategory" under "$subCategory".');
        }

        DocumentSnapshot inventoryDoc = inventoryQuery.docs.first;
        Map<String, dynamic> inventoryData = inventoryDoc.data() as Map<String, dynamic>;

        // Log the inventory document details to verify fields
        print('Inventory data retrieved: ${inventoryData.toString()}');

        // Check if sizes exist in inventory data and validate the size
        if (!inventoryData.containsKey('sizes') || !inventoryData['sizes'].containsKey(itemSize)) {
          print('Size "$itemSize" not found for item "$itemLabel" in inventory.');
          throw Exception('Size "$itemSize" not found for item "$itemLabel" in inventory.');
        }

        int currentStock = inventoryData['sizes'][itemSize]['quantity'] ?? 0;
        if (currentStock < quantity) {
          print('Not enough stock available for item "$itemLabel" size "$itemSize". Only $currentStock in stock, but $quantity requested.');
          throw Exception('Not enough stock available for item "$itemLabel" size "$itemSize". Only $currentStock in stock, but $quantity requested.');
        }

        int updatedStock = currentStock - quantity;

        // Update the specific size's quantity in the inventory
        await _firestore.collection('inventory_stock')
            .doc(mainCategory)  // Either 'college_items' or 'senior_high_items'
            .collection(subCategory)  // e.g., 'IT&CPE'
            .doc(inventoryDoc.id)  // The ID of the document found through the query
            .update({
          'sizes.$itemSize.quantity': updatedStock,
        });

        // Log successful stock update
        print('Stock updated for item "$itemLabel" size "$itemSize". New quantity: $updatedStock');

        // Add to approved items collection
        await _firestore.collection('approved_items').add({
          'reservationDate': reservationDate,
          'approvalDate': FieldValue.serverTimestamp(),
          'itemLabel': itemLabel,
          'itemSize': itemSize,
          'quantity': quantity,
          'name': userName,
          'pricePerPiece': item['price'],
        });

        // Add transaction to admin records
        await _firestore.collection('admin_transactions').add({
          'cartItemRef': orderId,
          'category': mainCategory,
          'courseLabel': subCategory,
          'itemLabel': itemLabel,
          'itemSize': itemSize,
          'quantity': quantity,
          'studentNumber': studentId,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': userId,
          'userName': userName,
        });
      }

      // Update the order status to approved
      await _firestore.collection('users').doc(userId).collection('orders').doc(orderId).update({'status': 'approved'});

      // Send notification to user
      await _sendNotificationToUser(userId, userName, reservation);

      // Delete the order document now that it has been successfully processed
      await _firestore.collection('users').doc(userId).collection('orders').doc(orderId).delete();

      // Update local state
      setState(() {
        allPendingReservations.removeWhere((element) => element['orderId'] == orderId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation for ${reservation['items'].map((e) => e['itemLabel']).join(", ")} approved successfully! Stock has been updated and order deleted.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error approving reservation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve reservation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendNotificationToUser(String userId, String userName, Map<String, dynamic> reservation) async {
    try {
      List<dynamic> orderItems = reservation['items'] ?? [];
      List<Map<String, dynamic>> orderSummary = [];

      if (orderItems.isNotEmpty) {
        for (var item in orderItems) {
          int quantity = item['quantity'] ?? 1;
          double price = item['price'] ?? 0.0;

          double pricePerPiece = price / quantity;
          double totalPrice = pricePerPiece * quantity;

          orderSummary.add({
            'itemLabel': item['itemLabel'],
            'itemSize': item['itemSize'],
            'quantity': quantity,
            'pricePerPiece': pricePerPiece,
            'totalPrice': totalPrice,
          });
        }
      } else {
        int quantity = reservation['quantity'] ?? 1;
        double price = reservation['price'] ?? 0.0;

        double pricePerPiece = price / quantity;
        double totalPrice = pricePerPiece * quantity;

        orderSummary.add({
          'itemLabel': reservation['itemLabel'],
          'itemSize': reservation['itemSize'],
          'quantity': quantity,
          'pricePerPiece': pricePerPiece,
          'totalPrice': totalPrice,
        });
      }

      String notificationMessage;
      if (orderSummary.length > 1) {
        notificationMessage =
        'Your bulk reservation (${orderSummary.length} items) has been approved.';
      } else {
        notificationMessage =
        'Your reservation for ${orderSummary[0]['itemLabel']} (${orderSummary[0]['itemSize']}) has been approved.';
      }
      CollectionReference notificationsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications');

      await notificationsRef.add({
        'title': 'Reservation Approved',
        'message': notificationMessage,
        'orderSummary': orderSummary,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unread',
      });

      print('Notification sent to user: $userName');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Reservation List"),
        centerTitle: true,
      ),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(),
      )
          : Scrollbar(
        controller: _verticalController,
        thumbVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          controller: _verticalController,
          scrollDirection: Axis.vertical,
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            interactive: true,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width,
                ),
                child: DataTable(
                  columnSpacing: 16.0,
                  columns: [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Student ID')),
                    DataColumn(label: Text('Item Label')),
                    DataColumn(label: Text('Size')),
                    DataColumn(label: Text('Quantity')),
                    DataColumn(label: Text('Price per Piece')),
                    DataColumn(label: Text('Total Price')),
                    DataColumn(label: Text('Order Date')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: allPendingReservations.expand<DataRow>((reservation) {
                    final List orderItems = reservation['items'] ?? [];
                    bool isExpanded = expandedBulkOrders.contains(reservation['orderId']);

                    // Calculate the total quantity and total price for the bulk order
                    double totalQuantity = orderItems.fold<double>(0, (sum, item) => sum + (item['quantity'] ?? 1));
                    double totalPrice = orderItems.fold<double>(
                        0, (sum, item) => sum + ((item['quantity'] ?? 1) * (item['price'] ?? 0.0)));

                    // Main row for the bulk order
                    List<DataRow> rows = [
                      DataRow(
                        key: ValueKey(reservation['orderId']),
                        cells: [
                          DataCell(Text(reservation['userName'] ?? 'Unknown User')),
                          DataCell(Text(reservation['studentId'] ?? 'Unknown ID')),
                          DataCell(Row(
                            children: [
                              if (orderItems.length > 1)
                                IconButton(
                                  icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                                  onPressed: () {
                                    setState(() {
                                      if (isExpanded) {
                                        expandedBulkOrders.remove(reservation['orderId']);
                                      } else {
                                        expandedBulkOrders.add(reservation['orderId']);
                                      }
                                    });
                                  },
                                ),
                              Text(orderItems.length > 1
                                  ? 'Bulk Order (${orderItems.length} items)'
                                  : (orderItems.isNotEmpty ? orderItems[0]['itemLabel'] ?? 'No label' : 'No label')),
                            ],
                          )),
                          DataCell(Text('')), // Size not applicable for the bulk order summary
                          DataCell(Text('$totalQuantity')), // Total quantity for the bulk order
                          DataCell(Text('')), // Price per piece not applicable for the bulk order summary
                          DataCell(Text('₱${totalPrice.toStringAsFixed(2)}')), // Total price for the bulk order
                          DataCell(Text(
                            reservation['orderDate'] != null && reservation['orderDate'] is Timestamp
                                ? DateFormat('yyyy-MM-dd HH:mm:ss').format(
                              (reservation['orderDate'] as Timestamp).toDate(),
                            )
                                : 'No Date Provided',
                          )),
                          DataCell(
                            ElevatedButton(
                              onPressed: () {
                                _approveReservation(reservation);
                              },
                              child: Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ];

                    // Expanded rows for each item in the bulk order
                    if (isExpanded) {
                      rows.addAll(orderItems.map<DataRow>((item) {
                        return DataRow(
                          key: ValueKey('${reservation['orderId']}_${item['itemLabel']}'),
                          cells: [
                            DataCell(Text('')), // Empty cell for indentation
                            DataCell(Text('')),
                            DataCell(Text(item['itemLabel'] ?? 'No label')),
                            DataCell(Text(item['itemSize'] ?? 'No Size')),
                            DataCell(Text('${item['quantity'] ?? 1}')), // Quantity per item
                            DataCell(Text('₱${(item['price'] ?? 0).toStringAsFixed(2)}')), // Price per piece per item
                            DataCell(Text('₱${((item['price'] ?? 0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}')), // Total price for each item
                            DataCell(Text('')), // Empty cell for order date
                            DataCell(Text('')), // Empty cell for action
                          ],
                        );
                      }).toList());
                    }
                    return rows;
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}