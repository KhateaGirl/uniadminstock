import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SalesStatisticsPage extends StatefulWidget {
  @override
  _SalesStatisticsPageState createState() => _SalesStatisticsPageState();
}

class _SalesStatisticsPageState extends State<SalesStatisticsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, double> _collegeSalesData = {};
  Map<String, double> _seniorHighSalesData = {};
  String _selectedPeriod = 'Overall';

  @override
  void initState() {
    super.initState();
    _fetchSalesData();
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

  Future<void> _fetchSalesData() async {
    try {
      QuerySnapshot salesSnapshot;

      // Fetch the sales data based on the selected period
      if (_selectedPeriod == 'Weekly' || _selectedPeriod == 'Monthly') {
        DateTime now = DateTime.now();
        DateTime startDate = _selectedPeriod == 'Weekly'
            ? now.subtract(Duration(days: 7))
            : DateTime(now.year, now.month - 1, now.day);

        Timestamp firestoreStartDate = Timestamp.fromDate(startDate);

        salesSnapshot = await _firestore
            .collection('approved_items')
            .where('approvalDate', isGreaterThanOrEqualTo: firestoreStartDate)
            .get();
      } else {
        // Fetch all sales data for "Overall"
        salesSnapshot = await _firestore.collection('approved_items').get();
      }

      Map<String, double> collegeSales = {};
      Map<String, double> seniorHighSales = {};

      // Process Sales Data
      print("Processing Sales Data:");
      for (var doc in salesSnapshot.docs) {
        var sale = doc.data() as Map<String, dynamic>;

        String itemLabel = sale['itemLabel'] ?? 'Unknown';
        String itemSize = sale['itemSize'] ?? 'Unknown';
        double quantity = (sale['quantity'] ?? 0).toDouble();
        String category = sale['category'] ?? 'Unknown';
        String itemKey = '$itemLabel ($itemSize)';

        if (category == 'Senior High') {
          // Senior High sales
          seniorHighSales[itemKey] = (seniorHighSales[itemKey] ?? 0) + quantity;
          print("Matched Senior High Item: $itemKey with quantity: $quantity");
        } else if (category == 'College') {
          // College sales
          collegeSales[itemKey] = (collegeSales[itemKey] ?? 0) + quantity;
          print("Matched College Item: $itemKey with quantity: $quantity");
        } else {
          print("Unknown category for item label: $itemLabel");
        }
      }

      setState(() {
        _collegeSalesData = collegeSales;
        _seniorHighSalesData = seniorHighSales;
        _isLoading = false;
      });

      // Log the results
      print("College Sales Data: $_collegeSalesData");
      print("Senior High Sales Data: $_seniorHighSalesData");

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
        title: Text('Sales Statistics'),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Select Sales Period:"),
              _buildDropdown(),
              SizedBox(height: 20),
              Text(
                "College Item Sales Distribution (${_selectedPeriod})",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 20),
              _buildPieChart(_collegeSalesData),
              SizedBox(height: 50),
              Divider(thickness: 2),
              SizedBox(height: 50),
              Text(
                "Senior High Item Sales Distribution (${_selectedPeriod})",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 20),
              _buildPieChart(_seniorHighSalesData),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> salesData) {
    return Center(
      child: salesData.isEmpty
          ? Text("No data available for this section")
          : Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            flex: 2,
            child: SizedBox(
              height: 300,
              child: PieChart(
                PieChartData(
                  sections: salesData.entries.map((entry) {
                    return PieChartSectionData(
                      color: _getDistinctColor(entry.key),
                      value: entry.value,
                      title: '${entry.value.toInt()}',
                      titleStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      radius: 100,
                    );
                  }).toList(),
                  centerSpaceRadius: 50,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ),
          SizedBox(width: 20),
          Flexible(
            flex: 1,
            child: _buildLegend(salesData),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Map<String, double> salesData) {
    return Column(
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
            Expanded(
              child: Text(
                entry.key,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      }).toList(),
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
    ];
    return colors[label.hashCode % colors.length];
  }
}
