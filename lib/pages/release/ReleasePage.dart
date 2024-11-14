import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReleasePage extends StatefulWidget {
  @override
  _ReleasePageState createState() => _ReleasePageState();
}

class _ReleasePageState extends State<ReleasePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> allPendingReservations = [];
  Set<String> expandedBulkOrders = Set<String>();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAllApprovedTransactions();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> fetchAllApprovedTransactions() async {
    List<Map<String, dynamic>> approvedTransactions = [];
    setState(() {
      isLoading = true;
    });

    try {
      QuerySnapshot approvedReservationsSnapshot = await _firestore.collection('approved_reservation').get();

      for (var doc in approvedReservationsSnapshot.docs) {
        Map<String, dynamic> transactionData = doc.data() as Map<String, dynamic>;
        transactionData['transactionId'] = doc.id;
        transactionData['userName'] = transactionData['name'] ?? 'Unknown User';
        transactionData['studentId'] = transactionData['studentId'] ?? 'Unknown ID';

        if (transactionData.containsKey('items') && transactionData['items'] is List) {
          double totalOrderPrice = 0.0;
          for (var item in transactionData['items']) {
            int quantity = item['quantity'] ?? 1;
            double pricePerPiece = item['pricePerPiece'] ?? 0.0;
            item['totalPrice'] = (quantity * pricePerPiece).toStringAsFixed(2);
            totalOrderPrice += quantity * pricePerPiece;
          }
          transactionData['totalOrderPrice'] = totalOrderPrice.toStringAsFixed(2);
        } else {
          int quantity = transactionData['quantity'] ?? 1;
          double pricePerPiece = transactionData['pricePerPiece'] ?? 0.0;
          transactionData['totalPrice'] = (quantity * pricePerPiece).toStringAsFixed(2);
        }

        approvedTransactions.add(transactionData);
      }

      setState(() {
        allPendingReservations = approvedTransactions;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching approved reservations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showORNumberDialog(Map<String, dynamic> reservation) {
    final _orNumberController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter OR Number'),
          content: TextField(
            controller: _orNumberController,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: InputDecoration(
              hintText: 'Enter 8-digit OR Number',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                String orNumber = _orNumberController.text;

                if (orNumber.length == 8 && int.tryParse(orNumber) != null) {
                  Navigator.pop(context);
                  _approveReservation(reservation, orNumber);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid 8-digit OR number.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _approveReservation(Map<String, dynamic> reservation, String orNumber) async {
    try {
      reservation['orNumber'] = orNumber;
      String userId = reservation['userId'] ?? '';
      String userName = reservation['userName'] ?? 'Unknown User';
      String studentId = reservation['studentId'] ?? 'Unknown ID';
      String studentName = reservation['userName'] ?? 'Unknown User';

      if (userId.isEmpty) {
        throw Exception('Invalid reservation data: userId is missing.');
      }

      Timestamp reservationDate = reservation['reservationDate'] ?? Timestamp.now();
      String label = (reservation['label'] ?? 'No Label').trim();
      String itemSize = (reservation['itemSize'] ?? 'Unknown Size').trim();
      String mainCategory = (reservation['mainCategory'] ?? '').trim();
      String subCategory = (reservation['subCategory'] ?? '').trim();
      int quantity = reservation['quantity'] ?? 0;
      double pricePerPiece = reservation['pricePerPiece'] ?? 0.0;
      double totalPrice = pricePerPiece * quantity;

      if (label.isEmpty || mainCategory.isEmpty || subCategory.isEmpty || quantity <= 0) {
        throw Exception('Invalid item data: missing label, category, subCategory, or quantity.');
      }

      await _deductItemQuantity(mainCategory, subCategory, label, itemSize, quantity);

      await _firestore.collection('approved_items').add({
        'reservationDate': reservationDate,
        'approvalDate': FieldValue.serverTimestamp(),
        'label': label,
        'itemSize': itemSize,
        'quantity': quantity,
        'name': userName,
        'pricePerPiece': pricePerPiece,
        'totalPrice': totalPrice,
        'mainCategory': mainCategory,
        'subCategory': subCategory,
        'orNumber': orNumber,
      });

      await _firestore.collection('admin_transactions').add({
        'cartItemRef': reservation['transactionId'],
        'category': mainCategory,
        'courseLabel': subCategory,
        'label': label,
        'itemSize': itemSize,
        'quantity': quantity,
        'studentNumber': studentId,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
        'userName': userName,
        'pricePerPiece': pricePerPiece,
        'totalPrice': totalPrice,
        'orNumber': orNumber,
      });

      await _sendNotificationToUser(userId, userName, studentName, studentId, reservation);
      await fetchAllApprovedTransactions();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation for $label approved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve reservation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deductItemQuantity(String category, String subCategory, String label, String size, int quantity) async {
    try {
      if (category == 'merch_and_accessories') {
        category = 'Merch & Accessories';
      } else {
        category = category.toLowerCase().replaceAll('_', ' ');
      }

      CollectionReference itemsRef;

      if (category == 'senior high items') {
        itemsRef = _firestore.collection('Inventory_stock').doc('senior_high_items').collection('Items');

        QuerySnapshot querySnapshot = await itemsRef.where('label', isEqualTo: label).limit(1).get();
        if (querySnapshot.docs.isEmpty) {
          throw Exception('Item not found in inventory: $label');
        }

        DocumentSnapshot itemDoc = querySnapshot.docs.first;
        Map<String, dynamic> itemData = itemDoc.data() as Map<String, dynamic>;

        if (itemData.containsKey('sizes') && itemData['sizes'] is Map && itemData['sizes'][size] != null) {
          int currentStock = itemData['sizes'][size]['quantity'] ?? 0;

          if (currentStock >= quantity) {
            itemData['sizes'][size]['quantity'] = currentStock - quantity;
            await itemsRef.doc(itemDoc.id).update({'sizes': itemData['sizes']});
          } else {
            throw Exception('Insufficient stock for $label size $size. Current stock: $currentStock, required: $quantity');
          }
        } else {
          throw Exception('Size $size not available for item $label');
        }

      } else if (category == 'college items') {
        itemsRef = _firestore.collection('Inventory_stock').doc('college_items').collection(subCategory);

        QuerySnapshot querySnapshot = await itemsRef.where('label', isEqualTo: label).limit(1).get();
        if (querySnapshot.docs.isEmpty) {
          throw Exception('Item not found in inventory: $label');
        }

        DocumentSnapshot itemDoc = querySnapshot.docs.first;
        Map<String, dynamic> itemData = itemDoc.data() as Map<String, dynamic>;

        if (itemData.containsKey('sizes') && itemData['sizes'] is Map && itemData['sizes'][size] != null) {
          int currentStock = itemData['sizes'][size]['quantity'] ?? 0;

          if (currentStock >= quantity) {
            itemData['sizes'][size]['quantity'] = currentStock - quantity;
            await itemsRef.doc(itemDoc.id).update({'sizes': itemData['sizes']});
          } else {
            throw Exception('Insufficient stock for $label size $size. Current stock: $currentStock, required: $quantity');
          }
        } else {
          throw Exception('Size $size not available for item $label');
        }

      } else if (category == 'Merch & Accessories') {
        DocumentSnapshot merchDoc = await _firestore.collection('Inventory_stock').doc('Merch & Accessories').get();
        if (!merchDoc.exists) {
          throw Exception('Merch & Accessories document not found');
        }

        Map<String, dynamic> merchData = merchDoc.data() as Map<String, dynamic>;

        if (merchData.containsKey(label)) {
          Map<String, dynamic> itemData = merchData[label] as Map<String, dynamic>;

          if (itemData.containsKey('sizes') && itemData['sizes'] is Map && itemData['sizes'][size] != null) {
            int currentStock = itemData['sizes'][size]['quantity'] ?? 0;

            if (currentStock >= quantity) {
              itemData['sizes'][size]['quantity'] = currentStock - quantity;

              await _firestore.collection('Inventory_stock').doc('Merch & Accessories').update({label: itemData});
            } else {
              throw Exception('Insufficient stock for $label size $size. Current stock: $currentStock, required: $quantity');
            }
          } else {
            throw Exception('Size $size not available for item $label');
          }
        } else {
          throw Exception('Item not found in Merch & Accessories: $label');
        }

      } else {
        throw Exception('Unknown category: $category');
      }

    } catch (e) {
      throw Exception('Failed to deduct stock: $e');
    }
  }

  Future<void> _rejectReservation(Map<String, dynamic> reservation) async {
    try {
      await _firestore.collection('approved_reservation').doc(reservation['transactionId']).delete();

      await fetchAllApprovedTransactions();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation for ${reservation['label']} rejected successfully!'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject reservation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendNotificationToUser(String userId, String userName, String studentName, String studentId, Map<String, dynamic> reservation) async {
    await _firestore.collection('approved_reservation').doc(reservation['transactionId']).delete();
    try {
      List<dynamic> orderItems = reservation['items'] ?? [];
      List<Map<String, dynamic>> orderSummary = [];

      if (orderItems.isNotEmpty) {
        for (var item in orderItems) {
          int quantity = item['quantity'] ?? 1;
          double pricePerPiece = item['price'] ?? 0.0;
          double totalPrice = pricePerPiece * quantity;

          orderSummary.add({
            'label': item['label'],
            'itemSize': item['itemSize'],
            'quantity': quantity,
            'pricePerPiece': pricePerPiece,
            'totalPrice': totalPrice,
          });
        }
      } else {
        int quantity = reservation['quantity'] ?? 1;
        double pricePerPiece = reservation['pricePerPiece'] ?? 0.0;
        double totalPrice = pricePerPiece * quantity;

        orderSummary.add({
          'label': reservation['label'],
          'itemSize': reservation['itemSize'],
          'quantity': quantity,
          'pricePerPiece': pricePerPiece,
          'totalPrice': totalPrice,
        });
      }

      String notificationMessage;
      if (orderSummary.length > 1) {
        notificationMessage = 'Dear $studentName (ID: $studentId), your bulk transaction (${orderSummary.length} items) has been approved.';
      } else {
        notificationMessage = 'Dear $studentName (ID: $studentId), your transaction for ${orderSummary[0]['label']} (${orderSummary[0]['itemSize']}) has been approved.';
      }

      CollectionReference notificationsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications');

      await notificationsRef.add({
        'title': 'Transaction Approved',
        'message': notificationMessage,
        'orderSummary': orderSummary,
        'studentName': studentName,
        'studentId': studentId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unread',
      });

    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Release Page"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              fetchAllApprovedTransactions();
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
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
                    DataColumn(label: Text('Label')),
                    DataColumn(label: Text('Size')),
                    DataColumn(label: Text('Quantity')),
                    DataColumn(label: Text('Price per Piece')),
                    DataColumn(label: Text('Total Price')),
                    DataColumn(label: Text('Order Date')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: allPendingReservations.map<DataRow>((reservation) {
                    String name = reservation['userName'] ?? 'Unknown User';
                    String studentId = reservation['studentId'] ?? 'Unknown ID';
                    String label = reservation['label'] ?? 'No Label';
                    String size = reservation['itemSize'] ?? 'No Size';
                    int quantity = reservation['quantity'] ?? 1;
                    double pricePerPiece = reservation['pricePerPiece'] ?? 0.0;
                    double totalPrice = double.parse(reservation['totalPrice'] ?? '0.0');
                    String orderDate = reservation['reservationDate'] != null &&
                        reservation['reservationDate'] is Timestamp
                        ? DateFormat('yyyy-MM-dd HH:mm:ss')
                        .format((reservation['reservationDate'] as Timestamp).toDate())
                        : 'No Date Provided';

                    // Unique key by combining transaction ID with a unique identifier
                    return DataRow(
                      key: ValueKey('${reservation['transactionId']}_${reservation.hashCode}'),
                      cells: [
                        DataCell(Text(name)),
                        DataCell(Text(studentId)),
                        DataCell(Text(label)),
                        DataCell(Text(size)),
                        DataCell(Text('$quantity')),
                        DataCell(Text('₱${pricePerPiece.toStringAsFixed(2)}')),
                        DataCell(Text('₱${totalPrice.toStringAsFixed(2)}')),
                        DataCell(Text(orderDate)),
                        DataCell(
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  _showORNumberDialog(reservation);
                                },
                                child: Text('Approve'),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () {
                                  _rejectReservation(reservation);
                                },
                                child: Text('Reject'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
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
