import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:unistock/widgets/custom_text.dart';

class ReservationListPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> _fetchAllPendingReservations() async {
    List<Map<String, dynamic>> allPendingReservations = [];

    QuerySnapshot usersSnapshot = await _firestore.collection('users').get();

    for (var userDoc in usersSnapshot.docs) {
      String userName = userDoc['name'] ?? 'Unknown User';

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
        String itemSize = reservationData['itemSize'] ?? 'Unknown';    // Ensure it won't be null
        String category = reservationData['category'] ?? 'Unknown';    // Ensure it won't be null

        // Fetch price from the inventory based on itemLabel and itemSize
        double price = await _fetchItemPrice(itemLabel, itemSize, category);

        // Add the price to the reservation data
        reservationData['price'] = price;

        reservationData['userName'] = userName;
        reservationData['userId'] = userDoc.id;
        reservationData['cartId'] = cartDoc.id;

        allPendingReservations.add(reservationData);
      }
    }

    return allPendingReservations;
  }

  // Function to fetch price based on itemLabel, itemSize, and category (College/Senior High)
  Future<double> _fetchItemPrice(String itemLabel, String itemSize, String category) async {
    try {
      String collection = category == 'Senior High' ? 'Senior_high_items' : 'College_items';

      // Fetch the item from the Inventory_stock collection
      DocumentSnapshot itemSnapshot = await _firestore
          .collection('Inventory_stock')
          .doc(collection)
          .collection('Items')
          .doc(itemLabel)
          .get();

      if (itemSnapshot.exists) {
        Map<String, dynamic> itemData = itemSnapshot.data() as Map<String, dynamic>? ?? {};

        // Check if the size exists and has a price
        if (itemData != null && itemData.containsKey(itemSize)) {
          return itemData[itemSize]['price']?.toDouble() ?? 0.0;
        } else {
          print("Size not found for item: $itemLabel, size: $itemSize");
        }
      } else {
        print("Item not found in inventory: $itemLabel");
      }
    } catch (e) {
      print("Error fetching item price: $e");
    }

    return 0.0; // Return 0 if no price is found
  }

  Future<void> _approveReservation(Map<String, dynamic> reservation) async {
    try {
      DocumentSnapshot cartDoc = await _firestore
          .collection('users')
          .doc(reservation['userId'])
          .collection('cart')
          .doc(reservation['cartId'])
          .get();

      Timestamp reservationDate = cartDoc['timestamp'];

      await _firestore
          .collection('users')
          .doc(reservation['userId'])
          .collection('cart')
          .doc(reservation['cartId'])
          .update({'status': 'approved'});

      await _firestore.collection('approved_items').add({
        'reservationDate': reservationDate,
        'approvalDate': FieldValue.serverTimestamp(),
        'itemLabel': reservation['itemLabel'],
        'itemSize': reservation['itemSize'],
        'quantity': reservation['quantity'],
        'name': reservation['userName'],
        'pricePerPiece': reservation['price'], // Add price to approved items
      });

      // Send notification to the user after approving
      await _sendNotificationToUser(reservation['userId'], reservation['userName'], reservation);

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
            print('No pending reservations found');
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
                columns: [
                  DataColumn(label: Text('Item Label')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('User Name')),
                  DataColumn(label: Text('Image')),
                  DataColumn(label: Text('Action')),
                ],
                rows: reservations.map((reservation) {
                  return DataRow(cells: [
                    DataCell(Text(reservation['itemLabel'] ?? 'No label')),
                    DataCell(Text('₱${reservation['price'].toString()}')), // Show price
                    DataCell(Text(reservation['status'] ?? 'No status')),
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
                      ElevatedButton(
                        onPressed: () {
                          _approveReservation(reservation);
                        },
                        child: Text('Approve'),
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
