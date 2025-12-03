import 'package:flutter/material.dart';
import '../models/wipe_result.dart';
import '../services/wipe_service.dart';
import 'verification_screen.dart';

class WipeProgressScreen extends StatefulWidget {
  final List<String> filePaths;
  final WipeMethod wipeMethod;

  const WipeProgressScreen({
    super.key,
    required this.filePaths,
    required this.wipeMethod,
  });

  @override
  State<WipeProgressScreen> createState() => _WipeProgressScreenState();
}

class _WipeProgressScreenState extends State<WipeProgressScreen>
    with SingleTickerProviderStateMixin {
  final WipeService _wipeService = WipeService();

  double _overallProgress = 0;
  int _currentFileIndex = 0;
  String _currentFileName = '';
  int _currentPass = 1;
  bool _isWiping = false;
  List<WipeResult> _results = [];

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _startWiping();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startWiping() async {
    setState(() {
      _isWiping = true;
      _currentFileName = widget.filePaths.first.split('/').last;
    });

    final results = <WipeResult>[];

    for (int i = 0; i < widget.filePaths.length; i++) {
      final path = widget.filePaths[i];

      setState(() {
        _currentFileIndex = i;
        _currentFileName = path.split('/').last;
      });

      final result = await _wipeService.wipeFile(
        path,
        widget.wipeMethod,
        onProgress: (progress, pass) {
          setState(() {
            _currentPass = pass;
            _overallProgress = (i + progress) / widget.filePaths.length;
          });
        },
      );

      results.add(result);
    }

    setState(() {
      _isWiping = false;
      _results = results;
    });

    // Navigate to verification screen
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationScreen(
            wipeResults: _results,
            wipeMethod: widget.wipeMethod,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Icon
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1 + (_pulseController.value * 0.1),
                      child: Icon(
                        Icons.cleaning_services,
                        size: 80,
                        color: Colors.orange.withOpacity(
                          0.7 + (_pulseController.value * 0.3),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),

                // Progress Circle
                SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: CircularProgressIndicator(
                          value: _overallProgress,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey.shade900,
                          valueColor: const AlwaysStoppedAnimation(Colors.red),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${(_overallProgress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Pass $_currentPass/${widget.wipeMethod.passes}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Status Text
                const Text(
                  'DESTROYING DATA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.red,
                  ),
                ),

                const SizedBox(height: 16),

                // Current File
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _currentFileName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'File ${_currentFileIndex + 1} of ${widget.filePaths.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Warning
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning,
                        color: Colors.orange.shade300,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Do not close the app',
                        style: TextStyle(
                          color: Colors.orange.shade300,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
