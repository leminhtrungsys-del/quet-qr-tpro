import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/scan_record.dart';
import '../services/ad_service.dart';
import '../services/locale_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/content_parser.dart';
import '../widgets/scanner_overlay.dart';
import 'result_screen.dart';

/// Full-screen immersive camera preview with a Bento-style scan frame,
/// flashlight toggle, pinch-to-zoom, and a small adaptive banner pinned to
/// the bottom (kept deliberately unobtrusive per the UX spec — no
/// interstitials or native ads live on this screen).
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  final BarcodeScanner _barcodeScanner = BarcodeScanner();

  bool _isFlashOn = false;
  bool _isProcessing = false;
  bool _isDetecting = false;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 4.0;
  double _baseZoom = 1.0;

  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _loadBanner();
    AdService.instance.preloadInterstitial(); // warm up for Result screen
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    try {
      await controller.initialize();
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
      await controller.startImageStream(_processCameraImage);
      if (!mounted) return;
      setState(() => _cameraController = controller);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _loadBanner() {
    _bannerAd = AdService.instance.createAdaptiveBannerAd(
      width: MediaQuery.of(context).size.width.truncate(),
      onLoaded: (ad) {
        if (mounted) setState(() => _bannerLoaded = true);
      },
      onFailed: (ad, error) {
        ad.dispose();
        debugPrint('Banner failed: $error');
      },
    )..load();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting || _isProcessing) return;
    _isDetecting = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final barcodes = await _barcodeScanner.processImage(inputImage);
      if (barcodes.isNotEmpty && !_isProcessing) {
        final barcode = barcodes.first;
        if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
          _isProcessing = true;
          await _onBarcodeDetected(barcode);
        }
      }
    } catch (e) {
      debugPrint('Detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = _cameraController;
    if (controller == null) return null;

    final sensorOrientation = controller.description.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // NV21 (Android) is a single-plane-friendly format for ML Kit.
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _onBarcodeDetected(Barcode barcode) async {
    await _cameraController?.stopImageStream();

    final contentType = ContentParser.classify(barcode);
    final record = ScanRecord(
      rawValue: barcode.rawValue ?? '',
      contentTypeName: contentType.name,
      timestamp: DateTime.now(),
      format: barcode.format.name,
    );
    await StorageService.add(record);

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultScreen(record: record)),
    );

    // Resume scanning after returning from the result screen.
    _isProcessing = false;
    if (mounted && _cameraController != null && _cameraController!.value.isInitialized) {
      await _cameraController!.startImageStream(_processCameraImage);
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null) return;
    final newMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
    await controller.setFlashMode(newMode);
    setState(() => _isFlashOn = !_isFlashOn);
  }

  Future<void> _onScaleUpdate(ScaleUpdateDetails details) async {
    final controller = _cameraController;
    if (controller == null) return;
    final newZoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
    if ((newZoom - _currentZoom).abs() < 0.02) return;
    _currentZoom = newZoom;
    await controller.setZoomLevel(_currentZoom);
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _barcodeScanner.close();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            GestureDetector(
              onScaleStart: (_) => _baseZoom = _currentZoom,
              onScaleUpdate: _onScaleUpdate,
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.previewSize?.height ?? 0,
                    height: controller.value.previewSize?.width ?? 0,
                    child: CameraPreview(controller),
                  ),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: AppColors.accent)),

          // Dim overlay with a clear square cutout for the scan frame.
          IgnorePointer(
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),

          Center(child: const ScannerOverlay(size: 260)),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.appTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.translate_rounded,
                        active: false,
                        tooltip: AppLocalizations.of(context)!.languageSwitchTooltip,
                        onTap: () => LocaleService.instance.toggle(context),
                      ),
                      const SizedBox(width: 10),
                      _CircleIconButton(
                        icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        active: _isFlashOn,
                        onTap: _toggleFlash,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 90,
            left: 0,
            right: 0,
            child: Text(
              AppLocalizations.of(context)!.scanHintText,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14),
            ),
          ),

          // Small, non-intrusive adaptive banner pinned to the very bottom.
          if (_bannerLoaded && _bannerAd != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final