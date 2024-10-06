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
      String userId = reservation['userId'] ?? '';
      String orderId = reservation['orderId'] ?? '';
      String itemLabel = reservation['itemLabel'] ?? 'No Label';
      String userName = reservation['userName'] ?? 'Unknown User';
      String itemSize = reservation['itemSize'] ?? 'Unknown Size';

      // Calculate total quantity for bulk orders
      int totalQuantity = 0;
      if (reservation.containsKey('items') && reservation['items'] is List) {
        List orderItems = reservation['items'];
        totalQuantity = orderItems.fold<int>(0, (sum, item) => sum + (item['quantity'] ?? 0));
      }

      if (userId.isEmpty || orderId.isEmpty || totalQuantity <= 0) {
        throw Exception('Invalid reservation data: userId or orderId is missing, or quantity is zero.');
      }

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

      String mainCategory = reservation['category'] ?? 'Unknown Category';
      if (mainCategory == 'college_items' || mainCategory == 'senior_high_items') {
        mainCategory = 'Uniform';
      }

      DocumentSnapshot inventoryDoc = await _firestore
          .collection('inventory_stock')
          .doc(itemLabel)
          .get();

      if (!inventoryDoc.exists) {
        throw Exception('Item not found in inventory');
      }

      Map<String, dynamic> inventoryData = inventoryDoc.data() as Map<String, dynamic>;
      int currentStock = inventoryData['stockQuantity'] ?? 0;

      if (currentStock < totalQuantity) {
        throw Exception('Not enough stock available for item "$itemLabel". Only $currentStock in stock, but $totalQuantity requested.');
      }

      int updatedStock = currentStock - totalQuantity;

      await _firestore.collection('inventory_stock').doc(itemLabel).update({
        'stockQuantity': updatedStock,
      });

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('orders')
          .doc(orderId)
          .update({'status': 'approved'});

      // Assuming that the first item is representative of the bulk order
      await _firestore.collection('approved_items').add({
        'reservationDate': reservationDate,
        'approvalDate': FieldValue.serverTimestamp(),
        'itemLabel': itemLabel,
        'itemSize': itemSize,
        'quantity': totalQuantity, // Use total quantity here
        'name': userName,
        'pricePerPiece': reservation['price'] != null ? reservation['price'] / totalQuantity : 0,
      });

      await _firestore.collection('admin_transactions').add({
        'cartItemRef': orderId,
        'category': mainCategory,
        'courseLabel': reservation['courseLabel'] ?? 'Unknown Course',
        'itemLabel': itemLabel,
        'itemSize': itemSize,
        'quantity': totalQuantity, // Use total quantity here
        'studentNumber': reservation['studentId'] ?? 'Unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
        'userName': userName,
      });

      await _sendNotificationToUser(userId, userName, reservation);

      setState(() {
        allPendingReservations.removeWhere((element) => element['orderId'] == orderId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation for $itemLabel approved successfully! Stock has been updated.'),
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
