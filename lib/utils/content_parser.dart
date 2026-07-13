import 'package:flutter/widgets.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/scan_record.dart';

/// Parsed Wi-Fi credentials extracted from a `WIFI:` QR payload.
class WifiCredentials {
  final String ssid;
  final String password;
  final String encryption; // WPA, WEP, or nopass
  final bool hidden;

  WifiCredentials({
    required this.ssid,
    required this.password,
    required this.encryption,
    required this.hidden,
  });
}

/// Central place for turning an ML Kit [Barcode] into a friendly
/// [ScanContentType] + display label, and for extracting structured data
/// (like Wi-Fi credentials) from raw payloads.
class ContentParser {
  ContentParser._();

  static ScanContentType classify(Barcode barcode) {
    switch (barcode.type) {
      case BarcodeType.url:
        return ScanContentType.url;
      case BarcodeType.wifi:
        return ScanContentType.wifi;
      case BarcodeType.contactInfo:
        return ScanContentType.contact;
      case BarcodeType.email:
        return ScanContentType.email;
      case BarcodeType.phone:
        return ScanContentType.phone;
      case BarcodeType.sms:
        return ScanContentType.sms;
      default:
        final value = barcode.rawValue ?? '';
        if (value.startsWith('WIFI:')) return ScanContentType.wifi;
        if (value.startsWith('http://') || value.startsWith('https://')) {
          return ScanContentType.url;
        }
        return ScanContentType.text;
    }
  }

  /// Localized display label for a content type. Requires a [context] so it
  /// can pull the right string for the app's current language (EN/VI).
  static String label(BuildContext context, ScanContentType type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case ScanContentType.url:
        return l10n.contentTypeUrl;
      case ScanContentType.wifi:
        return l10n.contentTypeWifi;
      case ScanContentType.contact:
        return l10n.contentTypeContact;
      case ScanContentType.email:
        return l10n.contentTypeEmail;
      case ScanContentType.phone:
        return l10n.contentTypePhone;
      case ScanContentType.sms:
        return l10n.contentTypeSms;
      case ScanContentType.text:
        return l10n.contentTypeText;
    }
  }

  /// Parses a raw `WIFI:T:WPA;S:MyNetwork;P:password123;H:false;;` string.
  static WifiCredentials? parseWifi(String raw) {
    if (!raw.startsWith('WIFI:')) return null;
    String ssid = '', password = '', encryption = 'nopass';
    bool hidden = false;

    final body = raw.substring(5);
    final parts = body.split(';');
    for (final part in parts) {
      if (part.startsWith('S:')) ssid = _unescape(part.substring(2));
      if (part.startsWith('P:')) password = _unescape(part.substring(2));
      if (part.startsWith('T:')) encryption = part.substring(2);
      if (part.startsWith('