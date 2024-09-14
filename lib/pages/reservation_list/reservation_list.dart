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

      QuerySnapshot cartSnapshot = await _firestore
          .collection('users')
          .doc(userDoc.id)
          .collection('cart')
          .where('status', isEqualTo: 'pending')
          .get();

      for (var cartDoc in cartSnapshot.docs) {
        Map<String, dynamic> reservationData = cartDoc.data() as Map<String, dynamic>;
        reservationData['userName'] = userName;
        reservationData['userId'] = userDoc.id;
        reservationData['cartId'] = cartDoc.id;
        allPendingReservations.add(reservationData);
      }
    }

    return allPendingReservations;
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
      });

      print('Reservation approved successfully');
    } catch (e) {
      print('Error approving reservation: $e');
    }
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
                    DataCell(Text(reservation['price'].toString() ?? '0')),
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
