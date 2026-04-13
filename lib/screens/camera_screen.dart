import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/meal_provider.dart';
import '../models/meal.dart';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isCaptured = false;
  bool _isAnalyzing = false;
  bool _isCameraReady = false;
  XFile? _imageFile;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // 1. Request Permission
    final status = await Permission.camera.request();
    if (status.isDenied) {
      // Handle the case where the user denies permission
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required to analyze meals.')),
        );
      }
      return;
    }

    // 2. Get available cameras
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // 3. Initialize Controller
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {
      print('Camera Error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final image = await _controller!.takePicture();
      
      setState(() {
        _isAnalyzing = true;
      });

      final mealProvider = Provider.of<MealProvider>(context, listen: false);
      await mealProvider.addMealWithImage(image.path);

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal uploaded! AI analysis started...'),
            backgroundColor: Color(0xFFFF5E3A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Capture Error: $e');
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process image: $e')),
        );
      }
    }
  }

  void _reset() {
    setState(() {
      _isCaptured = false;
      _isAnalyzing = false;
      _imageFile = null;
    });
  }

  void _saveMeal(BuildContext context) {
    // This is now handled directly in _captureImage for performance
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _isCaptured ? _buildResultView() : _buildCameraPreview(),
          if (_isAnalyzing) _buildAnalyzingOverlay(),
          _buildTopControls(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraReady || _controller == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return Stack(
      children: [
        CameraPreview(_controller!),
        // Camera Overlay (Focus Brackets, etc.)
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              color: Colors.black.withOpacity(0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 32),
                  ),
                  GestureDetector(
                    onTap: _captureImage,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.flash_off_rounded, color: Colors.white, size: 32),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ],
    );
  }

  Widget _buildResultView() {
    return Container(
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1525351484163-7529414344d8'),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detected Meal',
                    style: TextStyle(fontSize: 14, color: Colors.blueGrey),
                  ),
                  const Text(
                    'Avocado Toast',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMacroInfo('Calories', '380', const Color(0xFF38BDF8)),
                      _buildMacroInfo('Protein', '10g', Colors.orangeAccent),
                      _buildMacroInfo('Carbs', '45g', Colors.greenAccent),
                      _buildMacroInfo('Fat', '18g', Colors.purpleAccent),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _reset,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.blueGrey),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: const Text('Retake', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _saveMeal(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5E3A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: const Text('Save Meal', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroInfo(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildAnalyzingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text(
              'Analyzing with AI...',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () {
                if (_isCaptured) {
                  _reset();
                } else {
                  Navigator.pop(context);
                }
              },
              icon: Icon(
                _isCaptured ? Icons.arrow_back_rounded : Icons.close_rounded, 
                color: Colors.white, size: 30
              ),
            ),
          ],
        ),
      ),
    );
  }
}
