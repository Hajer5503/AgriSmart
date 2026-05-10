import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../features/offline_disease/offline_leaf_scan.dart';

class PlantCameraWidget extends StatefulWidget {
  final int userId;
  final List<CameraDescription> cameras;
  /// Si true : bouton compact style AppBar (verre), sinon FAB vert classique.
  final bool appBarStyle;

  const PlantCameraWidget({
    super.key,
    required this.userId,
    required this.cameras,
    this.appBarStyle = false,
  });

  @override
  State<PlantCameraWidget> createState() => _PlantCameraWidgetState();
}

class _PlantCameraWidgetState extends State<PlantCameraWidget> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.photos.request();
  }

  /// Analyse maladie **hors ligne (TFLite)** sur l’image choisie.
  Future<void> _openOfflineResult(String imagePath) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OfflineLeafResultScreen(imagePath: imagePath),
      ),
    );
  }

  Future<void> _takePicture() async {
    await _requestPermissions();

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (photo != null) await _openOfflineResult(photo.path);
    } catch (e) {
      if (mounted) {
        _showError('Erreur de capture: ${e.toString()}');
      }
    }
  }

  Future<void> _pickFromGallery() async {
    await _requestPermissions();

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (image != null) await _openOfflineResult(image.path);
    } catch (e) {
      if (mounted) {
        _showError('Erreur de sélection: ${e.toString()}');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildOptionsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.appBarStyle) {
      return IconButton(
        icon: const Icon(Icons.camera_alt_rounded),
        tooltip: 'Analyser une plante',
        onPressed: _showOptions,
      );
    }
    return FloatingActionButton(
      onPressed: _showOptions,
      backgroundColor: const Color(0xFF34C759),
      child: const Icon(Icons.camera_alt_rounded, color: Colors.white),
    );
  }

  Widget _buildOptionsSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Analyser une plante',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Caméra ou galerie — détection de maladie hors ligne (TFLite)',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOptionButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Caméra',
                  onTap: () {
                    Navigator.pop(context);
                    _takePicture();
                  },
                ),
                _buildOptionButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Galerie',
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromGallery();
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF34C759), Color(0xFF30D158)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF34C759).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
