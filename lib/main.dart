import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'screens/root_shell.dart';
import 'services/ad_service.dart';
import 'services/locale_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local history storage (Hive)
  await StorageService.init();

  // AdMob (banner / interstitial / native)
  await AdService.instance.init();

  // Saved language preference (EN / VI), falls back to system locale
  await LocaleService.instance.init();

  runApp(const QrScannerApp());
}

class QrScannerApp extends StatelessWidget {
  const QrScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleService.instance.locale,
      builder: (context, locale, _) {
        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          darkTheme: AppTheme.dark,
          theme: AppTheme.dark, // dark-mode-first: same theme regardless of system setting
          locale: locale,
          supportedLocales: LocaleService.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (deviceLocale, supported) {
            if (deviceLocale == null) return supported.first;
            for (final l in supported) {
              if (l.languageCode == deviceLocale.languageCode) return l;
            }
            return supported.first; // default English if unsupported
          },
          home: const RootShell(),
        );
      },
    );
  }
}
