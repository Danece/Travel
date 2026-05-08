import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/providers/settings_provider.dart';

class TravelMarkApp extends ConsumerStatefulWidget {
  const TravelMarkApp({super.key});

  @override
  ConsumerState<TravelMarkApp> createState() => _TravelMarkAppState();
}

class _TravelMarkAppState extends ConsumerState<TravelMarkApp> {
  @override
  void initState() {
    super.initState();
    FlutterError.onError = FlutterError.presentError;
    ErrorWidget.builder = (details) => _AppErrorPage(details: details);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(settingsNotifierProvider).valueOrNull;
    final themeMode = settings?.themeMode ?? ThemeMode.system;
    final locale = settings?.locale ?? 'zh-TW';
    final colorVariant =
        ref.watch(colorVariantNotifierProvider).valueOrNull ?? 'default';

    final isColorful = colorVariant == 'colorful';

    return MaterialApp.router(
      title: 'Travel Mark',
      theme: isColorful ? AppTheme.colorful : AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isColorful ? ThemeMode.light : themeMode,
      locale: locale == 'en' ? const Locale('en') : const Locale('zh', 'TW'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'TW'), Locale('en')],
      routerConfig: router,
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
  }
}

class _AppErrorPage extends StatelessWidget {
  const _AppErrorPage({required this.details});
  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                '發生非預期的錯誤',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                kDebugMode ? details.exceptionAsString() : '請重新啟動應用程式',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
