import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/welcome_screen.dart';
import 'features/home/presentation/navigation_home.dart';
import 'features/mentor_workspace/presentation/mentor_navigation_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the saved theme preference before the first frame to avoid a flash.
  final themeController = ThemeController();
  await themeController.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ApiClient()),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
      ],
      child: const UpscApp(),
    ),
  );
}

class UpscApp extends StatelessWidget {
  const UpscApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    return MaterialApp(
      title: 'UPSC Test Series',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeController.mode,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Keep the theme-aware AppColors tokens in sync with whichever theme
        // (light/dark) the app resolved to — including OS-driven changes.
        AppColors.brightness = Theme.of(context).brightness;
        return child ?? const SizedBox.shrink();
      },
      home: const _AuthGate(),
    );
  }
}

/// Root auth gate that also refreshes entitlements whenever the app returns to
/// the foreground.
///
/// Purchases happen on the website in an external browser, so without this a
/// user who has just paid comes back to an app that still shows everything
/// locked — until they fully restart or log out and back in. Re-syncing on
/// resume closes that gap.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    if (!apiClient.isAuthenticated) return;
    // Fire-and-forget: a failed refresh must never block the UI.
    apiClient.syncEntitlements();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiClient>(
      builder: (context, apiClient, _) {
          // Show a blank loading canvas while SharedPreferences token retrieval is initializing
          if (!apiClient.isInitialized) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.civic),
              ),
            );
          }

          // If token exists and authenticated or in guest mode, redirect to bottom navigation screens, else show the marketing welcome screen
          if (apiClient.isAuthenticated || apiClient.isGuestMode) {
            if (apiClient.isMentor) {
              return const MentorNavigationHome();
            }
            return const NavigationHome();
          } else {
            return const WelcomeScreen();
          }
        },
    );
  }
}
