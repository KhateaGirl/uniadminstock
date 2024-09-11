import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:unistock/widgets/custom_text.dart';

class ReservationListPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch reservations from all users where status is 'pending'
  Future<List<Map<String, dynamic>>> _fetchAllPendingReservations() async {
    List<Map<String, dynamic>> allPendingReservations = [];

    // Get all users
    QuerySnapshot usersSnapshot = await _firestore.collection('users').get();

    for (var userDoc in usersSnapshot.docs) {
      // Fetch the user's name
      String userName = userDoc['name'] ?? 'Unknown User'; // Assumes there's a 'name' field in the user document

      // For each user, fetch items from the cart collection with status 'pending'
      QuerySnapshot cartSnapshot = await _firestore
          .collection('users')
          .doc(userDoc.id)
          .collection('cart')
          .where('status', isEqualTo: 'pending')
          .get();

      // Add each pending item to the allPendingReservations list
      for (var cartDoc in cartSnapshot.docs) {
        Map<String, dynamic> reservationData = cartDoc.data() as Map<String, dynamic>;
        reservationData['userName'] = userName;  // Add the user's name for reference
        allPendingReservations.add(reservationData);
      }
    }

    return allPendingReservations;
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
            print('Error fetching data: ${snapshot.error}'); // Debug: Print any errors encountered
            return Center(
              child: CustomText(
                text: "Error fetching reservations",
              ),
            );
          } else if (snapshot.hasData && snapshot.data!.isEmpty) {
            print('No pending reservations found'); // Debug: Print if no pending reservations were found
            return Center(
              child: CustomText(
                text: "No pending reservations found",
              ),
            );
          } else if (snapshot.hasData) {
            // Display the list of pending reservations
            final reservations = snapshot.data!;
            print('Displaying reservations: $reservations'); // Debug: Print the reservations to be displayed
            return ListView.builder(
              itemCount: reservations.length,
              itemBuilder: (context, index) {
                final reservation = reservations[index];
                return ListTile(
                  title: Text(reservation['itemLabel'] ?? 'No label'),
                  subtitle: Text('Price: ${reservation['price']} | Status: ${reservation['status']}'),
                  leading: reservation['imagePath'] != null && reservation['imagePath'].isNotEmpty
                      ? FadeInImage.assetNetwork(
                    placeholder: 'assets/images/placeholder.png',  // Path to your local placeholder image
                    image: reservation['imagePath'],
                    imageErrorBuilder: (context, error, stackTrace) {
                      // Display default icon if image fails to load
                      return Icon(Icons.shopping_cart);
                    },
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  )
                      : Icon(Icons.shopping_cart), // Default Flutter icon if no imagePath is available
                  trailing: Text('Name: ${reservation['userName']}'), // Display the user's name
                );
              },
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
