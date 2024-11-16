import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unistock/helpers/API.dart';

class ReleasePage extends StatefulWidget {
  @override
  _ReleasePageState createState() => _ReleasePageState();
}

extension CapitalizeExtension on String {
  String capitalize() {
    return this.isNotEmpty ? this[0].toUpperCase() + this.substring(1).toLowerCase() : '';
  }
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
      QuerySnapshot approvedReservationsSnapshot =
      await _firestore.collection('approved_reservation').get();
      for (var doc in approvedReservationsSnapshot.docs) {
        Map<String, dynamic> transactionData = doc.data() as Map<String, dynamic>;
        transactionData['transactionId'] = doc.id;

        transactionData['name'] = transactionData['name'] ?? 'Unknown User';
        transactionData['studentId'] = transactionData['studentId'] ?? 'Unknown ID';

        if (transactionData.containsKey('items') &&
            transactionData['items'] is List) {
          for (var item in transactionData['items']) {
            item['label'] = item['label'] ?? 'No Label';
            item['mainCategory'] = item['mainCategory'] ?? 'Unknown Category';
            item['subCategory'] = item['subCategory'] ?? 'N/A';
            item['size'] = item['itemSize'] ?? 'Unknown Size';
            item['pricePerPiece'] = item['pricePerPiece'] ?? 0.0;
            item['quantity'] = item['quantity'] ?? 1;
          }
        }

        approvedTransactions.add(transactionData);
      }

      // Fetch approved preorders
      QuerySnapshot approvedPreordersSnapshot =
      await _firestore.collection('approved_preorders').get();
      for (var doc in approvedPreordersSnapshot.docs) {
        Map<String, dynamic> preorderData = doc.data() as Map<String, dynamic>;
        preorderData['transactionId'] = doc.id;

        // Fetch user data using userId
        if (preorderData.containsKey('userId')) {
          String userId = preorderData['userId'];
          DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            preorderData['name'] = userDoc['name'] ?? 'Unknown User';
            preorderData['studentId'] =
                userDoc['studentId'] ?? 'Unknown ID';
          } else {
            preorderData['name'] = 'Unknown User';
            preorderData['studentId'] = 'Unknown ID';
          }
        } else {
          preorderData['name'] = 'Unknown User';
          preorderData['studentId'] = 'Unknown ID';
        }

        if (preorderData.containsKey('items') &&
            preorderData['items'] is List) {
          for (var item in preorderData['items']) {
            item['label'] = item['label'] ?? 'No Label';
            item['mainCategory'] = item['category'] ?? 'Unknown Category';
            item['subCategory'] = item['courseLabel'] ?? 'N/A';
            item['size'] = item['itemSize'] ?? 'Unknown Size';
            item['pricePerPiece'] = item['pricePerPiece'] ?? 0.0;
            item['quantity'] = item['quantity'] ?? 1;
          }
        }

