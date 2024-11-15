import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unistock/helpers/API.dart';

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
      // Fetch approved reservations
      QuerySnapshot approvedReservationsSnapshot = await _firestore.collection('approved_reservation').get();
      for (var doc in approvedReservationsSnapshot.docs) {
        Map<String, dynamic> transactionData = doc.data() as Map<String, dynamic>;
        print("Fetched data: $transactionData"); // Debugging line

        transactionData['transactionId'] = doc.id;

        transactionData['name'] = transactionData['studentName'] ?? transactionData['name'] ?? 'Unknown User';

        transactionData['studentId'] = transactionData['studentId'] ?? transactionData['studentNumber'] ?? 'Unknown ID';

        print("Processed name: ${transactionData['name']}");
        print("Processed studentId: ${transactionData['studentId']}");

        transactionData['source'] = 'approved_reservation';

        if (transactionData['approvalDate'] != null && transactionData['approvalDate'] is Timestamp) {
          transactionData['orderDateFormatted'] = DateFormat('yyyy-MM-dd HH:mm:ss').format((transactionData['approvalDate'] as Timestamp).toDate());
        } else {
          transactionData['orderDateFormatted'] = 'No Date';
        }

        if (transactionData.containsKey('items') && transactionData['items'] is List) {
          double totalOrderPrice = 0.0;

          for (var item in transactionData['items']) {
            int quantity = int.tryParse(item['quantity'].toString()) ?? 1;
            double pricePerPiece = double.tryParse(item['pricePerPiece'].toString()) ?? 0.0;

            item['totalPrice'] = (quantity * pricePerPiece).toStringAsFixed(2);
            totalOrderPrice += quantity * pricePerPiece;

            item['size'] = item['itemSize'] ?? 'Unknown Size';
            item['label'] = item['itemLabel'] ?? 'No Label';
          }

          transactionData['totalOrderPrice'] = totalOrderPrice.toStringAsFixed(2);
        } else {
          int quantity = int.tryParse(transactionData['quantity'].toString()) ?? 1;
          double pricePerPiece = double.tryParse(transactionData['pricePerPiece'].toString()) ?? 0.0;
          transactionData['totalPrice'] = (quantity * pricePerPiece).toStringAsFixed(2);
          transactionData['size'] = transactionData['itemSize'] ?? 'Unknown Size';
          transactionData['label'] = transactionData['itemLabel'] ?? 'No Label';
        }

        approvedTransactions.add(transactionData);
      }

      // Fetch approved preorders
      QuerySnapshot approvedPreOrdersSnapshot = await _firestore.collection('approved_preorders').get();
      for (var doc in approvedPreOrdersSnapshot.docs) {
        Map<String, dynamic> preOrderData = doc.data() as Map<String, dynamic>;

        // Name column: Show userName if available, otherwise use name
        preOrderData['name'] = preOrderData['userName'] ?? preOrderData['name'] ?? 'Unknown User';

        // Student ID column: Show studentId if available, otherwise use studentNumber
        preOrderData['studentId'] = preOrderData['studentId'] ?? preOrderData['studentNumber'] ?? 'Unknown ID';

        print("Processed pre-order name: ${preOrderData['name']}"); // Debugging line
        print("Processed pre-order studentId: ${preOrderData['studentId']}"); // Debugging line

        preOrderData['source'] = 'approved_preorders'; // Indicate the source of this data

        if (preOrderData['approvalDate'] != null && preOrderData['approvalDate'] is Timestamp) {
          preOrderData['orderDateFormatted'] = DateFormat('yyyy-MM-dd HH:mm:ss').format((preOrderData['approvalDate'] as Timestamp).toDate());
        } else {
          preOrderData['orderDateFormatted'] = 'No Date';
        }

        if (preOrderData.containsKey('items') && preOrderData['items'] is List) {
          double totalOrderPrice = 0.0;

          for (var item in preOrderData['items']) {
            int quantity = int.tryParse(item['quantity'].toString()) ?? 1;
            double pricePerPiece = double.tryParse(item['pricePerPiece'].toString()) ?? 0.0;

            item['totalPrice'] = (quantity * pricePerPiece).toStringAsFixed(2);
            totalOrderPrice += quantity * pricePerPiece;

            item['size'] = item['itemSize'] ?? 'Unknown Size';
            item['label'] = item['itemLabel'] ?? 'No Label';
          }

          preOrderData['totalOrderPrice'] = totalOrderPrice.toStringAsFixed(2);
        } else {
          int quantity = int.tryParse(preOrderData['quantity'].toString()) ?? 1;
          double pricePerPiece = double.tryParse(preOrderData['pricePerPiece'].toString()) ?? 0.0;
          preOrderData['totalPrice'] = (quantity * pricePerPiece).toStringAsFixed(2);
          preOrderData['size'] = preOrderData['itemSize'] ?? 'Unknown Size';
          preOrderData['label'] = preOrderData['itemLabel'] ?? 'No Label';
        }

        approvedTransactions.add(preOrderData);
      }

      // Update state with the combined list
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
          content: Text('Error fetching approved transactions and preorders: $e'),
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
      String userName = reservation['userName'] ?? 'Unknown User';
      String studentId = reservation['studentId'] ?? 'Unknown ID';
      String studentName = reservation['userName'] ?? 'Unknown User';

      List items = reservation['items'] ?? [];

      // Prepare item data for bulk order
      List<Map<String, dynamic>> itemDataList = [];
      int totalQuantity = 0;
      double totalTransactionPrice = 0.0;

      if (items.isNotEmpty) {
        for (var item in items) {
          String label = (item['label'] ?? 'No Label').trim();
          String category = (item['category'] ?? 'Unknown Category').trim();
          String subCategory = '';
          if (reservation['source'] == 'approved_reservation') {
            subCategory = (item['subCategory'] ?? 'Unknown SubCategory').trim();
          } else if (reservation['source'] == 'approved_preorders') {
            subCategory = (item['courseLabel'] ?? 'Unknown SubCategory').trim(); // For approved_preorders
          }
          int quantity = item['quantity'] ?? 0;
          double pricePerPiece = double.tryParse(item['pricePerPiece']?.toString() ?? '0') ?? 0.0;
          double totalPrice = pricePerPiece * quantity;

          // Validate fields for each item
          if (label.isEmpty || category.isEmpty || subCategory.isEmpty || quantity <= 0) {
            throw Exception('Invalid item data: missing label, category, subCategory, or quantity.');
          }

          // Deduct item quantity
          await _deductItemQuantity(category, subCategory, label, item['itemSize'] ?? 'Unknown Size', quantity);

          // Add item data to list
          itemDataList.add({
            'label': label,
            'itemSize': item['itemSize'] ?? 'Unknown Size',
            'quantity': quantity,
            'pricePerPiece': pricePerPiece,
            'totalPrice': totalPrice,
            'mainCategory': category,
            'subCategory': subCategory,
          });

          // Update totals
          totalQuantity += quantity;
          totalTransactionPrice += totalPrice;
        }
      } else {
        // Single item logic for both `approved_reservation` and `approved_preorders`
        String label = (reservation['label'] ?? 'No Label').trim();
        String category = (reservation['category'] ?? 'Unknown Category').trim();
        String subCategory = '';
        if (reservation['source'] == 'approved_reservation') {
          subCategory = (reservation['subCategory'] ?? 'Unknown SubCategory').trim();
        } else if (reservation['source'] == 'approved_preorders') {
          subCategory = (reservation['courseLabel'] ?? 'Unknown SubCategory').trim(); // For approved_preorders
        }
        int quantity = reservation['quantity'] ?? 0;
        double pricePerPiece = reservation['pricePerPiece'] ?? 0.0;
        double totalPrice = pricePerPiece * quantity;

        if (label.isEmpty || category.isEmpty || subCategory.isEmpty || quantity <= 0) {
          throw Exception('Invalid item data: missing label, category, subCategory, or quantity.');
        }

        await _deductItemQuantity(category, subCategory, label, reservation['itemSize'] ?? 'Unknown Size', quantity);

        itemDataList.add({
          'label': label,
          'itemSize': reservation['itemSize'] ?? 'Unknown Size',
          'quantity': quantity,
          'pricePerPiece': pricePerPiece,
          'totalPrice': totalPrice,
          'mainCategory': category,
          'subCategory': subCategory,
        });

        totalQuantity = quantity;
        totalTransactionPrice = totalPrice;
      }

      // Store bulk order as a single document in approved_items
      await _firestore.collection('approved_items').add({
        'reservationDate': reservation['reservationDate'] ?? Timestamp.now(),
        'approvalDate': FieldValue.serverTimestamp(),
        'items': itemDataList,
        'name': userName,
        'totalQuantity': totalQuantity,
        'totalTransactionPrice': totalTransactionPrice,
        'orNumber': orNumber,
      });

      // Store transaction summary in admin_transactions
      await _firestore.collection('admin_transactions').add({
        'cartItemRef': reservation['transactionId'],
        'userName': userName,
        'studentNumber': studentId,
        'timestamp': FieldValue.serverTimestamp(),
        'orNumber': orNumber,
        'totalQuantity': totalQuantity,
        'totalTransactionPrice': totalTransactionPrice,
        'items': itemDataList,
      });

      // If the reservation is from `approved_preorders`, delete the document
      if (reservation['source'] == 'approved_preorders') {
        await _firestore.collection('approved_preorders').doc(reservation['transactionId']).delete();
      }

      await fetchAllApprovedTransactions();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation approved successfully!'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Release Page"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchAllApprovedTransactions,
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
                  rows: allPendingReservations.expand<DataRow>((reservation) {
                    final List items = reservation['items'] ?? [];
                    bool isBulkOrder = items.length > 1;
                    bool isExpanded = expandedBulkOrders.contains(reservation['transactionId']);

                    if (!isBulkOrder) {
                      final item = items[0];
                      int quantity = item['quantity'] ?? 1;
                      double pricePerPiece = double.tryParse(item['pricePerPiece'].toString()) ?? 0.0;
                      double totalPrice = quantity * pricePerPiece;
                      String size = item['itemSize'] ?? 'No Size';
                      String label = item['label'] ?? 'No Label';

                      return [
                        DataRow(
                          key: ValueKey(reservation['transactionId']),
                          cells: [
                            DataCell(Text(reservation['name'] ?? 'Unknown User')),
                            DataCell(Text(reservation['studentId'] ?? 'Unknown ID')),
                            DataCell(Text(label)),
                            DataCell(Text(size)),
                            DataCell(Text('$quantity')),
                            DataCell(Text('₱${pricePerPiece.toStringAsFixed(2)}')),
                            DataCell(Text('₱${totalPrice.toStringAsFixed(2)}')),
                            DataCell(Text(
                              reservation['reservationDate'] != null && reservation['reservationDate'] is Timestamp
                                  ? DateFormat('yyyy-MM-dd HH:mm:ss').format(
                                (reservation['reservationDate'] as Timestamp).toDate(),
                              )
                                  : 'No Date Provided',
                            )),
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
                        ),
                      ];
                    } else {
                      double totalQuantity = items.fold<double>(0, (sum, item) => sum + (item['quantity'] ?? 1));
                      double totalOrderPrice = items.fold<double>(
                          0, (sum, item) => sum + ((item['quantity'] ?? 1) * (double.tryParse(item['pricePerPiece']?.toString() ?? '0') ?? 0.0)));

                      List<DataRow> rows = [
                        DataRow(
                          key: ValueKey(reservation['transactionId']),
                          cells: [
                            DataCell(Text(reservation['userName'] ?? 'Unknown User')),
                            DataCell(Text(reservation['studentId'] ?? 'Unknown ID')),
                            DataCell(Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Bulk Order (${items.length} items)'),
                                IconButton(
                                  icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                                  onPressed: () {
                                    setState(() {
                                      if (isExpanded) {
                                        expandedBulkOrders.remove(reservation['transactionId']);
                                      } else {
                                        expandedBulkOrders.add(reservation['transactionId']);
                                      }
                                    });
                                  },
                                ),
                              ],
                            )),
                            DataCell(Text('')),
                            DataCell(Text('$totalQuantity')),
                            DataCell(Text('')),
                            DataCell(Text('₱${totalOrderPrice.toStringAsFixed(2)}')),
                            DataCell(Text(
                              reservation['reservationDate'] != null && reservation['reservationDate'] is Timestamp
                                  ? DateFormat('yyyy-MM-dd HH:mm:ss').format(
                                (reservation['reservationDate'] as Timestamp).toDate(),
                              )
                                  : 'No Date Provided',
                            )),
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
                        ),
                      ];

                      if (isExpanded) {
                        rows.addAll(items.map<DataRow>((item) {
                          int quantity = item['quantity'] ?? 1;
                          double pricePerPiece = double.tryParse(item['pricePerPiece'].toString()) ?? 0.0;
                          double itemTotalPrice = quantity * pricePerPiece;
                          String label = item['label'] ?? 'No Label';
                          String size = item['itemSize'] ?? 'No Size';
                          return DataRow(
                            key: ValueKey('${reservation['transactionId']}_${label}'),
                            cells: [
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text(label)),
                              DataCell(Text(size)),
                              DataCell(Text('$quantity')),
                              DataCell(Text('₱${pricePerPiece.toStringAsFixed(2)}')),
                              DataCell(Text('₱${itemTotalPrice.toStringAsFixed(2)}')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                            ],
                          );
                        }).toList());
                      }
                      return rows;
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