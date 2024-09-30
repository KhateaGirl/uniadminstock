import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:unistock/widgets/custom_text.dart';
import 'package:intl/intl.dart';

class ReservationListPage extends StatefulWidget {
  @override
  _ReservationListPageState createState() => _ReservationListPageState();
}

class _ReservationListPageState extends State<ReservationListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> allPendingReservations = [];

  @override
  void initState() {
    super.initState();
    _fetchAllPendingReservations();
  }

  Future<void> _fetchAllPendingReservations() async {
    List<Map<String, dynamic>> pendingReservations = [];

    // Fetch all users
    QuerySnapshot usersSnapshot = await _firestore.collection('users').get();

    for (var userDoc in usersSnapshot.docs) {
      String userName = userDoc['name'] ?? 'Unknown User';
      print("Processing user: $userName (${userDoc.id})");

      // Fetch orders from the user's "orders" subcollection with no status or a null status field
      QuerySnapshot ordersSnapshot = await _firestore
          .collection('users')
          .doc(userDoc.id)
          .collection('orders')
          .where('status', isEqualTo: null)
          .get();

      for (var orderDoc in ordersSnapshot.docs) {
        Map<String, dynamic> reservationData = orderDoc.data() as Map<String, dynamic>;

        // Extract fields from the order document
        String itemLabel = reservationData['itemLabel'] ?? 'Unknown';
        String itemSize = reservationData['itemSize'] ?? 'No Size';
        String category = reservationData['category'] ?? 'Unknown';
        String courseLabel = reservationData['courseLabel'] ?? 'No Course';
        Timestamp reservationDate = reservationData['orderDate'] ?? Timestamp.now();
        double price = (reservationData['price'] as num?)?.toDouble() ?? 0.0;
        int quantity = reservationData['quantity'] ?? 0;

        print(
            "Item details - itemLabel: $itemLabel, itemSize: $itemSize, category: $category, price: $price, quantity: $quantity");

        // Add fields to reservation data
        reservationData['price'] = price;
        reservationData['userName'] = userName;
        reservationData['userId'] = userDoc.id;
        reservationData['orderId'] = orderDoc.id; // Renamed from 'cartId' to 'orderId'
        reservationData['courseLabel'] = courseLabel;
        reservationData['itemSize'] = itemSize;
        reservationData['reservationDate'] = reservationDate;
        reservationData['quantity'] = quantity;

        pendingReservations.add(reservationData);
      }
    }

    pendingReservations.sort((a, b) {
      Timestamp aTimestamp = a['reservationDate'] as Timestamp;
      Timestamp bTimestamp = b['reservationDate'] as Timestamp;
      return bTimestamp.compareTo(aTimestamp); // Sort in descending order
    });

    setState(() {
      allPendingReservations = pendingReservations;
    });
  }

  Future<void> _approveReservation(Map<String, dynamic> reservation) async {
    try {
      DocumentSnapshot orderDoc = await _firestore
          .collection('users')
          .doc(reservation['userId'])
          .collection('orders')
          .doc(reservation['orderId'])
          .get();

      Timestamp reservationDate = orderDoc['orderDate'];

      String mainCategory = reservation['category'];
      if (mainCategory == 'college_items' ||
          mainCategory == 'senior_high_items') {
        mainCategory = 'Uniform';
      }

      String userName = reservation['userName'];

      QuerySnapshot usersSnapshot = await _firestore
          .collection('users')
          .where('name', isEqualTo: userName)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        throw Exception('User with the provided userName not found');
      }

      DocumentSnapshot userDoc = usersSnapshot.docs.first;

      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;

      String userId = userDoc.id;
      String studentId = (userData != null && userData.containsKey('studentId'))
          ? userData['studentId']
          : 'Unknown';

      int quantity = reservation['quantity'] ?? 0;
      if (quantity == 0) {
        throw Exception('Quantity cannot be zero.');
      }

      // Update the status of the reservation to 'approved'
      await _firestore
          .collection('users')
          .doc(reservation['userId'])
          .collection('orders')
          .doc(reservation['orderId'])
          .update({'status': 'approved'});

      // Add to approved_items collection
      await _firestore.collection('approved_items').add({
        'reservationDate': reservationDate,
        'approvalDate': FieldValue.serverTimestamp(),
        'itemLabel': reservation['itemLabel'],
        'itemSize': reservation['itemSize'],
        'quantity': quantity,
        'name': reservation['userName'],
        'pricePerPiece': reservation['price'] / quantity,
      });

      // Store the approved reservation in the admin_transactions collection
      await _firestore.collection('admin_transactions').add({
        'cartItemRef': reservation['orderId'],
        'category': mainCategory,
        'courseLabel': reservation['courseLabel'],
        'itemLabel': reservation['itemLabel'],
        'itemSize': reservation['itemSize'],
        'quantity': quantity,
        'studentNumber': studentId,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
        'userName': userName,
      });

      // Send notification to the user after approving
      await _sendNotificationToUser(userId, userName, reservation);

      print('Reservation approved successfully');

      // Update the local list to remove the approved reservation
      setState(() {
        allPendingReservations.removeWhere(
                (element) => element['orderId'] == reservation['orderId']);
      });

      // Show success message using SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation for ${reservation['itemLabel']} approved successfully!'),
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
    int quantity = reservation['quantity'] ?? 1; // Ensure quantity is not null or zero
    double price = reservation['price'] ?? 0.0;

    String notificationMessage =
        'Your reservation for ${reservation['itemLabel']} (${reservation['itemSize']}) has been approved.';

    double pricePerPiece = price / quantity;
    double totalPrice = pricePerPiece * quantity;

    Map<String, dynamic> notificationData = {
      'itemLabel': reservation['itemLabel'],
      'itemSize': reservation['itemSize'],
      'quantity': quantity,
      'pricePerPiece': pricePerPiece,
      'totalPrice': totalPrice,
    };

    CollectionReference notificationsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications');

    await notificationsRef.add({
      'title': 'Reservation Approved',
      'message': notificationMessage,
      'orderSummary': [notificationData],
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'unread',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText(
          text: "Reservation List",
        ),
        centerTitle: true,
      ),
      body: allPendingReservations.isEmpty
          ? Center(
        child: CustomText(
          text: "No pending reservations found",
        ),
      )
          : SingleChildScrollView(
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    columnSpacing: 16.0,
                    columns: [
                      DataColumn(label: Text('Item Label')),
                      DataColumn(label: Text('Item Size')),
                      DataColumn(label: Text('Course Label')),
                      DataColumn(label: Text('Price')),
                      DataColumn(label: Text('Reservation Date')),
                      DataColumn(label: Text('User Name')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: allPendingReservations.map((reservation) {
                      return DataRow(
                        cells: [
                          DataCell(Text(reservation['itemLabel'] ?? 'No label')),
                          DataCell(Text(reservation['itemSize'] ?? 'No Size')),
                          DataCell(Text(reservation['courseLabel'] ?? 'No Course')),
                          DataCell(Text('₱${reservation['price'].toString()}')),
                          DataCell(Text(
                            DateFormat('yyyy-MM-dd HH:mm:ss').format(
                              (reservation['reservationDate'] as Timestamp).toDate(),
                            ),
                          )),
                          DataCell(Text(reservation['userName'] ?? 'Unknown User')),
                          DataCell(
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ElevatedButton(
                                onPressed: () {
                                  _approveReservation(reservation);
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                                  backgroundColor: Colors.deepPurple.shade100,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: FittedBox(
                                  child: Text(
                                    'Approve',
                                    style: TextStyle(
                                      color: Colors.deepPurple,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
