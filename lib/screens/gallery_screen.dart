import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/progress_provider.dart';
import '../models/progress_photo.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  Future<void> _pickAndUpload(BuildContext context) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final weightController = TextEditingController();
      final descController = TextEditingController();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Add Progress Log', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Weight (kg)', labelStyle: TextStyle(color: Colors.blueGrey)),
              ),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Note (Optional)', labelStyle: TextStyle(color: Colors.blueGrey)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final provider = Provider.of<ProgressProvider>(context, listen: false);
                provider.uploadPhoto(
                  File(image.path),
                  weight: double.tryParse(weightController.text),
                  description: descController.text,
                );
                Navigator.pop(context);
              },
              child: const Text('Upload'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProgressProvider>(context);
    final baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8000';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Progress Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: provider.isLoading && provider.photos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => provider.fetchPhotos(),
              child: provider.photos.isEmpty 
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: provider.photos.length,
                    itemBuilder: (context, index) {
                      final photo = provider.photos[index];
                      return _buildGalleryItem(context, photo, baseUrl);
                    },
                  ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickAndUpload(context),
        backgroundColor: const Color(0xFFFF5E3A),
        child: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_rounded, size: 80, color: Colors.blueGrey[800]),
          const SizedBox(height: 16),
          const Text('No transformation photos yet', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Upload your first photo to track your journey!', style: TextStyle(color: Colors.blueGrey)),
        ],
      ),
    );
  }

  Widget _buildGalleryItem(BuildContext context, ProgressImg photo, String baseUrl) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.network(
                baseUrl + photo.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => const Center(child: Icon(Icons.broken_image, color: Colors.blueGrey)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy').format(photo.createdAt),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  if (photo.weight != null)
                    Text('${photo.weight} kg', style: const TextStyle(color: Color(0xFFFF5E3A), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
