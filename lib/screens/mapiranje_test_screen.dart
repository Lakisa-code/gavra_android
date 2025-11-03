import 'package:flutter/material.dart';

import '../utils/database_validator.dart';

class MapiranjeTestScreen extends StatefulWidget {
  const MapiranjeTestScreen({Key? key}) : super(key: key);

  @override
  State<MapiranjeTestScreen> createState() => _MapiranjeTestScreenState();
}

class _MapiranjeTestScreenState extends State<MapiranjeTestScreen> {
  Map<String, dynamic>? _validationResults;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔍 Mapiranje Baze Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quick Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📊 Quick Status:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildQuickStatus(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _validateComplete,
                    icon: const Icon(Icons.search),
                    label: const Text('Kompletna Validacija'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _autoFix,
                    icon: const Icon(Icons.build),
                    label: const Text('Auto Fix'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Results
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_validationResults != null)
              Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatus() {
    final quickCheck = DatabaseValidator.quickCheck();
    final status = quickCheck['status'] as String;
    final driverCount = quickCheck['hardcodedDriverCount'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              status == 'OK' ? Icons.check_circle : Icons.warning,
              color: status == 'OK' ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text('Status: $status'),
          ],
        ),
        Text('Hardcoded vozači: $driverCount'),
        Text('Email mapiranje: ${quickCheck['emailMappingComplete'] == true ? "✅" : "❌"}'),
      ],
    );
  }

  Widget _buildResults() {
    if (_validationResults == null) return const SizedBox();

    return SingleChildScrollView(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔍 Rezultati Validacije:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Summary
              if (_validationResults!['summary'] != null && _validationResults!['summary'] is Map<String, dynamic>)
                _buildSummarySection(_validationResults!['summary'] as Map<String, dynamic>),

              const SizedBox(height: 16),

              // Vozac Mapping Details
              if (_validationResults!['vozacMapping'] != null &&
                  _validationResults!['vozacMapping'] is Map<String, dynamic>)
                _buildVozacMappingSection(_validationResults!['vozacMapping'] as Map<String, dynamic>),

              const SizedBox(height: 16),

              // JSON Debug View
              ExpansionTile(
                title: const Text('🔧 Raw Data (Debug)'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _validationResults.toString(),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection(Map<String, dynamic> summary) {
    final isValid = summary['isValid'] == true;
    final errorCount = summary['errorCount'] as int? ?? 0;
    final warningCount = summary['warningCount'] as int? ?? 0;

    return Card(
      color: isValid ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isValid ? Icons.check_circle : Icons.error,
                  color: isValid ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  isValid ? 'VALIDACIJA PROŠLA' : 'VALIDACIJA NEUSPEŠNA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isValid ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            if (errorCount > 0) Text('❌ Greške: $errorCount', style: const TextStyle(color: Colors.red)),
            if (warningCount > 0) Text('⚠️ Upozorenja: $warningCount', style: const TextStyle(color: Colors.orange)),
            Text('💡 ${summary['recommendation']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildVozacMappingSection(Map<String, dynamic> mapping) {
    final errors = (mapping['errors'] as List?) ?? [];
    final warnings = (mapping['warnings'] as List?) ?? [];
    final hardcoded = (mapping['hardcodedDrivers'] as List?) ?? [];
    final dynamic = (mapping['dynamicDrivers'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🗂️ Vozac Mapping Detalji:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Hardcoded vozači: ${hardcoded.join(", ")}'),
        Text('Dinamički vozači: ${dynamic.join(", ")}'),
        if (errors.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('❌ Greške:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ...errors.map((error) => Text('  • $error', style: const TextStyle(color: Colors.red))),
        ],
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('⚠️ Upozorenja:', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ...warnings.map((warning) => Text('  • $warning', style: const TextStyle(color: Colors.orange))),
        ],
      ],
    );
  }

  Future<void> _validateComplete() async {
    setState(() {
      _isLoading = true;
      _validationResults = null;
    });

    try {
      final results = await DatabaseValidator.validateComplete();
      setState(() {
        _validationResults = results;
      });
    } catch (e) {
      setState(() {
        _validationResults = {'error': e.toString()};
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _autoFix() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await DatabaseValidator.autoFix();
      setState(() {
        _validationResults = results;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto fix završen! Proverite rezultate.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _validationResults = {'error': e.toString()};
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
