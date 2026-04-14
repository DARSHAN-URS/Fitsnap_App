import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/meal_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mealProvider = Provider.of<MealProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FitSnap AI',
          style: TextStyle(
            color: Color(0xFFFF5E3A),
            fontWeight: FontWeight.w900,
            fontSize: 26,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                'Photo Diary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => mealProvider.fetchMeals(),
        color: const Color(0xFFFF5E3A),
        child: mealProvider.meals.isEmpty 
            ? _buildEmptyState() 
            : _buildMealList(mealProvider),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: 600, // Ensure enough height to scroll
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.apple_outlined, 
              size: 100, 
              color: Colors.blueGrey[800],
            ),
            const SizedBox(height: 30),
            const Text(
              "You're all caught up!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "No more meals to show. Start logging your meals to see them here.",
              style: TextStyle(fontSize: 16, color: Colors.blueGrey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealList(MealProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.meals.length,
      itemBuilder: (context, index) {
        final meal = provider.meals[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (meal.imageUrl != null && meal.imageUrl!.isNotEmpty)
                  ? Image.network(
                      meal.imageUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 50,
                          height: 50,
                          color: const Color(0xFF1E293B),
                          child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF5E3A)))),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 50,
                        height: 50,
                        color: const Color(0xFF1E293B),
                        child: const Icon(Icons.broken_image_rounded, color: Colors.blueGrey, size: 20),
                      ),
                    )
                  : Container(
                      width: 50,
                      height: 50,
                      color: const Color(0xFF1E293B),
                      child: const Icon(Icons.fastfood_rounded, color: Color(0xFFFF5E3A), size: 20),
                    ),
            ),
            title: Text(meal.status == 'processing' ? 'Analysing...' : meal.foodName),
            subtitle: Text(meal.status == 'processing' ? 'Processing ingredients...' : '${meal.calories.toInt()} kcal'),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}
