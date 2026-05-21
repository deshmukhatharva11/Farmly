import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'core/providers.dart';
import 'features/onboarding/screens/language_selection_screen.dart';
import 'features/onboarding/screens/tutorial_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/scan/screens/scan_screen.dart';
import 'features/scan/screens/processing_screen.dart';
import 'features/result/screens/result_screen.dart';
import 'features/disease/screens/disease_detail_screen.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'features/onboarding/screens/location_permission_screen.dart';
import 'features/history/screens/history_screen.dart';
import 'features/weather/screens/weather_dashboard_screen.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load persisted language before app starts
  final savedLocale = await loadPersistedLocale();
  runApp(ProviderScope(
    overrides: [localeProvider.overrideWith((ref) => savedLocale)],
    child: const FarmlyApp(),
  ));
}

class FarmlyApp extends ConsumerWidget {
  const FarmlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Farmly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/',
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/':
            page = const LanguageSelectionScreen();
            break;
          case '/tutorial':
            page = const TutorialScreen();
            break;
          case '/location-permission':
            page = const LocationPermissionScreen();
            break;
          case '/login':
            page = const LoginScreen();
            break;
          case '/home':
            page = const AppShell();
            break;
          case '/scan':
            page = const ScanScreen();
            break;
          case '/processing':
            page = const ProcessingScreen();
            break;
          case '/result':
            page = const ResultScreen();
            break;
          case '/disease-detail':
            final diseaseName = settings.arguments as String? ?? 'Leaf Spot';
            page = DiseaseDetailScreen(diseaseName: diseaseName);
            break;
          case '/notifications':
            page = const NotificationsScreen();
            break;
          case '/history':
            page = const HistoryScreen();
            break;
          case '/weather-dashboard':
            page = const WeatherDashboardScreen();
            break;
          default:
            page = const LanguageSelectionScreen();
        }

        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        );
      },
    );
  }
}
