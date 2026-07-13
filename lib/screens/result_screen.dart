import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/scan_record.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';
import '../utils/content_parser.dart';

/// Shown immediately after a successful scan (or when opening a history
/// item). Displays the content type, raw value, contextual action buttons,
/// and a Native Ad embedded in the card layout - this is the primary
/// monetization surface of the app.
class ResultScreen extends StatefulWidget {
  final ScanRecord record;
  const ResultScreen({super.key, required this.record});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  NativeAd? _nativeAd;
  bool _nativeAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    _nativeAd = AdService.instance.createNativeAd(
      onLoaded: (ad) {
        if (mounted) setState(() => _nativeAdLoaded = true);
      },
      onFailed: (ad, error) {
        ad.dispose();
        debugPrint('Native ad failed: $error');
      },
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.record.rawValue));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.copiedToClipboard)),
    );
    // Frequency-capped interstitial: shows once every 3 ad-eligible actions.
    await AdService.instance.maybeShowInterstitial();
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.tryParse(widget.record.rawValue);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    await AdService.instance.maybeShowInterstitial();
  }

  Future<void> _connectToWifi() async {
    // Android doesn't allow programmatic Wi-Fi connection with credentials
    // pre-filled from a third-party app on modern versions; the best UX is
    // to copy the password and deep-link to Wi-Fi settings for the user to
    // tap their network.
    final wifi = ContentParser.parseWifi(widget.record.rawValue);
    if (wifi != null && wifi.password.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: wifi.password));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.wifiPasswordCopied)),
    );
    const intentUri = 'android.settings.WIFI_SETTINGS';
    try {
      await launchUrl(Uri.parse('package:$intentUri'));
    } catch (_) {
      // Fallback: no-op if the settings deep link isn't resolvable on device.
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(ShareParams(text: widget.record.rawValue));
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final type = record.contentType;
    final wifi = type == ScanContentType.wifi ? ContentParser.parseWifi(record.rawValue) : null;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.resultTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ContentCard(type: type, record: record, wifi: wifi),
              const SizedBox(height: 16),
              _ActionButtons(
                type: type,
                onOpenBrowser: _openInBrowser,
                onConnectWifi: _connectToWifi,
                onCopy: _copyToClipboard,
                onShare: _share,
              ),
              const SizedBox(height: 20),
              // --- Native Ad embedded inside the result layout ---
              if (_nativeAdLoaded && _nativeAd != null) _NativeAdCard(ad: _nativeAd!),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final ScanContentType type;
  final ScanRecord record;
  final WifiCredentials? wifi;

  const _ContentCard({required this.type, required this.record, required this.wifi});

  IconData get _icon {
    switch (type) {
      case ScanContentType.url:
        return Icons.link_rounded;
      case ScanContentType.wifi:
        return Icons.wifi_rounded;
      case ScanContentType.contact:
        return Icons.contact_page_rounded;
      case ScanContentType.email:
        return Icons.email_rounded;
      case ScanContentType.phone:
        return Icons.phone_rounded;
      case ScanContentType.sms:
        return Icons.sms_rounded;
      case ScanContentType.text:
        return Icons.text_snippet_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_icon, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ContentParser.label(context, type),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      Text(
                        record.format,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            if (wifi != null) ...[
              _KeyValueRow(label: l10n.wifiSsidLabel, value: wifi!.ssid),
              const SizedBox(height: 8),
              _KeyValueRow(label: l10n.wifiPasswordLabel, value: wifi!.password.isEmpty ? l10n.none : wifi!.password),
              const SizedBox(height: 8),
              _KeyValueRow(label: l10n.wifiSecurityLabel, value: wifi!.encryption),
            ] else
              SelectableText(
                record.rawValue,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
          ],
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  const _KeyValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ),
        Expanded(child: SelectableText(value)),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final ScanContentType type;
  final VoidCallback onOpenBrowser;
  final VoidCallback onConnectWifi;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const _ActionButtons({
    required this.type,
    required this.onOpenBrowser,
    required this.onConnectWifi,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        if (type == ScanContentType.url)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpenBrowser,
              icon: const Icon(Icons.open_in_browser_rounded),
              label: Text(l10n.actionOpenBrowser),
            ),
          ),
        if (type == ScanContentType.wifi)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onConnectWifi,
              icon: const Icon(Icons.wifi_rounded),
              label: Text(l10n.actionConnectWifi),
            ),
          ),
        if (type == ScanContentType.url || type == ScanContentType.wifi)
          const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(l10n.actionCopy),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text(l10n.actionShare),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NativeAdCard extends StatelessWidget {
  final NativeAd ad;
  const _NativeAdCard({required this.ad});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              AppLocalizations.of(context)!.sponsored,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.8)),
            ),
          ),
          SizedBox(
            height: 120,
            child: AdWidget(ad: ad),
          ),
        ],
      ),
    );
  }
}
