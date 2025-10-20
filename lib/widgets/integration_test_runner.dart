import 'package:flutter/material.dart';

import '../tests/integration_test.dart';

/// 🧪 INTEGRATION TEST RUNNER
/// Widget koji može da pokrene integration test iz Admin Screen-a
class IntegrationTestRunner extends StatefulWidget {
  const IntegrationTestRunner({Key? key}) : super(key: key);

  @override
  State<IntegrationTestRunner> createState() => _IntegrationTestRunnerState();
}

class _IntegrationTestRunnerState extends State<IntegrationTestRunner> {
  bool _isRunning = false;
  Map<String, dynamic>? _testResults;
  List<String> _liveResults = [];

  /// 🚀 Pokreni integration test
  Future<void> _runTest() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _testResults = null;
      _liveResults = [];
    });

    try {
      // Pokretam System Integration Test

      final results = await SystemIntegrationTest.runFullTest();

      setState(() {
        _testResults = results;
        _liveResults = List<String>.from((results['results'] as List?) ?? []);
        _isRunning = false;
      });

      // Show success/error notification
      if (!mounted) return;

      if (results['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Integration Test PROŠAO! Aplikacija je 100% stabilna'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Integration Test NEUSPEŠAN: ${results['error']}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isRunning = false;
        _testResults = {
          'success': false,
          'error': e.toString(),
          'results': ['❌ Kritična greška: $e'],
        };
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('💥 Test crash: $e'),
            backgroundColor: Colors.red[800],
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 System Integration Test'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Test Info Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.integration_instructions,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'System Integration Test',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Testira svih 4 glavna screen-a i memori leak prevenciju:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('✅ TimerManager funkcionalnost'),
                        Text('✅ AdminSecurityService sigurnost'),
                        Text('✅ Memory Management (Timer cleanup)'),
                        Text('✅ Navigation Flow između screen-ova'),
                        Text('✅ Screen Instantiation bez grešaka'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Run Test Button
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _runTest,
              icon: _isRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isRunning ? 'Pokretam test...' : 'Pokreni Integration Test'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 16),

            // Test Results
            if (_testResults != null || _liveResults.isNotEmpty)
              Expanded(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _testResults?['success'] == true ? Icons.check_circle : Icons.error,
                              color: _testResults?['success'] == true ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Test Rezultati',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Summary
                        if (_testResults != null && _testResults!['summary'] != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _testResults!['success'] == true ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _testResults!['success'] == true ? Colors.green.shade300 : Colors.red.shade300,
                              ),
                            ),
                            child: Text(
                              _testResults!['summary'] as String? ?? 'Nema rezumlate',
                              style: TextStyle(
                                color: _testResults!['success'] == true ? Colors.green.shade700 : Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Detailed Results
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ListView.builder(
                              itemCount: _liveResults.length,
                              itemBuilder: (context, index) {
                                final result = _liveResults[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    result,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: result.contains('❌')
                                          ? Colors.red
                                          : result.contains('✅')
                                              ? Colors.green
                                              : Colors.black87,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
