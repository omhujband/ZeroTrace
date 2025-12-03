import 'package:flutter/material.dart';
import '../models/wipe_result.dart';
import '../services/wipe_service.dart';
import 'decision_screen.dart';

class VerificationScreen extends StatefulWidget {
  final List<WipeResult> wipeResults;
  final WipeMethod wipeMethod;

  const VerificationScreen({
    super.key,
    required this.wipeResults,
    required this.wipeMethod,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final WipeService _wipeService = WipeService();
  Map<String, Map<String, dynamic>> _verificationData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVerificationData();
  }

  Future<void> _loadVerificationData() async {
    final data = <String, Map<String, dynamic>>{};

    for (final result in widget.wipeResults) {
      if (result.success) {
        final verification = await _wipeService.verifyCorruption(
          result.filePath,
        );
        data[result.filePath] = verification;
      }
    }

    setState(() {
      _verificationData = data;
      _isLoading = false;
    });
  }

  void _showRawData(WipeResult result) {
    final verification = _verificationData[result.filePath];
    final sampleBytes = verification?['sampleBytes'];
    final sampleHex = verification?['sampleHex'];

    // FIXED: Explicitly convert to proper types
    final List<int> bytesList = (sampleBytes is List)
        ? List<int>.from(sampleBytes)
        : <int>[];
    final String hexString = (sampleHex is String) ? sampleHex : '';

    // FIXED: Explicitly get boolean value
    final bool isAllZeros = verification?['isAllZeros'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                '🔍 Raw Data: ${result.fileName}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This is what the file contains now (first 200 bytes):',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 16),

              // Hex View Label
              const Text(
                'HEX VIEW:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Hex Data Display
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Text(
                      hexString.isNotEmpty ? hexString : 'No data available',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Explanation - FIXED: Using the boolean variable
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isAllZeros
                            ? 'All bytes are zeros - data completely wiped!'
                            : 'Random bytes - original data destroyed!',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _proceedToDecision() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DecisionScreen(
          wipeResults: widget.wipeResults,
          wipeMethod: widget.wipeMethod,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final successCount = widget.wipeResults.where((r) => r.success).length;
    final failCount = widget.wipeResults.where((r) => !r.success).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('✅ Verify Data Destruction'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade900, Colors.green.shade800],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.verified_user,
                        size: 50,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'DATA DESTROYED',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$successCount file(s) successfully wiped',
                        style: TextStyle(color: Colors.green.shade100),
                      ),
                      if (failCount > 0)
                        Text(
                          '$failCount file(s) failed',
                          style: const TextStyle(color: Colors.orange),
                        ),
                    ],
                  ),
                ),

                // Instruction
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.touch_app, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tap on any file to see the raw corrupted data '
                            'and verify the original content is destroyed.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Files List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.wipeResults.length,
                    itemBuilder: (context, index) {
                      final result = widget.wipeResults[index];
                      final verification = _verificationData[result.filePath];

                      // FIXED: Explicitly get message as String
                      final String message =
                          (verification?['message'] is String)
                          ? verification!['message'] as String
                          : 'Data destroyed';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: result.success
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              result.success ? Icons.check : Icons.error,
                              color: result.success ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(
                            result.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            result.success
                                ? message
                                : (result.error ?? 'Failed'),
                            style: TextStyle(
                              fontSize: 12,
                              color: result.success
                                  ? Colors.green.shade300
                                  : Colors.red.shade300,
                            ),
                          ),
                          trailing: result.success
                              ? IconButton(
                                  icon: const Icon(Icons.code, size: 20),
                                  tooltip: 'View Raw Data',
                                  onPressed: () => _showRawData(result),
                                )
                              : null,
                          onTap: result.success
                              ? () => _showRawData(result)
                              : null,
                        ),
                      );
                    },
                  ),
                ),

                // Next Button
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _proceedToDecision,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text(
                        'CONTINUE → DELETE OR KEEP FILES',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
