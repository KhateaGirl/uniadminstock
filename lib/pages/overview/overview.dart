import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:unistock/widgets/custom_text.dart';
import 'package:intl/intl.dart';

class OverviewPage extends StatefulWidget {
  @override
  _OverviewPageState createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  int _totalSales = 0;
  String _latestSale = 'N/A';
  double _totalRevenue = 0.0;

  Map<String, double> _collegeSalesData = {};
  Map<String, double> _seniorHighSalesData = {};

  String _selectedPeriod = 'Overall';

  @override
  void initState() {
    super.initState();
    _fetchSalesStatistics();
    _fetchSalesData();
    _fetchTotalRevenueAndSales();
  }

  Future<void> _fetchSalesStatistics() async {
    try {
      QuerySnapshot salesSnapshot = await _firestore.collection('approved_items').get();

      Map<String, double> collegeSales = {};
      Map<String, double> seniorHighSales = {};

      for (var doc in salesSnapshot.docs) {
        var sale = doc.data() as Map<String, dynamic>;
        String itemLabel = sale['itemLabel'] ?? 'Unknown';
        double quantity = (sale['quantity'] ?? 0).toDouble();
        String category = sale['category'] ?? 'Unknown';

        if (category == 'Senior High') {
          seniorHighSales[itemLabel] = (seniorHighSales[itemLabel] ?? 0) + quantity;
        } else if (category == 'College') {
          collegeSales[itemLabel] = (collegeSales[itemLabel] ?? 0) + quantity;
        }
      }

      setState(() {
        _collegeSalesData = collegeSales;
        _seniorHighSalesData = seniorHighSales;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching sales statistics: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTotalRevenueAndSales() async {
    try {
      QuerySnapshot salesSnapshot = await _firestore.collection('approved_items').get();

      double totalRevenue = 0.0;
      int totalSales = salesSnapshot.docs.length;

      for (var doc in salesSnapshot.docs) {
        var sale = doc.data() as Map<String, dynamic>;
        int quantity = sale['quantity'] ?? 0;
        double pricePerPiece = sale['pricePerPiece'] ?? 0.0;
        totalRevenue += quantity * pricePerPiece;
      }

      setState(() {
        _totalSales = totalSales;
        _totalRevenue = totalRevenue;
      });
    } catch (e) {
      print("Error fetching total revenue and sales: $e");
    }
  }

  Future<void> _fetchSalesData() async {
    try {
      QuerySnapshot salesSnapshot;
      DateTime now = DateTime.now();
      DateTime startDate;

      if (_selectedPeriod == 'Weekly') {
        startDate = now.subtract(Duration(days: 7));
      } else if (_selectedPeriod == 'Monthly') {
        startDate = DateTime(now.year, now.month - 1, now.day);
      } else {
        startDate = DateTime(1970); // Fetch all data for "Overall"
      }

      Timestamp firestoreStartDate = Timestamp.fromDate(startDate);

      if (_selectedPeriod == 'Overall') {
        salesSnapshot = await _firestore.collection('admin_transactions').get();
      } else {
        salesSnapshot = await _firestore
            .collection('admin_transactions')
            .where('time_stamp', isGreaterThanOrEqualTo: firestoreStartDate)
            .get();
      }

      Map<String, double> collegeSales = {};
      Map<String, double> seniorHighSales = {};

      for (var doc in salesSnapshot.docs) {
        var transactionData = doc.data() as Map<String, dynamic>;
        List<dynamic> cartItems = transactionData['cartItems'] ?? [];

        for (var item in cartItems) {
          Map<String, dynamic> saleItem = item as Map<String, dynamic>;
          String itemLabel = saleItem['itemLabel'] ?? 'Unknown';
          double quantity = (saleItem['quantity'] ?? 0).toDouble();
          String category = saleItem['category'] ?? 'Unknown';

          if (category == 'senior_high_items') {
            seniorHighSales[itemLabel] = (seniorHighSales[itemLabel] ?? 0) + quantity;
          } else if (category == 'college_items') {
            collegeSales[itemLabel] = (collegeSales[itemLabel] ?? 0) + quantity;
          }
        }
      }

      setState(() {
        _collegeSalesData = collegeSales;
        _seniorHighSalesData = seniorHighSales;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching sales data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText(text: "Overview"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('admin_transactions')
            .orderBy('timestamp', descending: true)
            .limit(1) // Only get the most recent transaction for latest sale
            .snapshots(), // Real-time updates
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: CustomText(text: "Error loading data"));
          }

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            // Get the most recent transaction
            var mostRecentDoc = snapshot.data!.docs.first;
            var mostRecentTransaction = mostRecentDoc.data() as Map<String, dynamic>;
            List<dynamic> cartItems = mostRecentTransaction['cartItems'] ?? [];

            if (cartItems.isNotEmpty) {
              var latestItem = cartItems.first as Map<String, dynamic>;
              _latestSale = latestItem['itemLabel'] ?? 'N/A';
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(text: "Sales Overview", size: 24, weight: FontWeight.bold),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      _buildOverviewCard(Icons.attach_money, 'Total Revenue', '₱${_totalRevenue.toStringAsFixed(2)}'),
                      SizedBox(width: 10),
                      _buildOverviewCard(Icons.shopping_cart, 'Total Sales', '$_totalSales'),
                      SizedBox(width: 10),
                      _buildOverviewCard(Icons.new_releases, 'Latest Sale', '$_latestSale'),
                    ],
                  ),
                  SizedBox(height: 30),
                  CustomText(text: "Sales Statistics", size: 18, weight: FontWeight.bold),
                  SizedBox(height: 10),
                  _buildDropdown(),
                  SizedBox(height: 20),
                  CustomText(text: "College Sales", size: 18, weight: FontWeight.bold),
                  _buildMiniChartWithLegend(_collegeSalesData),
                  SizedBox(height: 20),
                  CustomText(text: "Senior High Sales", size: 18, weight: FontWeight.bold),
                  _buildMiniChartWithLegend(_seniorHighSalesData),
                ],
              ),
            );
          }

          return Center(
            child: CustomText(text: "No sales data available"),
          );
        },
      ),
    );
  }

Widget _buildOverviewCard(IconData icon, String title, String value) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.blueAccent),
              SizedBox(height: 10),
              CustomText(text: title, size: 16),
              SizedBox(height: 5),
              CustomText(text: value, size: 20, weight: FontWeight.bold),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniChartWithLegend(Map<String, double> salesData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: PieChart(
            PieChartData(
              sections: salesData.entries.map((entry) {
                return PieChartSectionData(
                  color: _getDistinctColor(entry.key),
                  value: entry.value,
                  title: '${entry.value.toInt()}',
                );
              }).toList(),
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: salesData.entries.map((entry) {
              return Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    color: _getDistinctColor(entry.key),
                  ),
                  SizedBox(width: 8),
                  Text(entry.key, overflow: TextOverflow.ellipsis),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown() {
    return DropdownButton<String>(
      value: _selectedPeriod,
      items: <String>['Overall', 'Weekly', 'Monthly'].map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedPeriod = newValue!;
          _isLoading = true;
          _fetchSalesData();
        });
      },
    );
  }

  String _formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  Color _getDistinctColor(String label) {
    final colors = <Color>[
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.yellow,
      Colors.brown,
      Colors.pink,
      Colors.teal,
    ];
    return colors[label.hashCode % colors.length];
  }
}
