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

      QuerySnapshot preordersSnapshot = await _firestore
          .collection('users')
          .doc(userDoc.id)
          .collection('preorders')
          .where('status', isEqualTo: 'pre-order confirmed')
          .get();

      for (var preorderDoc in preordersSnapshot.docs) {
        Map<String, dynamic> preOrderData = preorderDoc.data() as Map<String, dynamic>;

        List<dynamic> items = preOrderData['items'] ?? [];
        String label = items.length > 1 ? "Bulk Order (${items.length} items)" : items[0]['label'];
        String preOrderDate = DateFormat('yyyy-MM-dd').format((preOrderData['preOrderDate'] as Timestamp).toDate());

        pendingPreOrders.add({
          'userName': userName,
          'studentId': studentId,
          'label': label,
          'category': items.length > 1 ? 'Multiple' : items[0]['category'],
          'courseLabel': items.length > 1 ? 'Various' : items[0]['courseLabel'],
          'itemSize': items.length > 1 ? 'Various' : items[0]['itemSize'],
          'quantity': items.length > 1 ? items.map((e) => e['quantity'] as int).reduce((a, b) => a + b) : items[0]['quantity'],
          'preOrderDate': preOrderDate,
          'items': items, // Keep items for detailed view
          'preOrderTimestamp': preOrderData['preOrderDate'] as Timestamp, // Keep timestamp for sorting
          'orderId': preorderDoc.id,
        });
      }
    }

    // Sort pendingPreOrders by preOrderTimestamp in descending order
    pendingPreOrders.sort((a, b) => b['preOrderTimestamp'].compareTo(a['preOrderTimestamp']));

    setState(() {
      allPendingPreOrders = pendingPreOrders;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pre-Order List"),
        centerTitle: true,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        controller: _verticalController,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _horizontalController,
          child: DataTable(
            columnSpacing: 16.0,
            headingRowColor: MaterialStateColor.resolveWith(
                    (states) => Colors.grey.shade200),
            columns: [
              DataColumn(
                label: Text(
                  'User Name',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Item Label',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Category',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Course Label',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Size',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Quantity',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Pre-Order Date',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Actions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows: allPendingPreOrders.expand((order) {
              List<DataRow> rows = [];
              bool isBulkOrder = order['items'].length > 1;

              rows.add(DataRow(cells: [
                DataCell(ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 100),
                  child: Text(order['userName'],
                      overflow: TextOverflow.ellipsis),
                )),
                DataCell(
                  isBulkOrder
                      ? InkWell(
                    onTap: () {
                      setState(() {
                        if (expandedBulkOrders.contains(
                            order['orderId'])) {
                          expandedBulkOrders.remove(order['orderId']);
                        } else {
                          expandedBulkOrders.add(order['orderId']);
                        }
                      });
                    },
                    child: Row(
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 120),
                          child: Text(order['label'],
                              overflow: TextOverflow.ellipsis),
                        ),
                        Icon(
                          expandedBulkOrders.contains(order['orderId'])
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                      ],
                    ),
                  )
                      : ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 120),
                    child: Text(order['label'],
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
                DataCell(ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 100),
                  child: Text(order['category'],
                      overflow: TextOverflow.ellipsis),
                )),
                DataCell(ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 100),
                  child: Text(order['courseLabel'],
                      overflow: TextOverflow.ellipsis),
                )),
                DataCell(ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 50),
                  child: Text(order['itemSize'],
                      overflow: TextOverflow.ellipsis),
                )),
                DataCell(Text(order['quantity'].toString())),
                DataCell(Text(order['preOrderDate'])),
                DataCell(ElevatedButton(
                  onPressed: () {}, // Your action here
                  child: Text("Approve"),
                )),
              ]));

              if (isBulkOrder && expandedBulkOrders.contains(order['orderId'])) {
                rows.addAll(order['items'].map<DataRow>((item) {
                  return DataRow(cells: [
                    DataCell(SizedBox()), // Empty cell for alignment
                    DataCell(ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 120),
                      child: Text(item['label'],
                          overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 100),
                      child: Text(item['category'],
                          overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 100),
                      child: Text(item['courseLabel'],
                          overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 50),
                      child: Text(item['itemSize'],
                          overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(Text(item['quantity'].toString())),
                    DataCell(SizedBox()),
                    DataCell(SizedBox()),
                  ]);
                }).toList());
              }
              return rows;
            }).toList(),
          ),
        ),
      ),
    );
  }
}