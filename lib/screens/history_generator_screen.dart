import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/scan_record.dart';
import '../services/ad_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'result_screen.dart';

/// Screen 3: combines scan History (list, persisted via Hive) and a QR
/// Generator (text/URL -> custom-colored QR image, downloadable/shareable),
/// switchable via an inner segmented tab bar. A standard banner ad sits
/// at the bottom, shared across both sub-tabs.
class HistoryGeneratorScreen extends StatefulWidget {
  const HistoryGeneratorScreen({super.key});

  @override
  State<HistoryGeneratorScreen> createState() => _HistoryGeneratorScreenState();
}

class _HistoryGeneratorScreenState extends State<HistoryGeneratorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBanner());
  }

  void _loadBanner() {
    _bannerAd = AdService.instance.createAdaptiveBannerAd(
      width: MediaQuery.of(context).size.width.truncate(),
      onLoaded: (ad) {
        if (mounted) setState(() => _bannerLoaded = true);
      },
      onFailed: (ad, error) => ad.dispose(),
    )..load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.historyGeneratorTitle),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: l10n.tabHistoryLabel),
            Tab(text: l10n.tabGenerateLabel),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _HistoryTab(),
                _GeneratorTab(),
              ],
            ),
          ),
          if (_bannerLoaded && _bannerAd != null)
            SafeArea(
              top: false,
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
        ],
      ),
    );
  }
}

// =====================================================================
// HISTORY TAB
// =====================================================================
class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<ScanRecord>>(
      valueListenable: StorageService.listenable(),
      builder: (context, box, _) {
        final items = StorageService.getAll();
        if (items.isEmpty) {
          return _EmptyState(
            icon: Icons.history_rounded,
            message: AppLocalizations.of(context)!.emptyHistory,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return _HistoryTile(record: item);
          },
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ScanRecord record;
  const _HistoryTile({required this.record});

  IconData get _icon {
    switch (record.contentType) {
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
    return Dismissible(
      key: ValueKey(record.key),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.error),
      ),
      onDismissed: (_) => StorageService.delete(record),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: AppColors.accent, size: 20),
          ),
          title: Text(
            record.rawValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_jm().format(record.timestamp),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ResultScreen(record: record)),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// GENERATOR TAB
// =====================================================================
class _GeneratorTab extends StatefulWidget {
  const _GeneratorTab();

  @override
  State<_GeneratorTab> createState() => _GeneratorTabState();
}

class _GeneratorTabState extends State<_GeneratorTab> {
  final _controller = TextEditingController();
  final _screenshotController = ScreenshotController();
  Color _qrColor = AppColors.accent;
  String _qrData = '';

  static const List<Color> _palette = [
    AppColors.accent,
    AppColors.accentSecondary,
    Colors.white,
    Color(0xFFFF5470),
    Color(0xFFFFC15E),
    Color(0xFFB980F0),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveRecord() async {
    if (_qrData.isEmpty) return;
    final record = ScanRecord(
      rawValue: _qrData,
      contentTypeName: _qrData.startsWith('http') ? 'url' : 'text',
      timestamp: DateTime.now(),
      format: 'QR_CODE',
      isGenerated: true,
    );
    await StorageService.add(record);
  }

  Future<Uint8List?> _capture() {
    return _screenshotController.capture(pixelRatio: 3.0);
  }

  Future<void> _shareQr() async {
    final bytes = await _capture();
    if (bytes == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: 'qr_code.png', mimeType: 'image/png')],
        text: 'My QR Code',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: l10n.generatorHint,
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => _qrData = value),
          ),
          const SizedBox(height: 20),
          Text(l10n.colorLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            children: _palette.map((color) {
              final isSelected = color.value == _qrColor.value;
              return GestureDetector(
                onTap: () => setState(() => _qrColor = color),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          if (_qrData.isNotEmpty)
            Center(
              child: Screenshot(
                controller: _screenshotController,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: QrImageView(
                    data: _qrData,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: _qrColor),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: _qrColor,
                    ),
                  ),
                ),
              ),
            )
          else
            _EmptyState(
              icon: Icons.qr_code_2_rounded,
              message: l10n.emptyGenerator,
            ),
          const SizedBox(height: 24),
          if (_qrData.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _saveRecord();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.savedToHistory)),
                        );
                      }
                    },
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text(l10n.actionSave),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _shareQr,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: Text(l10n.actionShare),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
