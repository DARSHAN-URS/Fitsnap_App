import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareHelper {
  static Future<void> shareWidgetCapture(GlobalKey repaintKey, String shareText) async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();
      
      if (pngBytes == null) return;
      
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/shared_workout.png');
      await file.writeAsBytes(pngBytes);
      
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: shareText);
    } catch (e) {
      debugPrint('Error sharing widget capture: $e');
    }
  }
}
