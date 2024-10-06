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
  Set<String> expandedBulkOrders = Set<String>(); // Track expanded orders
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  bool isLoading = true; // Loading flag

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

    // Set loading to true while fetching data
    setState(() {
      isLoading = true;
    });

    // Fetch all users
    QuerySnapshot usersSnapshot = await _firestore.collection('users').get();

    for (var userDoc in usersSnapshot.docs) {
      String userName = userDoc['name'] ?? 'Unknown User';
      String studentId = (userDoc.data() as Map<String, dynamic>).containsKey('studentId')
          ? userDoc['studentId']
          : 'Unknown ID';

      // Fetch orders from the user's "orders" subcollection
      QuerySnapshot ordersSnapshot = await _firestore
          .collection('users')
          .doc(userDoc.id)
          .collection('orders')
          .get();

      for (var orderDoc in ordersSnapshot.docs) {
        Map<String, dynamic> reservationData = orderDoc.data() as Map<String, dynamic>;

        // Add document ID to reservation data for reference
        reservationData['orderId'] = orderDoc.id;
        reservationData['userName'] = userName;
        reservationData['studentId'] = studentId;
        reservationData['userId'] = userDoc.id;

        // Check if the order is a bulk order or a single item
        if (reservationData.containsKey('items') && reservationData['items'] is List) {
          // Bulk order case
          List<dynamic> orderItems = reservationData['items'];

          double totalOrderPrice = 0.0;
          for (var item in orderItems) {
            int itemQuantity = item['quantity'] ?? 1; // Default to 1 if quantity is missing
            double itemPrice = item['price'] ?? 0.0; // Default to 0 if price is missing

            // Calculate total price for the item
            double itemTotalPrice = itemQuantity * itemPrice;
            item['totalPrice'] = itemTotalPrice.toStringAsFixed(2); // Add total price to the item data

            // Accumulate the total order price
            totalOrderPrice += itemTotalPrice;
          }

          reservationData['totalOrderPrice'] = totalOrderPrice.toStringAsFixed(2);
        } else {
          // Single item order case
          int quantity = reservationData['quantity'] ?? 1; // Default to 1 if quantity is missing
          double pricePerPiece = reservationData['price'] ?? 0.0; // Default to 0 if price is missing

          // Calculate the total price for the reservation
          double totalPrice = quantity * pricePerPiece;
          reservationData['totalPrice'] = totalPrice.toStringAsFixed(2);
        }

        // Add the reservation to the list
        pendingReservations.add(reservationData);
      }
    }

    // Sort the orders by orderDate in descending order
    pendingReservations.sort((a, b) {
      Timestamp aTimestamp = a['orderDate'] != null && a['orderDate'] is Timestamp
          ? a['orderDate']
          : Timestamp.now();
      Timestamp bTimestamp = b['orderDate'] != null && b['orderDate'] is Timestamp
          ? b['orderDate']
          : Timestamp.now();
      return bTimestamp.compareTo(aTimestamp);
    });

    // Update the state after fetching is complete
    setState(() {
      allPendingReservations = pendingReservations;
      isLoading = false; // Set loading to false when data is fetched
    });
  }

  Future<void> _approveReservation(Map<String, dynamic> reservation) async {
    try {
      // Ensure reservation fields are not null, provide fallback values if necessary
      String userId = reservation['userId'] ?? '';
      String orderId = reservation['orderId'] ?? '';
      String itemLabel = reservation['itemLabel'] ?? 'No Label';
      String userName = reservation['userName'] ?? 'Unknown User';
      String itemSize = reservation['itemSize'] ?? 'Unknown Size';
      int quantity = reservation['quantity'] ?? 0;

      if (userId.isEmpty || orderId.isEmpty) {
        throw Exception('Invalid reservation data: userId or orderId is missing.');
      }

      // Fetch order document
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

      // Determine main category
      String mainCategory = reservation['category'] ?? 'Unknown Category';
      if (mainCategory == 'college_items' || mainCategory == 'senior_high_items') {
        mainCategory = 'Uniform';
      }

      // Check if quantity is valid
      if (quantity == 0) {
        throw Exception('Quantity cannot be zero.');
      }

      // Step 1: Fetch the current stock from the inventory_stock collection
      DocumentSnapshot inventoryDoc = await _firestore
          .collection('inventory_stock')
          .doc(itemLabel) // Assuming each item has a unique document ID based on the itemLabel
          .get();

      if (!inventoryDoc.exists) {
        throw Exception('Item not found in inventory');
      }

      Map<String, dynamic> inventoryData = inventoryDoc.data() as Map<String, dynamic>;
      int currentStock = inventoryData['stockQuantity'] ?? 0;

      // Step 2: Check if there is enough stock available
      if (currentStock < quantity) {
        throw Exception('Not enough stock available for item "$itemLabel". Only $currentStock in stock, but $quantity requested.');
      }

      // Step 3: Deduct the quantity from the available stock
      int updatedStock = currentStock - quantity;

      // Step 4: Update the inventory_stock collection with the new stock level
      await _firestore.collection('inventory_stock').doc(itemLabel).update({
        'stockQuantity': updatedStock,
      });

      // Update the status of the reservation to 'approved'
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('orders')
          .doc(orderId)
          .update({'status': 'approved'});

      // Add to approved_items collection
      await _firestore.collection('approved_items').add({
        'reservationDate': reservationDate,
        'approvalDate': FieldValue.serverTimestamp(),
        'itemLabel': itemLabel,
        'itemSize': itemSize,
        'quantity': quantity,
        'name': userName,
        'pricePerPiece': reservation['price'] != null ? reservation['price'] / quantity : 0,
      });

      // Store the approved reservation in the admin_transactions collection
      await _firestore.collection('admin_transactions').add({
        'cartItemRef': orderId,
        'category': mainCategory,
        'courseLabel': reservation['courseLabel'] ?? 'Unknown Course',
        'itemLabel': itemLabel,
        'itemSize': itemSize,
        'quantity': quantity,
        'studentNumber': reservation['studentId'] ?? 'Unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
        'userName': userName,
      });

      // Send notification to the user after approving
      await _sendNotificationToUser(userId, userName, reservation);

      print('Reservation approved and stock updated successfully');

      // Update the local list to remove the approved reservation
      setState(() {
        allPendingReservations.removeWhere(
                (element) => element['orderId'] == orderId);
      });

      // Show success message using SnackBar
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

  Future<void> _sendNotificationToUser(String userId, String userName,
      Map<String, dynamic> reservation) async {
    try {
      // Extract quantity and price information from the reservation
      List<dynamic> orderItems = reservation['items'] ?? [];
      List<Map<String, dynamic>> orderSummary = [];

      if (orderItems.isNotEmpty) {
        // If there are multiple items (bulk order), add all of them to the summary
        for (var item in orderItems) {
          int quantity = item['quantity'] ?? 1; // Ensure quantity is not null or zero
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
        // If it's a single item order, add the reservation itself to the summary
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

      // Create the notification message based on the number of items
      String notificationMessage;
      if (orderSummary.length > 1) {
        notificationMessage =
        'Your bulk reservation (${orderSummary.length} items) has been approved.';
      } else {
        notificationMessage =
        'Your reservation for ${orderSummary[0]['itemLabel']} (${orderSummary[0]['itemSize']}) has been approved.';
      }

      // Create a reference to the user's notifications collection
      CollectionReference notificationsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications');

      // Add the notification data to Firestore
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
        child: CircularProgressIndicator(), // Loading spinner
      )
          : allPendingReservations.isEmpty
          ? Center(
        child: Text("No pending reservations found"),
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
                    DataColumn(label: Text('Price per Piece')),
                    DataColumn(label: Text('Total Price')),
                    DataColumn(label: Text('Order Date')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: allPendingReservations.expand((reservation) {
                    final List orderItems = reservation['items'] ?? [];

                    if (orderItems.length <= 1) {
                      if (orderItems.isEmpty) {
                        return [
                          DataRow(
                            key: ValueKey(reservation['orderId']),
                            cells: [
                              DataCell(Text(reservation['userName'])),
                              DataCell(Text(reservation['studentId'])),
                              DataCell(Text(reservation['itemLabel'] ?? 'No label')),
                              DataCell(Text(reservation['itemSize'] ?? 'No Size')),
                              DataCell(Text('₱${(reservation['price'] ?? 0).toStringAsFixed(2)}')),
                              DataCell(Text('₱${((reservation['price'] ?? 0) * (reservation['quantity'] ?? 1)).toStringAsFixed(2)}')),
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
                      } else {
                        final item = orderItems[0];
                        return [
                          DataRow(
                            key: ValueKey('${reservation['orderId']}_${item['itemLabel']}'),
                            cells: [
                              DataCell(Text(reservation['userName'])),
                              DataCell(Text(reservation['studentId'])),
                              DataCell(Text(item['itemLabel'] ?? 'No label')),
                              DataCell(Text(item['itemSize'] ?? 'No Size')),
                              DataCell(Text('₱${(item['price'] ?? 0).toStringAsFixed(2)}')),
                              DataCell(Text('₱${((item['price'] ?? 0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}')),
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
                      }
                    } else {
                      bool isExpanded = expandedBulkOrders.contains(reservation['orderId']);
                      return [
                        DataRow(
                          key: ValueKey(reservation['orderId']),
                          cells: [
                            DataCell(Text(reservation['userName'])),
                            DataCell(Text(reservation['studentId'])),
                            DataCell(Row(
                              children: [
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
                                Text('Bulk Order (${orderItems.length} items)'),
                              ],
                            )),
                            DataCell(Text('')), // Empty for bulk order
                            DataCell(Text('')), // Empty for bulk order
                            DataCell(Text('₱${orderItems.fold<num>(
                                0, (previousValue, item) => previousValue +
                                ((item['price'] ?? 0) as num) *
                                    ((item['quantity'] ?? 1) as num)).toStringAsFixed(2)}')),
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
                        if (isExpanded)
                          ...orderItems.map<DataRow>((item) {
                            return DataRow(
                              key: ValueKey('${reservation['orderId']}_${item['itemLabel']}'),
                              cells: [
                                DataCell(Text('')), // Empty for name in expanded items
                                DataCell(Text('')), // Empty for studentId in expanded items
                                DataCell(Text(item['itemLabel'] ?? 'No label')),
                                DataCell(Text(item['itemSize'] ?? 'No Size')),
                                DataCell(Text('₱${(item['price'] ?? 0).toStringAsFixed(2)}')),
                                DataCell(Text('₱${((item['price'] ?? 0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}')),
                                DataCell(Text('')), // Empty cell for order date
                                DataCell(Text('')), // Empty cell for actions
                              ],
                            );
                          }).toList(),
                      ];
                    }
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
