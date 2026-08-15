import 'dart:ui';
import 'package:flutter/material.dart';

/// A widget that overlays a semi‑transparent black background with optional blur.
/// Used to render a Strava‑style transparent layout for report screenshots.
class TransparentReportWidget extends StatelessWidget {
  final Widget child;
  final double opacity;
  final double blurSigma;

  const TransparentReportWidget({
    super.key,
    required this.child,
    this.opacity = 0.4,
    this.blurSigma = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              color: Colors.black.withOpacity(opacity),
            ),
          ),
        ),
      ],
    );
  }
}
