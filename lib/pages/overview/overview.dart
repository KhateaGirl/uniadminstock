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

  int _totalSales = 0;
  String _latestSale = 'N/A';
  bool _isLoading = true;
  double _totalRevenue = 0.0;

  Map<String, double> _collegeSalesData = {};
  Map<String, double> _seniorHighSalesData = {};

  @override
  void initState() {
    super.initState();
    _fetchSalesHistory();
    _fetchSalesStatistics();
  }

  Future<void> _fetchSalesHistory() async {
    try {
      QuerySnapshot approvedItemsSnapshot = await _firestore
          .collection('approved_items')
          .orderBy('approvalDate', descending: true)
          .get();

      if (approvedItemsSnapshot.docs.isNotEmpty) {
        double totalRevenue = 0.0;
        setState(() {
          _totalSales = approvedItemsSnapshot.size;
          var latestSale = approvedItemsSnapshot.docs.first.data() as Map<String, dynamic>;
          _latestSale = latestSale['itemLabel'] ?? 'N/A';

          // Assuming each document has a 'price' field
          approvedItemsSnapshot.docs.forEach((doc) {
            totalRevenue += (doc.data() as Map<String, dynamic>)['price'] ?? 0.0;
          });
          _totalRevenue = totalRevenue;
        });
      }
    } catch (e) {
      print("Error fetching sales history: $e");
    }
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
        String itemKey = itemLabel;

        if (itemLabel.contains('Senior')) {
          seniorHighSales[itemKey] = (seniorHighSales[itemKey] ?? 0) + quantity;
        } else {
          collegeSales[itemKey] = (collegeSales[itemKey] ?? 0) + quantity;
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
                _buildOverviewCard(Icons.attach_money, 'Total Revenue', '\$$_totalRevenue'),
                SizedBox(width: 10),
                _buildOverviewCard(Icons.shopping_cart, 'Total Sales', '$_totalSales'),
                SizedBox(width: 10),
                _buildOverviewCard(Icons.new_releases, 'Latest Sale', '$_latestSale'),
              ],
            ),
            SizedBox(height: 30),
            CustomText(text: "College Sales", size: 18, weight: FontWeight.bold),
            _buildMiniChartWithLegend(_collegeSalesData),  // Updated to include legend
            SizedBox(height: 20),
            CustomText(text: "Senior High Sales", size: 18, weight: FontWeight.bold),
            _buildMiniChartWithLegend(_seniorHighSalesData),  // Updated to include legend
            SizedBox(height: 30),
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

  // Updated function to build the pie chart with a legend on the side
  Widget _buildMiniChartWithLegend(Map<String, double> salesData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Constrain the pie chart to a specific width and height
        SizedBox(
          width: 150,  // Set a fixed width for the pie chart
          height: 150,  // Set a fixed height for the pie chart
          child: PieChart(
            PieChartData(
              sections: salesData.entries.map((entry) {
                return PieChartSectionData(
                  color: _getDistinctColor(entry.key), // Set distinct colors for each section
                  value: entry.value,
                  title: '${entry.value.toInt()}',
                );
              }).toList(),
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        SizedBox(width: 20), // Space between the chart and the legend
        // Legend on the right, wrapped in Expanded to avoid overflow
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: salesData.entries.map((entry) {
              return Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    color: _getDistinctColor(entry.key), // Same color as the chart
                  ),
                  SizedBox(width: 8),
                  Text(entry.key, overflow: TextOverflow.ellipsis),  // Handle long labels
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Function to generate distinct colors for the chart sections and legend
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

  // Helper function to build a bar chart for a given category
  Widget _buildCategorySalesChart(String title, Map<String, double> salesData) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 200, width: 150, child: _buildBarChart(salesData)),
      ],
    );
  }

  Widget _buildBarChart(Map<String, double> salesData) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,  // Use spaceEvenly for better spacing
        barGroups: salesData.entries.map((entry) {
          return BarChartGroupData(
            x: entry.key.hashCode,
            barsSpace: 15,  // Add space between bars
            barRods: [
              BarChartRodData(
                toY: entry.value,  // Updated 'y' to 'toY'
                width: 20,  // Bar width
                color: Colors.blue,  // Corrected: Use 'color' instead of 'colors'
              ),
            ],
          );
        }).toList(),
        barTouchData: BarTouchData(enabled: false),  // Disable touch feedback to avoid clutter
        gridData: FlGridData(show: true),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.black, width: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final itemLabel = salesData.keys.firstWhere(
                      (key) => key.hashCode == value.toInt(),
                  orElse: () => '',
                );
                return Text(
                  itemLabel.length > 6 ? itemLabel.substring(0, 6) + '...' : itemLabel,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
