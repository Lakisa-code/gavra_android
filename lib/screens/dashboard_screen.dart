import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? dashboardData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Simulacija podataka - zameniti sa stvarnim podacima iz Supabase
      await Future<void>.delayed(const Duration(seconds: 1));

      setState(() {
        dashboardData = {
          'total_passengers': 150,
          'active_drivers': 25,
          'completed_trips': 89,
          'revenue': 45000.0,
            'passenger_types': {
            'regular': 85,
            'senior': 35,
              'ucenik': 30,
          },
          'monthly_data': [
            {'month': 'Jan', 'trips': 120},
            {'month': 'Feb', 'trips': 135},
            {'month': 'Mar', 'trips': 145},
            {'month': 'Apr', 'trips': 160},
            {'month': 'May', 'trips': 175},
            {'month': 'Jun', 'trips': 189},
          ],
        };
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri učitavanju podataka: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: Theme.of(context).backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 3,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 80,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).glassContainer,
              border: Border.all(
                color: Theme.of(context).glassBorder,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadDashboardData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      _buildChartsSection(),
                      const SizedBox(height: 24),
                      _buildQuickActions(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    if (dashboardData == null) return const SizedBox.shrink();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildSummaryCard(
          'Ukupno putnika',
          '${dashboardData!['total_passengers']}',
          Icons.people,
          Colors.blue,
        ),
        _buildSummaryCard(
          'Aktivni vozači',
          '${dashboardData!['active_drivers']}',
          Icons.drive_eta,
          Colors.green,
        ),
        _buildSummaryCard(
          'Završene vožnje',
          '${dashboardData!['completed_trips']}',
          Icons.check_circle,
          Colors.orange,
        ),
        _buildSummaryCard(
          'Prihod',
          '${dashboardData!['revenue']} RSD',
          Icons.attach_money,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    if (dashboardData == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistike',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Mesečne vožnje',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: _buildLineChart(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Tipovi putnika',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _buildPieChart(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLineChart() {
    final monthlyData = dashboardData!['monthly_data'] as List<dynamic>;

    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < monthlyData.length) {
                  return Text(
                    monthlyData[value.toInt()]['month'].toString(),
                    style: const TextStyle(fontSize: 12),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: monthlyData.asMap().entries.map((entry) {
              return FlSpot(
                entry.key.toDouble(),
                (entry.value['trips'] as num).toDouble(),
              );
            }).toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    final passengerTypes =
        dashboardData!['passenger_types'] as Map<String, dynamic>;
    final colors = [Colors.blue, Colors.green, Colors.orange];

    return PieChart(
      PieChartData(
        sections: passengerTypes.entries.map((entry) {
          final index = passengerTypes.keys.toList().indexOf(entry.key);
          return PieChartSectionData(
            value: (entry.value as num).toDouble(),
            title: '${entry.key}\n${entry.value}',
            color: colors[index % colors.length],
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Brze akcije',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Dodaj putnika',
                Icons.person_add,
                Colors.blue,
                () => _navigateToAddPassenger(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                'Nova vožnja',
                Icons.add_road,
                Colors.green,
                () => _navigateToNewTrip(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Vozači',
                Icons.drive_eta,
                Colors.orange,
                () => _navigateToDrivers(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                'Izveštaji',
                Icons.assessment,
                Colors.purple,
                () => _navigateToReports(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color.withValues(alpha: 0.1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAddPassenger() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dodavanje putnika - u razvoju')),
    );
  }

  void _navigateToNewTrip() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nova vožnja - u razvoju')),
    );
  }

  void _navigateToDrivers() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upravljanje vozačima - u razvoju')),
    );
  }

  void _navigateToReports() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Izveštaji - u razvoju')),
    );
  }
}
