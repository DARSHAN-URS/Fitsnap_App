import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double fontSize;
  final Color? color;
  final bool showAI;

  const AppLogo({
    super.key,
    this.fontSize = 24,
    this.color,
    this.showAI = false,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          color: color ?? Colors.white,
          letterSpacing: -0.5,
        ),
        children: [
          const TextSpan(
            text: 'Sab',
            style: TextStyle(
              color: Color(0xFF3ABEF9), // The blue from the image
            ),
          ),
          const TextSpan(
            text: 'Track',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          if (showAI)
            const TextSpan(
              text: ' AI',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.blueGrey,
              ),
            ),
        ],
      ),
    );
  }
}
