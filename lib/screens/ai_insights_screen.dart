import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/suggestion_provider.dart';
import '../widgets/app_logo.dart';

class AIInsightsScreen extends StatelessWidget {
  const AIInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05080E),
      appBar: AppBar(
        title: const AppLogo(fontSize: 22),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Consumer<SuggestionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF3ABEF9)));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 30),
                _buildInsightCard(
                  title: 'Dietary Insights',
                  icon: Icons.restaurant_rounded,
                  suggestion: provider.foodSuggestion ?? "Log more meals to get personalized diet tips!",
                  color: const Color(0xFF3ABEF9),
                ),
                const SizedBox(height: 20),
                _buildInsightCard(
                  title: 'Exercise Advice',
                  icon: Icons.fitness_center_rounded,
                  suggestion: provider.exerciseSuggestion ?? "Complete your steps or log an exercise for advice!",
                  color: Colors.orangeAccent,
                ),
                const SizedBox(height: 30),
                _buildTipsSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3ABEF9).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF3ABEF9), size: 28),
            ),
            const SizedBox(width: 15),
            const Text(
              'AI Coach Insights',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Your personalized health recommendations based on your daily activity and logging.',
          style: TextStyle(color: Colors.blueGrey[400], fontSize: 16, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required String title,
    required IconData icon,
    required String suggestion,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2C),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withOpacity(0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            const Color(0xFF161F2C),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            suggestion,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pro Tips',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          _tipItem('Consistent logging improves AI accuracy.'),
          _tipItem('Log water intake to track hydration levels.'),
          _tipItem('Check insights daily for new recommendations.'),
        ],
      ),
    );
  }

  Widget _tipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF3ABEF9), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.blueGrey[300], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
