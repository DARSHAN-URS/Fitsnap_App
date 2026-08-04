import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class ShareHelper {
  // Share PNG capture via share sheet (existing behavior)
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

  // Save PNG/JPEG capture directly to device storage
  static Future<String?> saveWidgetCapture(
    GlobalKey repaintKey, {
    required String fileName,
    bool asJpeg = false,
  }) async {
    try {
      // Request storage / media permission
      if (Platform.isAndroid) {
        if (await Permission.photos.isDenied && await Permission.storage.isDenied) {
          await [Permission.photos, Permission.storage].request();
        }
      }

      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();
      if (pngBytes == null) return null;

      Uint8List fileBytes = pngBytes;
      String extension = 'png';
      // TODO: Convert to JPEG if needed using an image library
      if (asJpeg) {
        // Placeholder: currently saving as PNG even when JPEG requested
        extension = 'jpg';
      }

      final directory = await getExternalStorageDirectory();
      if (directory == null) return null;
      final reportsDir = Directory('${directory.path}/Reports');
      if (!await reportsDir.exists()) {
        await reportsDir.create(recursive: true);
      }
      final filePath = '${reportsDir.path}/$fileName.$extension';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      return filePath;
    } catch (e) {
      debugPrint('Error saving widget capture: $e');
      return null;
    }
  }
}
