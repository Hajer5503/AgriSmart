import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(AgriSmartApp(cameras: cameras));
}

class AgriSmartApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const AgriSmartApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriSmart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: HomeScreen(cameras: cameras),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────────────────────
class HomeScreen extends StatelessWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Logo + Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.eco, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AgriSmart',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      Text(
                        'Plant Disease Detection',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // Hero card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.camera_alt, color: Colors.white, size: 40),
                    const SizedBox(height: 16),
                    const Text(
                      'Scan a leaf',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Point your camera at a plant leaf to detect diseases instantly — no internet needed.',
                      style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CameraScreen(cameras: cameras),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text(
                        'Open Camera',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Supported Crops',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Apple', 'Tomato', 'Potato', 'Corn', 'Grape',
                  'Peach', 'Pepper', 'Strawberry', 'Orange', 'Cherry',
                ].map((crop) => Chip(
                  label: Text(crop),
                  backgroundColor: const Color(0xFFE8F5E9),
                  labelStyle: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12),
                )).toList(),
              ),
              const Spacer(),
              Center(
                child: Text(
                  '38 disease classes • Offline • ResNet-50',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CAMERA SCREEN
// ─────────────────────────────────────────────────────────────
class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  bool _isReady = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller.initialize();
    if (mounted) setState(() => _isReady = true);
  }

  Future<void> _captureAndAnalyze() async {
    if (!_controller.value.isInitialized || _isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final file = await _controller.takePicture();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(imagePath: file.path),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isReady
          ? Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller),
                // Leaf guide overlay
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.greenAccent, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                // Top bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Center the leaf in the frame',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
                // Capture button
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _captureAndAnalyze,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.greenAccent, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: _isCapturing
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                  color: Color(0xFF2E7D32),
                                  strokeWidth: 3,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: Color(0xFF2E7D32),
                                size: 30,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RESULT SCREEN
// ─────────────────────────────────────────────────────────────
class ResultScreen extends StatefulWidget {
  final String imagePath;
  const ResultScreen({super.key, required this.imagePath});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  static Interpreter? _interpreter;
  static List<String>? _classNames;

  List<Map<String, dynamic>> _predictions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runInference();
  }

  Future<void> _loadModel() async {
    _interpreter ??= await Interpreter.fromAsset('assets/agrismart_disease.tflite');
    if (_classNames == null) {
      final json = await rootBundle.loadString('assets/class_names.json');
      _classNames = List<String>.from(jsonDecode(json));
    }
  }

  Future<void> _runInference() async {
    try {
      await _loadModel();

      // Read and preprocess image
      final rawBytes = await File(widget.imagePath).readAsBytes();
      img.Image? image = img.decodeImage(rawBytes);
      if (image == null) throw Exception('Could not decode image');

      // Resize to 224x224
      image = img.copyResize(image, width: 224, height: 224);

      // Normalize with ImageNet mean/std
      const mean = [0.485, 0.456, 0.406];
      const std  = [0.229, 0.224, 0.225];

      // Build input tensor [1, 224, 224, 3]
      final input = List.generate(
        1, (_) => List.generate(
          224, (y) => List.generate(
            224, (x) {
              final pixel = image!.getPixel(x, y);
              return [
                (pixel.r / 255.0 - mean[0]) / std[0],
                (pixel.g / 255.0 - mean[1]) / std[1],
                (pixel.b / 255.0 - mean[2]) / std[2],
              ];
            },
          ),
        ),
      );

      // Output tensor [1, 38]
      final output = List.generate(1, (_) => List.filled(38, 0.0));
      _interpreter!.run(input, output);

      // Softmax + top-3
      final logits = output[0];
      final maxLogit = logits.reduce((a, b) => a > b ? a : b);
      final exps = logits.map((v) => (v - maxLogit).abs() < 50 ? _exp(v - maxLogit) : 0.0).toList();
      final sumExp = exps.reduce((a, b) => a + b);
      final probs = exps.map((e) => e / sumExp).toList();

      final indexed = List.generate(38, (i) => {'index': i, 'prob': probs[i]});
      indexed.sort((a, b) => (b['prob'] as double).compareTo(a['prob'] as double));

      setState(() {
        _predictions = indexed.take(3).map((e) {
          final name = _classNames![e['index'] as int];
          final parts = name.split('___');
          return {
            'crop':       parts.isNotEmpty ? parts[0].replaceAll('_', ' ') : name,
            'disease':    parts.length > 1  ? parts[1].replaceAll('_', ' ') : 'Unknown',
            'confidence': (e['prob'] as double),
            'isHealthy':  name.toLowerCase().contains('healthy'),
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error    = e.toString();
        _isLoading = false;
      });
    }
  }

  double _exp(double x) => x > -50 ? (1.0 * (1 + x + x*x/2 + x*x*x/6)) : 0.0;

  @override
  Widget build(BuildContext context) {
    final top = _predictions.isNotEmpty ? _predictions[0] : null;
    final isHealthy = top?['isHealthy'] as bool? ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: const Text('Analysis Result'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  SizedBox(height: 16),
                  Text('Analyzing leaf...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Error: $_error', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Captured image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(widget.imagePath),
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Main result card
                      if (top != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isHealthy
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isHealthy
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isHealthy ? Icons.check_circle : Icons.warning_amber_rounded,
                                    color: isHealthy
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFC62828),
                                    size: 28,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    isHealthy ? 'Healthy Plant' : 'Disease Detected',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isHealthy
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFC62828),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _infoRow('Crop',      top['crop'] as String),
                              _infoRow('Condition', top['disease'] as String),
                              _infoRow(
                                'Confidence',
                                '${((top['confidence'] as double) * 100).toStringAsFixed(1)}%',
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      // Top 3 predictions
                      const Text(
                        'Top 3 Predictions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._predictions.asMap().entries.map((entry) {
                        final i = entry.key;
                        final p = entry.value;
                        final conf = (p['confidence'] as double);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: i == 0
                                        ? const Color(0xFF2E7D32)
                                        : Colors.grey[300],
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: i == 0 ? Colors.white : Colors.grey[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${p['crop']} — ${p['disease']}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${(conf * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: i == 0
                                          ? const Color(0xFF2E7D32)
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: conf,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    i == 0
                                        ? const Color(0xFF2E7D32)
                                        : Colors.grey[400]!,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                      // Scan again button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text(
                            'Scan Another Leaf',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
