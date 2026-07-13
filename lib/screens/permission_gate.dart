import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';

/// Wraps the Scanner screen: shows a friendly "why we need this" dialog
/// BEFORE hitting the OS permission prompt (Google Play best practice /
/// improves grant rates), then requests the real permission, then either
/// shows [onGranted] or an elegant "denied" state with a Settings deep link.
class PermissionGate extends StatefulWidget {
  final WidgetBuilder onGranted;

  const PermissionGate({super.key, required this.onGranted});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> with WidgetsBindingObserver {
  PermissionStatus _status = PermissionStatus.denied;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check status when the user returns from Settings.
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _bootstrap() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      setState(() {
        _status = status;
        _checking = false;
      });
      return;
    }
    setState(() => _checking = false);
    // Show rationale dialog before the system prompt on first ask,
    // and whenever previously denied (not permanently).
    if (mounted) await _showRationaleThenRequest();
  }

  Future<void> _refreshStatus() async {
    final status = await Permission.camera.status;
    if (mounted) setState(() => _status = status);
  }

  Future<void> _showRationaleThenRequest() async {
    final l10n = AppLocalizations.of(context)!;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.camera_alt_rounded, color: AppColors.accent, size: 36),
        title: Text(l10n.permissionTitle),
        content: Text(
          l10n.permissionBody,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.permissionNotNow, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.permissionContinue),
          ),
        ],
      ),
    );

    if (proceed == true) {
      final result = await Permission.camera.request();
      if (mounted) setState(() => _status = result);
    } else {
      if (mounted) setState(() => _status = PermissionStatus.denied);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_status.isGranted) {
      return widget.onGranted(context);
    }

    return _PermissionDeniedView(
      isPermanentlyDenied: _status.isPermanentlyDenied,
      onRetry: _showRationaleThenRequest,
      onOpenSettings: () => openAppSettings(),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  final bool isPermanentlyDenied;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  const _PermissionDeniedView({
    required this.isPermanentlyDenied,
    required this.onRetry,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.no_photography_rounded, size: 56, color: AppColors.error),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.permissionDeniedTitle,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.permissionDeniedBody,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isPermanentlyDenied ? onOpenSettings : onRetry,
                  child: Text(isPermanentlyDenied ? l10n.permissionOpenSettings : l10n.permissionGrant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
