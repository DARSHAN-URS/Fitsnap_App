import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class ProgressTab extends StatefulWidget {
  const ProgressTab({super.key});

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  int _selectedSegment = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title
          Text(
            'Progress',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 24),
          
          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: AppTheme.neonPink, size: 48),
                        const SizedBox(height: 6),
                        Text(
                          '7 Days',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Active streak',
                          style: GoogleFonts.inter(
                            color: Colors.black45,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Weekly dot matrix
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            _StreakDot(label: 'M', isActive: true),
                            _StreakDot(label: 'T', isActive: true),
                            _StreakDot(label: 'W', isActive: true),
                            _StreakDot(label: 'T', isActive: true),
                            _StreakDot(label: 'F', isActive: true),
                            _StreakDot(label: 'S', isActive: true),
                            _StreakDot(label: 'S', isActive: true),
                          ],
                        )
                      ],
                    ),
                  )
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.stars_rounded, color: AppTheme.neonAmber, size: 48),
                        const SizedBox(height: 6),
                        Text(
                          '3 Earned',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total achievements',
                          style: GoogleFonts.inter(
                            color: Colors.black45,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Badge mini circles
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.verified_rounded, color: AppTheme.accent, size: 20),
                            SizedBox(width: 6),
                            Icon(Icons.offline_bolt_rounded, color: AppTheme.neonCyan, size: 20),
                            SizedBox(width: 6),
                            Icon(Icons.fitness_center_rounded, color: AppTheme.neonEmerald, size: 20),
                          ],
                        ),
                      ],
                    ),
                  )
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main weight chart card
          _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Weight Progress',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.flag_rounded, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              '-2.1 kg from goal',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 28),
                  
                  // Custom Bezier Chart
                  const WeightCurveChart(),
                  const SizedBox(height: 28),

                  // iOS styled Segment Slider
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _buildSegmentButton(0, '30D'),
                        _buildSegmentButton(1, '90D'),
                        _buildSegmentButton(2, '6M'),
                        _buildSegmentButton(3, 'ALL'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Tip / Insights banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: AppTheme.cardRadius,
              border: Border.all(color: Colors.green.shade100, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_rounded, color: Colors.green, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Analytics Insight',
                        style: GoogleFonts.inter(
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "You've stayed below your calorie budget 6 out of 7 days. Your weight is down by 0.5kg this week!",
                        style: GoogleFonts.inter(
                          color: Colors.green.shade800,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSegmentButton(int index, String label) {
    final isSelected = _selectedSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSegment = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : Colors.black45,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }
}

class _StreakDot extends StatelessWidget {
  final String label;
  final bool isActive;

  const _StreakDot({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.neonEmerald : Colors.grey.shade200,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.neonEmerald.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: isActive
              ? const Icon(Icons.check, size: 10, color: Colors.white)
              : null,
        )
      ],
    );
  }
}

class WeightCurveChart extends StatelessWidget {
  final List<double> dataPoints = const [78.5, 78.2, 77.8, 78.0, 77.3, 76.9, 76.4];
  final List<String> labels = const ['May 1', 'May 5', 'May 10', 'May 15', 'May 20', 'May 25', 'Jun 1'];

  const WeightCurveChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomPaint(
          size: const Size(double.infinity, 160),
          painter: _ChartPainter(dataPoints: dataPoints),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels.map((l) => Text(l, style: GoogleFonts.inter(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w600))).toList(),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> dataPoints;

  _ChartPainter({required this.dataPoints});

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final double width = size.width;
    final double height = size.height;

    // Determine min and max
    double minVal = dataPoints.reduce((a, b) => a < b ? a : b);
    double maxVal = dataPoints.reduce((a, b) => a > b ? a : b);
    
    // Add small buffer to top and bottom of chart
    double range = maxVal - minVal;
    if (range == 0) range = 1.0;
    minVal -= range * 0.15;
    maxVal += range * 0.15;
    range = maxVal - minVal;

    final double stepX = width / (dataPoints.length - 1);
    
    // Draw Grid Lines (3 horizontal lines)
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.5;
    
    for (int i = 0; i < 4; i++) {
      double y = height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
      
      // Draw weight label on grid lines
      final double val = maxVal - (range * (i / 3));
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${val.toStringAsFixed(1)} kg',
          style: GoogleFonts.inter(fontSize: 9, color: Colors.black26, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(4, y - 12));
    }

    // Build the path for the line
    final path = Path();
    final fillPath = Path();

    double getX(int index) => index * stepX;
    double getY(double val) => height - ((val - minVal) / range * height);

    path.moveTo(getX(0), getY(dataPoints[0]));
    fillPath.moveTo(getX(0), height);
    fillPath.lineTo(getX(0), getY(dataPoints[0]));

    for (int i = 0; i < dataPoints.length - 1; i++) {
      final double x1 = getX(i);
      final double y1 = getY(dataPoints[i]);
      final double x2 = getX(i + 1);
      final double y2 = getY(dataPoints[i + 1]);

      // Control points for smooth bezier curve
      final double cx1 = x1 + stepX / 2;
      final double cy1 = y1;
      final double cx2 = x2 - stepX / 2;
      final double cy2 = y2;

      path.cubicTo(cx1, cy1, cx2, cy2, x2, y2);
      fillPath.cubicTo(cx1, cy1, cx2, cy2, x2, y2);
    }

    fillPath.lineTo(getX(dataPoints.length - 1), height);
    fillPath.close();

    // Draw the gradient fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppTheme.accent.withOpacity(0.22),
          AppTheme.accent.withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Draw the main curve line
    final linePaint = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Draw active dot at the last point
    final double lastX = getX(dataPoints.length - 1);
    final double lastY = getY(dataPoints.last);

    final dotShadowPaint = Paint()
      ..color = AppTheme.accent.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    
    final dotOuterPaint = Paint()
      ..color = AppTheme.accent
      ..style = PaintingStyle.fill;

    final dotInnerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(lastX, lastY), 8, dotShadowPaint);
    canvas.drawCircle(Offset(lastX, lastY), 6, dotOuterPaint);
    canvas.drawCircle(Offset(lastX, lastY), 3, dotInnerPaint);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints;
  }
}
