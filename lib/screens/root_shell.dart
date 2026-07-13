import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import 'history_generator_screen.dart';
import 'permission_gate.dart';
import 'scanner_screen.dart';

/// App shell with the 3-tab bottom navigation:
/// Scanner (default) | History & Generator.
/// (Result is a pushed route, not a tab - it's reached from Scanner/History.)
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  late final List<Widget> _tabs = [
    PermissionGate(onGranted: (_) => const ScannerScreen()),
    const HistoryGeneratorScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: AppColors.surface,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: l10n.tabScanner,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.grid_view_rounded),
            label: l10n.tabHistory,
          ),
        ],
      ),
    );
  }
}
