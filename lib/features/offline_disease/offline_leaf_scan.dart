import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// On-device ResNet-50 disease detection (TFLite). Entry: [OfflineLeafCameraScreen].
class OfflineLeafCameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const OfflineLeafCameraScreen({super.key, required this.cameras});

  @override
  State<OfflineLeafCameraScreen> createState() => _OfflineLeafCameraScreenState();
}

class _OfflineLeafCameraScreenState extends State<OfflineLeafCameraScreen> {
  late CameraController _controller;
  bool _isReady = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;
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
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => OfflineLeafResultScreen(imagePath: file.path),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    if (widget.cameras.isNotEmpty) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cameras.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scanner hors ligne')),
        body: const Center(
          child: Text('Aucune caméra disponible sur cet appareil.'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isReady
          ? Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller),
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
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
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
                            'Centrez la feuille (hors ligne, TFLite)',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
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
                              color: Colors.greenAccent.withValues(alpha: 0.4),
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

class OfflineLeafResultScreen extends StatefulWidget {
  final String imagePath;
  const OfflineLeafResultScreen({super.key, required this.imagePath});

  @override
  State<OfflineLeafResultScreen> createState() => _OfflineLeafResultScreenState();
}

class _OfflineLeafResultScreenState extends State<OfflineLeafResultScreen> {
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
    if (_interpreter == null) {
      _interpreter = await Interpreter.fromAsset('assets/agrismart_disease.tflite');
      _interpreter!.allocateTensors();
      debugPrint('[AgriSmart] Loaded model: assets/agrismart_disease.tflite');
    }
    if (_classNames == null) {
      final json = await rootBundle.loadString('assets/class_names.json');
      _classNames = List<String>.from(jsonDecode(json));
    }
  }

  Future<void> _runInference() async {
    try {
      await _loadModel();

      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      final inShape = inputTensor.shape;
      final outShape = outputTensor.shape;

      const imgSize = 224;
      final isNchw = inShape.length == 4 && inShape[1] == 3;
      final h = isNchw ? inShape[2] : inShape[1];
      final w = isNchw ? inShape[3] : inShape[2];
      final size = (h > 0 && w > 0) ? h : imgSize;

      final bytes = await File(widget.imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('Unable to decode the captured image.');
      }
      final resized = img.copyResize(decoded, width: size, height: size);

      const mean = [0.485, 0.456, 0.406];
      const std = [0.229, 0.224, 0.225];

      List<double> normPixel(int x, int y) {
        final p = resized.getPixel(x, y);
        return [
          ((p.r / 255.0) - mean[0]) / std[0],
          ((p.g / 255.0) - mean[1]) / std[1],
          ((p.b / 255.0) - mean[2]) / std[2],
        ];
      }

      final dynamic input = isNchw
          ? List.generate(
              1,
              (_) => List.generate(
                3,
                (c) => List.generate(
                  size,
                  (y) => List.generate(
                    size,
                    (x) => normPixel(x, y)[c],
                  ),
                ),
              ),
            )
          : List.generate(
              1,
              (_) => List.generate(
                size,
                (y) => List.generate(size, (x) => normPixel(x, y)),
              ),
            );

      final numClasses = outShape.last;
      final output = List.generate(1, (_) => List<double>.filled(numClasses, 0.0));

      _interpreter!.run(input, output);

      final logits = output[0];
      final maxLogit = logits.reduce(math.max);
      final exps = logits.map((v) => math.exp(v - maxLogit)).toList();
      final sumExp = exps.reduce((a, b) => a + b);
      final probs = exps.map((e) => e / sumExp).toList();

      final indexed = List.generate(numClasses, (i) => {'index': i, 'prob': probs[i]});
      indexed.sort((a, b) => (b['prob'] as double).compareTo(a['prob'] as double));

      setState(() {
        _predictions = indexed.take(3).map((e) {
          final name = _classNames![e['index'] as int];
          final parts = name.split('___');
          return {
            'crop': parts.isNotEmpty ? parts[0].replaceAll('_', ' ') : name,
            'disease': parts.length > 1 ? parts[1].replaceAll('_', ' ') : 'Unknown',
            'confidence': (e['prob'] as double),
            'isHealthy': name.toLowerCase().contains('healthy'),
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = _predictions.isNotEmpty ? _predictions[0] : null;
    final isHealthy = top?['isHealthy'] as bool? ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: const Text('Résultat (hors ligne)'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  SizedBox(height: 16),
                  Text('Analyse…', style: TextStyle(color: Colors.grey)),
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
                        Text('Erreur: $_error', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Retour'),
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
                      if (top != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isHealthy ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
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
                                    isHealthy ? 'Plante saine' : 'Anomalie détectée',
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
                              _infoRow('Culture', top['crop'] as String),
                              _infoRow('Condition', top['disease'] as String),
                              _infoRow(
                                'Confiance',
                                '${((top['confidence'] as double) * 100).toStringAsFixed(1)}%',
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      const Text(
                        'Top 3',
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
                                color: Colors.black.withValues(alpha: 0.05),
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
                                    backgroundColor:
                                        i == 0 ? const Color(0xFF2E7D32) : Colors.grey[300],
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
                                      color: i == 0 ? const Color(0xFF2E7D32) : Colors.grey,
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
                                    i == 0 ? const Color(0xFF2E7D32) : Colors.grey[400]!,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
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
                            'Nouveau scan',
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
