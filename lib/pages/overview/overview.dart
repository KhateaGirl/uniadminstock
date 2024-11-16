import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:unistock/widgets/custom_text.dart';

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
  Map<String, double> _merchSalesData = {};

  String _selectedPeriod = 'Overall';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
    await Future.wait([
      _fetchSalesStatistics(),
      _fetchTotalRevenueAndSales(),
      _fetchLatestSale(),
    ]);
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchLatestSale() async {
    try {
      QuerySnapshot adminLatestSnapshot = await _firestore
          .collection('admin_transactions')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      String latestLabel = 'N/A';

      if (adminLatestSnapshot.docs.isNotEmpty) {
        var adminTransaction = adminLatestSnapshot.docs.first.data() as Map<String, dynamic>;
        latestLabel = adminTransaction['label'] ?? 'N/A';

        if (adminTransaction['items'] is List && (adminTransaction['items'] as List).isNotEmpty) {
          latestLabel = adminTransaction['items'][0]['label'] ?? latestLabel;
        }
      }

      setState(() {
        _latestSale = latestLabel;
      });
    } catch (e) {
      print("Error fetching latest sale: $e");
    }
  }

  Future<void> _fetchSalesStatistics() async {
    try {
      Map<String, double> collegeSales = {};
      Map<String, double> seniorHighSales = {};
      Map<String, double> merchSales = {};

      QuerySnapshot adminTransactionsSnapshot = await _firestore.collection('admin_transactions').get();
      for (var doc in adminTransactionsSnapshot.docs) {
        var transactionData = doc.data() as Map<String, dynamic>;

        if (transactionData['items'] is List) {
          for (var item in transactionData['items']) {
            String itemLabel = item['label'] ?? 'Unknown';
            double quantity = (item['quantity'] ?? 0).toDouble();
            String category = item['mainCategory'] ?? 'Unknown';

            if (category == 'senior high items') {
              seniorHighSales[itemLabel] = (seniorHighSales[itemLabel] ?? 0) + quantity;
            } else if (category == 'college items') {
              collegeSales[itemLabel] = (collegeSales[itemLabel] ?? 0) + quantity;
            } else if (category == 'merch & accessories') {
              merchSales[itemLabel] = (merchSales[itemLabel] ?? 0) + quantity;
            }
          }
        }
      }

      setState(() {
        _collegeSalesData = collegeSales;
        _seniorHighSalesData = seniorHighSales;
        _merchSalesData = merchSales;
      });
    } catch (e) {
      print("Error fetching sales statistics: $e");
    }
  }

  Future<void> _fetchTotalRevenueAndSales() async {
    try {
      double totalRevenue = 0.0;
      int totalSales = 0;

      // Fetch from admin_transactions collection
      QuerySnapshot adminTransactionsSnapshot = await _firestore.collection('admin_transactions').get();
      for (var doc in adminTransactionsSnapshot.docs) {
        var transactionData = doc.data() as Map<String, dynamic>;

        // Extract total transaction price and quantity directly from each document
        totalRevenue += transactionData['totalTransactionPrice'] ?? 0.0;
        totalSales += (transactionData['totalQuantity'] ?? 0) as int;
      }

      setState(() {
        _totalRevenue = totalRevenue;
        _totalSales = totalSales;
      });
    } catch (e) {
      print("Error fetching total revenue and sales: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText(text: "Overview"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _fetchData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CustomText(text: "Sales Overview", size: 24, weight: FontWeight.bold),
            SizedBox(height: 20),
            Row(
              children: [
                _buildOverviewCard(Icons.payments, 'Total Revenue', '₱${_totalRevenue.toStringAsFixed(2)}'),
                SizedBox(width: 10),
                _buildOverviewCard(Icons.shopping_cart, 'Total Sales', '$_totalSales'),
                SizedBox(width: 10),
                _buildOverviewCard(Icons.new_releases, 'Latest Sale', '$_latestSale'),
              ],
            ),
            SizedBox(height: 30),
            Center(
              child: CustomText(text: "Sales Statistics", size: 18, weight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Center(
              child: Column(
                children: [
                  CustomText(text: "College Sales", size: 18, weight: FontWeight.bold),
                  _buildMiniChartWithLegend(_collegeSalesData),
                ],
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  CustomText(text: "Senior High Sales", size: 18, weight: FontWeight.bold),
                  _buildMiniChartWithLegend(_seniorHighSalesData),
                ],
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  CustomText(text: "Merch & Accessories Sales", size: 18, weight: FontWeight.bold),
                  _buildMiniChartWithLegend(_merchSalesData),
                ],
              ),
            ),
          ],
        ),
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
    if (salesData.isEmpty) {
      return Center(child: Text("No sales data available"));
    }

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 350,
            height: 350,
            child: PieChart(
              PieChartData(
                sections: salesData.entries.map((entry) {
                  return PieChartSectionData(
                    color: _getDistinctColor(entry.key),
                    value: entry.value,
                    title: '${entry.value.toInt()}',
                    radius: 90,
                  );
                }).toList(),
                centerSpaceRadius: 35,
                sectionsSpace: 2,
              ),
            ),
          ),
          SizedBox(width: 20),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
        ],
      ),
    );
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
      Colors.indigo,
      Colors.cyan,
    ];
    return colors[label.hashCode % colors.length];
  }
}
