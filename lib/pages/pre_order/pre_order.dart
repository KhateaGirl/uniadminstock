import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PreOrderPage extends StatefulWidget {
  @override
  _PreOrderPageState createState() => _PreOrderPageState();
}

class _PreOrderPageState extends State<PreOrderPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> allPendingPreOrders = [];
  Set<String> expandedBulkOrders = Set<String>();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllPendingPreOrders();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllPendingPreOrders() async {
    List<Map<String, dynamic>> pendingPreOrders = [];
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
          .where('status', isEqualTo: 'pending') // Only fetch pending pre-orders
          .get();

      for (var orderDoc in ordersSnapshot.docs) {
        Map<String, dynamic> preOrderData = orderDoc.data() as Map<String, dynamic>;

        preOrderData['orderId'] = orderDoc.id;
        preOrderData['userName'] = userName;
        preOrderData['studentId'] = studentId;
        preOrderData['userId'] = userDoc.id;
        preOrderData['category'] = preOrderData['category'] ?? 'Unknown Category';
        preOrderData['label'] = preOrderData['label'] ?? 'No Label';
        preOrderData['itemSize'] = preOrderData['itemSize'] ?? 'Unknown Size';
        preOrderData['courseLabel'] = preOrderData['courseLabel'] ?? 'Unknown Course';

        if (preOrderData.containsKey('items') && preOrderData['items'] is List) {
          List<dynamic> orderItems = preOrderData['items'];

          double totalOrderPrice = 0.0;
          for (var item in orderItems) {
            int itemQuantity = item['quantity'] ?? 1;
            double itemPrice = item['price'] ?? 0.0;
            double itemTotalPrice = itemQuantity * itemPrice;
            item['totalPrice'] = itemTotalPrice.toStringAsFixed(2);

            totalOrderPrice += itemTotalPrice;
          }

          preOrderData['totalOrderPrice'] = totalOrderPrice.toStringAsFixed(2);
        } else {
          int quantity = preOrderData['quantity'] ?? 1;
          double pricePerPiece = preOrderData['price'] ?? 0.0;
          double totalPrice = quantity * pricePerPiece;
          preOrderData['totalPrice'] = totalPrice.toStringAsFixed(2);
        }
        pendingPreOrders.add(preOrderData);
      }
    }

    pendingPreOrders.sort((a, b) {
      Timestamp aTimestamp = a['orderDate'] != null && a['orderDate'] is Timestamp
          ? a['orderDate']
          : Timestamp.now();
      Timestamp bTimestamp = b['orderDate'] != null && b['orderDate'] is Timestamp
          ? b['orderDate']
          : Timestamp.now();
      return bTimestamp.compareTo(aTimestamp);
    });

    setState(() {
      allPendingPreOrders = pendingPreOrders;
      isLoading = false;
    });
  }

  Future<void> _approvePreOrder(Map<String, dynamic> preOrder) async {
    try {
      String userId = preOrder['userId'] ?? '';
      String orderId = preOrder['orderId'] ?? '';
      String userName = preOrder['userName'] ?? 'Unknown User';
      String studentId = preOrder['studentId'] ?? 'Unknown ID';

      print('Approving pre-order for userId: $userId, orderId: $orderId');
      print('Pre-order details: $preOrder');

      if (userId.isEmpty || orderId.isEmpty) {
        throw Exception('Invalid pre-order data: userId or orderId is missing.');
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

      Timestamp orderDate = orderDoc['orderDate'] ?? Timestamp.now();
      print('Order date: $orderDate');

      List<dynamic> orderItems = preOrder['items'] ?? [];
      if (orderItems.isEmpty) {
        throw Exception('No items found in the pre-order');
      }

      for (var item in orderItems) {
        String label = (item['label'] ?? 'No Label').trim();
        String itemSize = (item['itemSize'] ?? 'Unknown Size').trim();
        String mainCategory = (item['category'] ?? '').trim();
        String subCategory = (item['courseLabel'] ?? '').trim();
        int quantity = item['quantity'] ?? 0;

        if (label.isEmpty || mainCategory.isEmpty || subCategory.isEmpty || quantity <= 0) {
          throw Exception('Invalid item data: missing label, category, subCategory, or quantity.');
        }

        await _firestore.collection('approved_items').add({
          'orderDate': orderDate,
          'approvalDate': FieldValue.serverTimestamp(),
          'label': label,
          'itemSize': itemSize,
          'quantity': quantity,
          'name': userName,
          'mainCategory': mainCategory,
          'subCategory': subCategory,
        });

        await _firestore.collection('admin_transactions').add({
          'cartItemRef': orderId,
          'category': mainCategory,
          'courseLabel': subCategory,
          'label': label,
          'itemSize': itemSize,
          'quantity': quantity,
          'studentNumber': studentId,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': userId,
          'userName': userName,
        });
      }

      await _firestore.collection('users').doc(userId).collection('orders').doc(orderId).update({'status': 'approved'});

      await _sendNotificationToUser(userId, userName, preOrder);
      await _fetchAllPendingPreOrders();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pre-order for ${preOrder['items'].map((e) => e['label']).join(", ")} approved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('Error approving pre-order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve pre-order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendNotificationToUser(String userId, String userName, Map<String, dynamic> preOrder) async {
    try {
      String itemNames = preOrder['items'].map((e) => e['label']).join(", ");
      String message = "Hello $userName, your pre-order for $itemNames has been approved.";

      await _firestore.collection('users').doc(userId).collection('notifications').add({
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unread',
      });

      print("Notification sent to user: $userName");
    } catch (e) {
      print("Failed to send notification: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pre-Order List"),
        centerTitle: true,
      ),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(),
      )
          : SingleChildScrollView(
        controller: _verticalController,
        child: LayoutBuilder(
          builder: (context, constraints) {
            double totalWidth = constraints.maxWidth;
            double orderIdWidth = totalWidth * 0.2; // Adjusted proportions
            double userNameWidth = totalWidth * 0.25;
            double totalPriceWidth = totalWidth * 0.15;
            double orderDateWidth = totalWidth * 0.2;
            double actionsWidth = totalWidth * 0.2;

            return SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16.0,
                headingRowColor: MaterialStateColor.resolveWith(
                        (states) => Colors.grey.shade200), // Header background color
                columns: [
                  DataColumn(
                      label: SizedBox(
                          width: orderIdWidth,
                          child: Text('Order ID',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)))),
                  DataColumn(
                      label: SizedBox(
                          width: userNameWidth,
                          child: Text('User Name',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)))),
                  DataColumn(
                      label: SizedBox(
                          width: orderDateWidth,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text('Order Date',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ))),
                  DataColumn(
                      label: SizedBox(
                          width: actionsWidth,
                          child: Center(
                            child: Text('Actions',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ))),
                ],
                rows: allPendingPreOrders.map((order) {
                  return DataRow(cells: [
                    DataCell(SizedBox(
                      width: orderIdWidth,
                      child: Text(order['orderId'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12)),
                    )),
                    DataCell(SizedBox(
                      width: userNameWidth,
                      child: Text(order['userName'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12)),
                    )),
                    DataCell(SizedBox(
                      width: totalPriceWidth,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text("₱${order['totalOrderPrice']}",
                            style: TextStyle(fontSize: 12)),
                      ),
                    )),
                    DataCell(SizedBox(
                      width: orderDateWidth,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                            DateFormat('yyyy-MM-dd')
                                .format(order['orderDate'].toDate()),
                            style: TextStyle(fontSize: 12)),
                      ),
                    )),
                    DataCell(SizedBox(
                      width: actionsWidth,
                      child: Center(
                        child: ElevatedButton(
                          onPressed: () => _approvePreOrder(order),
                          child: Text("Approve"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            textStyle: TextStyle(fontSize: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    )),
                  ]);
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}