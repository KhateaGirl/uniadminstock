import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:unistock/widgets/custom_text.dart';
import 'package:intl/intl.dart';

class ReservationListPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> _fetchAllPendingReservations() async {
    List<Map<String, dynamic>> allPendingReservations = [];

    QuerySnapshot usersSnapshot = await _firestore.collection('users').get();

    for (var userDoc in usersSnapshot.docs) {
      String userName = userDoc['name'] ?? 'Unknown User';
      print("Processing user: $userName (${userDoc.id})");

      // Fetch pending reservations from the user's cart
      QuerySnapshot cartSnapshot = await _firestore
          .collection('users')
          .doc(userDoc.id)
          .collection('cart')
          .where('status', isEqualTo: 'pending')
          .get();

      for (var cartDoc in cartSnapshot.docs) {
        Map<String, dynamic> reservationData = cartDoc.data() as Map<String, dynamic>;
        String itemLabel = reservationData['itemLabel'] ?? 'Unknown';  // Ensure it won't be null
        String itemSize = reservationData['itemSize'] ?? 'No Size';    // Default value for item size
        String category = reservationData['category'] ?? 'Unknown';    // Ensure it won't be null
        String courseLabel = reservationData['courseLabel'] ?? 'No Course'; // Default value for courseLabel
        Timestamp reservationDate = reservationData['timestamp'] ?? Timestamp.now(); // Ensure timestamp is present

        // Fetch the price directly from the reservation data
        double price = (reservationData['price'] as num?)?.toDouble() ?? 0.0;

        print("Item details - itemLabel: $itemLabel, itemSize: $itemSize, category: $category, price: $price");

        // Add the price and additional fields to the reservation data
        reservationData['price'] = price;
        reservationData['userName'] = userName;
        reservationData['userId'] = userDoc.id;
        reservationData['cartId'] = cartDoc.id;
        reservationData['courseLabel'] = courseLabel;
        reservationData['itemSize'] = itemSize;
        reservationData['reservationDate'] = reservationDate;

        allPendingReservations.add(reservationData);
      }
    }

    return allPendingReservations;
  }

  Future<void> _approveReservation(Map<String, dynamic> reservation) async {
    try {
      // Fetch the user's cart document
      DocumentSnapshot cartDoc = await _firestore
          .collection('users')
          .doc(reservation['userId'])
          .collection('cart')
          .doc(reservation['cartId'])
          .get();

      Timestamp reservationDate = cartDoc['timestamp'];

      // Determine the category based on the subcategory value
      String mainCategory = reservation['category'];
      if (mainCategory == 'college_items' || mainCategory == 'senior_high_items') {
        mainCategory = 'Uniform';
      }

      // Fetch the userId and studentId that matches the userName
      String userName = reservation['userName'];

      // Query the users collection to find the matching user document by name
      QuerySnapshot usersSnapshot = await _firestore
          .collection('users')
          .where('name', isEqualTo: userName)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        throw Exception('User with the provided userName not found');
      }

      DocumentSnapshot userDoc = usersSnapshot.docs.first;

      // Cast the data to Map<String, dynamic> to access fields properly
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;

      String userId = userDoc.id;
      String studentId = (userData != null && userData.containsKey('studentId'))
          ? userData['studentId']
          : 'Unknown';

      // Update the status of the reservation to 'approved'
      await _firestore
          .collection('users')
          .doc(reservation['userId'])
          .collection('cart')
          .doc(reservation['cartId'])
          .update({'status': 'approved'});

      // Add to approved_items collection
      await _firestore.collection('approved_items').add({
        'reservationDate': reservationDate,
        'approvalDate': FieldValue.serverTimestamp(),
        'itemLabel': reservation['itemLabel'],
        'itemSize': reservation['itemSize'],
        'quantity': reservation['quantity'],
        'name': reservation['userName'],
        'pricePerPiece': reservation['price'], // Add price to approved items
      });

      // Store the approved reservation in the admin_transactions collection
      await _firestore.collection('admin_transactions').add({
        'cartItemRef': reservation['cartId'],
        'category': mainCategory,
        'courseLabel': reservation['courseLabel'],
        'itemLabel': reservation['itemLabel'],
        'itemSize': reservation['itemSize'],
        'quantity': reservation['quantity'],
        'studentNumber': studentId, // Corrected to use 'studentId'
        'timestamp': FieldValue.serverTimestamp(), // Approval timestamp
        'userId': userId,
        'userName': userName,
      });

      // Send notification to the user after approving
      await _sendNotificationToUser(userId, userName, reservation);

      print('Reservation approved successfully');
    } catch (e) {
      print('Error approving reservation: $e');
    }
  }

  // Notification function to notify the user
  Future<void> _sendNotificationToUser(String userId, String userName, Map<String, dynamic> reservation) async {
    String notificationMessage = 'Your reservation for ${reservation['itemLabel']} (${reservation['itemSize']}) has been approved.';

    Map<String, dynamic> notificationData = {
      'itemLabel': reservation['itemLabel'],
      'itemSize': reservation['itemSize'],
      'quantity': reservation['quantity'],
      'pricePerPiece': reservation['price'],
      'totalPrice': reservation['price'] * reservation['quantity'], // Calculate total price
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchAllPendingReservations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            print('Error fetching data: ${snapshot.error}');
            return Center(
              child: CustomText(
                text: "Error fetching reservations",
              ),
            );
          } else if (snapshot.hasData && snapshot.data!.isEmpty) {
            return Center(
              child: CustomText(
                text: "No pending reservations found",
              ),
            );
          } else if (snapshot.hasData) {
            final reservations = snapshot.data!;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16.0, // Adjust column spacing to align better
                columns: [
                  DataColumn(label: Text('Item Label')),
                  DataColumn(label: Text('Item Size')),
                  DataColumn(label: Text('Course Label')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('Reservation Date')),
                  DataColumn(label: Text('User Name')),
                  DataColumn(label: Text('Image')),
                  DataColumn(label: Text('Action')),
                ],
                rows: reservations.map((reservation) {
                  return DataRow(cells: [
                    DataCell(Text(reservation['itemLabel'] ?? 'No label')),
                    DataCell(Text(reservation['itemSize'] ?? 'No Size')),
                    DataCell(Text(reservation['courseLabel'] ?? 'No Course')),
                    DataCell(Text('₱${reservation['price'].toString()}')),
                    DataCell(Text(
                      DateFormat('yyyy-MM-dd HH:mm:ss').format((reservation['reservationDate'] as Timestamp).toDate()),
                    )), // Format reservation date
                    DataCell(Text(reservation['userName'] ?? 'Unknown User')),
                    DataCell(
                      reservation['imagePath'] != null && reservation['imagePath'].isNotEmpty
                          ? Image.network(
                        reservation['imagePath'],
                        width: 50,
                        height: 50,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.shopping_cart);
                        },
                      )
                          : Icon(Icons.shopping_cart),
                    ),
                    DataCell(
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            _approveReservation(reservation);
                          },
                          child: Text('Approve'),
                        ),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            );
          } else {
            return Center(
              child: CustomText(
                text: "No data available",
              ),
            );
          }
        },
      ),
    );
  }
}