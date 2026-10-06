import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactHelper {
  /// Opens WhatsApp chat with the target phone number.
  /// Automatically strips out non-digits from the number.
  static Future<bool> openWhatsApp(String phone, {String? message}) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.isEmpty) return false;

      final urlString = message != null && message.isNotEmpty
          ? 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}'
          : 'https://wa.me/$cleanPhone';

      final uri = Uri.parse(urlString);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
      return false;
    }
  }

  /// Initiates a native phone call to the target phone number.
  static Future<bool> makePhoneCall(String phone) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      if (cleanPhone.isEmpty) return false;

      final uri = Uri.parse('tel:$cleanPhone');
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error making phone call: $e');
      return false;
    }
  }
}
