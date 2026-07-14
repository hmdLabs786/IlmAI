import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_theme.dart';
import 'core/download/download_initializer.dart';
import 'core/router/app_router.dart';
import 'providers/auth_provider.dart';
import 'services/seed_data_service.dart';

/// Global theme notifier — permanently anchored to light mode.
/// The settings screen may toggle this, but the app always boots in light.
final ValueNotifier<ThemeMode> themeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start Firebase initialization early (async)
  final firebaseInit = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Start downloader init early (async)
  final downloaderInit = initializeDownloader(debug: !kReleaseMode);

  // Load theme preference early
  final prefsInit = SharedPreferences.getInstance();

  // Run initializations in parallel
  await Future.wait([firebaseInit, downloaderInit, prefsInit]);

  // Get theme preference
  final prefs = await prefsInit;
  final savedDark = prefs.getBool('dark_mode') ?? false;
  themeNotifier.value = savedDark ? ThemeMode.dark : ThemeMode.light;

  // Run seeding in background AFTER UI is shown (fire-and-forget)
  // Using a microtask to ensure UI renders first
  Future.microtask(() async {
    try {
      await SeedDataService().seedAll();
    } catch (e) {
      debugPrint("Seeding skipped: $e");
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const IlmAIApp(),
    ),
  );
}

class IlmAIApp extends StatelessWidget {
  const IlmAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp.router(
          title: 'IlmAI',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          routerConfig: appRouter,
        );
      },
    );
  }
}