        approvedTransactions.add(preorderData);
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
          content: Text('Error fetching approved transactions: $e'),
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
              onPressed: () async {
                String orNumber = _orNumberController.text;

                if (orNumber.length == 8 && int.tryParse(orNumber) != null) {
                  // Check for duplicate OR Number in admin_transactions
                  bool orNumberExists = await _checkIfORNumberExists(orNumber);
                  if (orNumberExists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('OR Number already exists. Please use a unique OR Number.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else {
                    Navigator.pop(context);
                    _approveReservation(reservation, orNumber);
                  }
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

  Future<bool> _checkIfORNumberExists(String orNumber) async {
    try {
      // Query the admin_transactions collection for the OR Number
      QuerySnapshot querySnapshot = await _firestore
          .collection('admin_transactions')
          .where('orNumber', isEqualTo: orNumber)
          .get();

      // If any document is found, the OR Number already exists
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking OR Number: $e');
      return false; // Default to false in case of error
    }
  }

  Future<void> _approveReservation(Map<String, dynamic> reservation, String orNumber) async {
    try {
      print("Approval process started for reservation ID: ${reservation['transactionId']}");

      reservation['orNumber'] = orNumber;

      // Fetch user data based on userId
      String userName = reservation['userName'] ?? 'Unknown User';
      String studentId = reservation['studentId'] ?? 'Unknown ID';

      if (reservation.containsKey('userId')) {
        String userId = reservation['userId'];
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          userName = userDoc['name'] ?? 'Unknown User';
          studentId = userDoc['studentId'] ?? 'Unknown ID';
        }
      }

      List items = reservation['items'] ?? [];
      List<Map<String, dynamic>> itemDataList = [];
      int totalQuantity = 0;
      double totalTransactionPrice = 0.0;

      if (items.isNotEmpty) {
        for (var item in items) {
          String label = (item['label'] ?? 'No Label').trim();
          String category = (item['mainCategory'] ?? 'Unknown Category').trim();
          category = category.toLowerCase().replaceAll('_', ' ');
          String subCategory = (item['subCategory'] ?? 'Unknown SubCategory').trim();

          int quantity = item['quantity'] ?? 0;
          double pricePerPiece = double.tryParse(item['pricePerPiece']?.toString() ?? '0') ?? 0.0;
          double totalPrice = pricePerPiece * quantity;

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

          totalQuantity += quantity;
          totalTransactionPrice += totalPrice;
        }
      }

      // Store bulk order as a single document in approved_items
      print("Storing approved items...");
      await _firestore.collection('approved_items').add({
        'reservationDate': reservation['reservationDate'] ?? Timestamp.now(),
        'approvalDate': FieldValue.serverTimestamp(),
        'items': itemDataList,
        'name': userName,
        'studentId': studentId,
        'totalQuantity': totalQuantity,
        'totalTransactionPrice': totalTransactionPrice,
        'orNumber': orNumber,
      });

      // Store transaction summary in admin_transactions
      print("Storing transaction summary...");
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

      // Delete the original document after approval
      if (reservation.containsKey('transactionId')) {
        print("Deleting original reservation document...");
        await _firestore
            .collection('approved_reservation')
            .doc(reservation['transactionId'])
            .delete();
        print("Reservation document deleted successfully.");
      }

      // Refresh data after approval
      await fetchAllApprovedTransactions();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation approved and document deleted successfully!'),
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
      // Trim and normalize the category for consistency
      category = category.trim(); // Remove leading/trailing whitespace
      category = category.replaceAll('_', ' '); // Replace underscores with spaces
      category = category.split(' ').map((word) => word.capitalize()).join(' '); // Capitalize each word

      CollectionReference itemsRef;

      if (category == 'Merch & Accessories') {
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

      } else if (category == 'College Items') {
        // Handle College Items category
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

      } else if (category == 'Senior High Items') {
        // Handle Senior High Items category
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
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Student ID')),
                    DataColumn(label: Text('Label')),
                    DataColumn(label: Text('Size')),
                    DataColumn(label: Text('Quantity')),
                    DataColumn(label: Text('Price per Piece')),
                    DataColumn(label: Text('Total Price')),
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

                      // Use a unique key for each DataRow
                      return [
                        DataRow(
                          key: ValueKey('${reservation['transactionId']}_${label}'), // Unique key
                          cells: [
                            DataCell(Text(reservation['name'] ?? 'Unknown User')),
                            DataCell(Text(reservation['studentId'] ?? 'Unknown ID')),
                            DataCell(Text(label)),
                            DataCell(Text(size)),
                            DataCell(Text('$quantity')),
                            DataCell(Text('₱${pricePerPiece.toStringAsFixed(2)}')),
                            DataCell(Text('₱${totalPrice.toStringAsFixed(2)}')),
                            DataCell(
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      _showORNumberDialog(reservation);
                                    },
                                    child: Text('Approve'),
                                  ),
                                  const SizedBox(width: 8),
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
                      // Generate a unique key for bulk orders
                      double totalQuantity = items.fold<double>(0, (sum, item) => sum + (item['quantity'] ?? 1));
                      double totalOrderPrice = items.fold<double>(
                          0, (sum, item) => sum + ((item['quantity'] ?? 1) * (double.tryParse(item['pricePerPiece']?.toString() ?? '0') ?? 0.0)));

                      List<DataRow> rows = [
                        DataRow(
                          key: ValueKey(reservation['transactionId']), // Unique key
                          cells: [
                            DataCell(Text(reservation['name'] ?? 'Unknown User')),
                            DataCell(Text(reservation['studentId'] ?? 'Unknown ID')),
                            DataCell(Row(
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
                            DataCell(
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      _showORNumberDialog(reservation);
                                    },
                                    child: Text('Approve'),
                                  ),
                                  const SizedBox(width: 8),
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
                        rows.addAll(items.asMap().entries.map<DataRow>((entry) {
                          final int index = entry.key; // Index of the item in the list
                          final Map<String, dynamic> item = entry.value;
                          int quantity = item['quantity'] ?? 1;
                          double pricePerPiece = double.tryParse(item['pricePerPiece'].toString()) ?? 0.0;
                          double itemTotalPrice = quantity * pricePerPiece;
                          String label = item['label'] ?? 'No Label';
                          String size = item['itemSize'] ?? 'No Size';

                          return DataRow(
                            key: ValueKey('${reservation['transactionId']}_${index}'), // Unique key using transactionId and index
                            cells: [
                              DataCell(Text('')), // Empty cell
                              DataCell(Text('')), // Empty cell
                              DataCell(Text(label)),
                              DataCell(Text(size)),
                              DataCell(Text('$quantity')),
                              DataCell(Text('₱${pricePerPiece.toStringAsFixed(2)}')),
                              DataCell(Text('₱${itemTotalPrice.toStringAsFixed(2)}')),
                              DataCell(Text('')), // Empty cell
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