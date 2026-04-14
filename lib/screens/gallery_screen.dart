import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/progress_provider.dart';
import '../providers/meal_provider.dart';
import '../models/progress_photo.dart';
import '../models/meal.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  int _selectedView = 0; // 0 for Progress, 1 for Meals

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
    final progressProvider = Provider.of<ProgressProvider>(context);
    final mealProvider = Provider.of<MealProvider>(context);
    final baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8000';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Visual History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
            child: _buildToggle(),
          ),
        ),
      ),
      body: _selectedView == 0 
          ? _buildProgressGrid(progressProvider, baseUrl)
          : _buildMealsGrid(mealProvider, baseUrl),
      floatingActionButton: _selectedView == 0 ? FloatingActionButton(
        onPressed: () => _pickAndUpload(context),
        backgroundColor: const Color(0xFFFF5E3A),
        child: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildToggle() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _toggleItem(0, 'Transformation', Icons.auto_awesome_rounded)),
          Expanded(child: _toggleItem(1, 'Meals', Icons.restaurant_rounded)),
        ],
      ),
    );
  }

  Widget _toggleItem(int index, String label, IconData icon) {
    bool isSelected = _selectedView == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedView = index),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5E3A) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.blueGrey),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.blueGrey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressGrid(ProgressProvider provider, String baseUrl) {
    if (provider.isLoading && provider.photos.isEmpty) return const Center(child: CircularProgressIndicator());
    if (provider.photos.isEmpty) return _buildEmptyState('No transformation photos yet', Icons.photo_library_rounded);

    return RefreshIndicator(
      onRefresh: () => provider.fetchPhotos(),
      child: GridView.builder(
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
          return _buildGalleryItem(photo.imageUrl, DateFormat('MMM dd, yyyy').format(photo.createdAt), photo.weight?.toString(), baseUrl);
        },
      ),
    );
  }

  Widget _buildMealsGrid(MealProvider provider, String baseUrl) {
    final mealsWithImages = provider.meals.where((m) => m.imageUrl != null).toList();
    if (mealsWithImages.isEmpty) return _buildEmptyState('No meal photos yet', Icons.fastfood_rounded);

    return RefreshIndicator(
      onRefresh: () => provider.fetchMeals(),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: mealsWithImages.length,
        itemBuilder: (context, index) {
          final meal = mealsWithImages[index];
          return _buildGalleryItem(meal.imageUrl!, meal.foodName, '${meal.calories.toInt()} kcal', baseUrl, compact: true);
        },
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.blueGrey[800]),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildGalleryItem(String url, String title, String? subtitle, String baseUrl, {bool compact = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url.startsWith('http') 
                  ? url 
                  : (baseUrl.endsWith('/') ? baseUrl + url.replaceFirst('/', '') : baseUrl + (url.startsWith('/') ? url : '/$url')),
              fit: BoxFit.cover,
              errorBuilder: (context, _, __) => const Center(child: Icon(Icons.broken_image, color: Colors.blueGrey)),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.all(compact ? 4 : 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: compact ? 10 : 12, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                    if (subtitle != null)
                      Text(subtitle, style: TextStyle(color: const Color(0xFFFF5E3A), fontSize: compact ? 9 : 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
