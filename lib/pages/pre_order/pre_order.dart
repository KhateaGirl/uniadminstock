import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


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

  Future<void> _sendSMSToUser(String contactNumber, String studentName, String studentNumber, double totalAmount, List<Map<String, dynamic>> cartItems) async {
    try {
      String message = "Hello $studentName (Student ID: $studentNumber), your order has been placed successfully. Total amount: ₱$totalAmount. Items: ";

      for (var item in cartItems) {
        message += "${item['itemLabel']} (x${item['quantity']}), ";
      }
      message = message.trimRight().replaceAll(RegExp(r',\s*$'), '');

      final response = await http.post(
        Uri.parse('http://localhost:3000/send-sms'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'apikey': dotenv.env['APIKEY'] ?? '',
          'number': contactNumber,
          'message': message,
          'sendername': dotenv.env['SENDERNAME'] ?? 'Unistock',
        }),
      );

      if (response.statusCode == 200) {
        print("SMS sent successfully to $contactNumber");
      } else {
        print("Failed to send SMS: ${response.body}");
      }
    } catch (e) {
      print("Error sending SMS: $e");
    }
  }

  Future<void> _approvePreOrder(Map<String, dynamic> preOrder) async {
    try {
      String userId = preOrder['userId'] ?? '';
      String orderId = preOrder['orderId'] ?? '';
      String userName = preOrder['userName'] ?? 'Unknown User';
      String studentId = preOrder['studentId'] ?? 'Unknown ID';
      String contactNumber = preOrder['contactNumber'] ?? '';

      print('Approving pre-order for userId: $userId, orderId: $orderId');
      print('Pre-order details: $preOrder');

      if (userId.isEmpty || orderId.isEmpty) {
        throw Exception('Invalid pre-order data: userId or orderId is missing.');
      }

      DocumentSnapshot orderDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('preorders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      Map<String, dynamic> orderData = orderDoc.data() as Map<String, dynamic>;
      orderData['status'] = 'approved';
      Timestamp orderDate = orderDoc['preOrderDate'] ?? Timestamp.now();
      List<dynamic> orderItems = preOrder['items'] ?? [];

      if (orderItems.isEmpty) {
        throw Exception('No items found in the pre-order');
      }

      double totalAmount = 0.0;
      List<Map<String, dynamic>> cartItems = [];

      for (var item in orderItems) {
        String label = (item['label'] ?? 'No Label').trim();
        String itemSize = (item['itemSize'] ?? 'Unknown Size').trim();
        String mainCategory = (item['category'] ?? '').trim();
        String subCategory = (item['courseLabel'] ?? '').trim();
        int quantity = item['quantity'] ?? 0;
        double itemPrice = item['price'] ?? 0.0;
        totalAmount += itemPrice * quantity;

        if (label.isEmpty || mainCategory.isEmpty || subCategory.isEmpty || quantity <= 0) {
          throw Exception('Invalid item data: missing label, category, subCategory, or quantity.');
        }

        cartItems.add({
          'itemLabel': label,
          'quantity': quantity,
          'price': itemPrice,
        });
      }

      await _firestore
          .collection('approved_preorders')
          .doc(orderId)
          .set({
        'userId': userId,
        ...orderData,
      });


      await _firestore
          .collection('users')
          .doc(userId)
          .collection('preorders')
          .doc(orderId)
          .delete();

      await _sendNotificationToUser(userId, userName, preOrder);
      await _sendSMSToUser(contactNumber, userName, studentId, totalAmount, cartItems);

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
          'userId': userDoc.id,
          'userName': userName,
          'studentId': studentId,
          'label': label,
          'category': items.length > 1 ? 'Multiple' : items[0]['category'],
          'courseLabel': items.length > 1 ? 'Various' : items[0]['courseLabel'],
          'itemSize': items.length > 1 ? 'Various' : items[0]['itemSize'],
          'quantity': items.length > 1 ? items.map((e) => e['quantity'] as int).reduce((a, b) => a + b) : items[0]['quantity'],
          'preOrderDate': preOrderDate,
          'items': items,
          'preOrderTimestamp': preOrderData['preOrderDate'] as Timestamp,
          'orderId': preorderDoc.id,
        });
      }
    }

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
        child: Container(
          width: double.infinity,
          child: DataTable(
            columnSpacing: 12.0,
            headingRowColor: MaterialStateColor.resolveWith(
                  (states) => Colors.grey.shade200,
            ),
            columns: [
              DataColumn(
                label: Text(
                  'User Name',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Item Label',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Category',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Course Label',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Size',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Quantity',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Pre-Order Date',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Actions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
            rows: allPendingPreOrders.expand((order) {
              List<DataRow> rows = [];
              bool isBulkOrder = order['items'].length > 1;

              rows.add(DataRow(cells: [
                DataCell(Text(order['userName'], overflow: TextOverflow.ellipsis)),
                DataCell(
                  isBulkOrder
                      ? InkWell(
                    onTap: () {
                      setState(() {
                        if (expandedBulkOrders.contains(order['orderId'])) {
                          expandedBulkOrders.remove(order['orderId']);
                        } else {
                          expandedBulkOrders.add(order['orderId']);
                        }
                      });
                    },
                    child: Row(
                      children: [
                        Text(order['label'], overflow: TextOverflow.ellipsis),
                        Icon(
                          expandedBulkOrders.contains(order['orderId'])
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 16,
                        ),
                      ],
                    ),
                  )
                      : Text(order['label'], overflow: TextOverflow.ellipsis),
                ),
                DataCell(Text(order['category'], overflow: TextOverflow.ellipsis)),
                DataCell(Text(order['courseLabel'], overflow: TextOverflow.ellipsis)),
                DataCell(Text(order['itemSize'], overflow: TextOverflow.ellipsis)),
                DataCell(Text(order['quantity'].toString())),
                DataCell(Text(order['preOrderDate'])),
                DataCell(
                  TextButton(
                    onPressed: () => _approvePreOrder(order),
                    child: Text("Approve", style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                    ),
                  ),
                ),
              ]));

              if (isBulkOrder && expandedBulkOrders.contains(order['orderId'])) {
                rows.addAll(order['items'].map<DataRow>((item) {
                  return DataRow(cells: [
                    DataCell(SizedBox()),
                    DataCell(Text(item['label'], overflow: TextOverflow.ellipsis)),
                    DataCell(Text(item['category'], overflow: TextOverflow.ellipsis)),
                    DataCell(Text(item['courseLabel'], overflow: TextOverflow.ellipsis)),
                    DataCell(Text(item['itemSize'], overflow: TextOverflow.ellipsis)),
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