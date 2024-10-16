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
    _fetchTotalRevenueAndSales();
    _fetchLatestSale();
  }

  Future<void> _fetchLatestSale() async {
    try {
      QuerySnapshot latestSaleSnapshot = await _firestore
          .collection('admin_transactions')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (latestSaleSnapshot.docs.isNotEmpty) {
        var mostRecentDoc = latestSaleSnapshot.docs.first;
        var latestTransaction = mostRecentDoc.data() as Map<String, dynamic>;
        String latestlabel = latestTransaction['label'] ?? 'N/A';

        setState(() {
          _latestSale = latestlabel;
        });
      }
    } catch (e) {
      print("Error fetching latest sale: $e");
    }
  }

  Future<void> _fetchSalesStatistics() async {
    try {
      QuerySnapshot salesSnapshot = await _firestore.collection('approved_items').get();

      Map<String, double> collegeSales = {};
      Map<String, double> seniorHighSales = {};

      for (var doc in salesSnapshot.docs) {
        var transactionData = doc.data() as Map<String, dynamic>;

        String label = transactionData['label'] ?? 'Unknown';
        double quantity = (transactionData['quantity'] ?? 0).toDouble();
        String category = transactionData['mainCategory'] ?? 'Unknown';
        String courseLabel = transactionData['subCategory'] ?? 'Unknown';

        if (category == 'college_items') {
          collegeSales[label] = (collegeSales[label] ?? 0) + quantity;
        } else if (category == 'senior_high_items') {
          seniorHighSales[label] = (seniorHighSales[label] ?? 0) + quantity;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText(text: "Overview"),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
            CustomText(text: "College Sales", size: 18, weight: FontWeight.bold),
            _buildMiniChartWithLegend(_collegeSalesData),
            SizedBox(height: 20),
            CustomText(text: "Senior High Sales", size: 18, weight: FontWeight.bold),
            _buildMiniChartWithLegend(_seniorHighSalesData),
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
