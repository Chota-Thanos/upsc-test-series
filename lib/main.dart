import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/navigation_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ApiClient(),
      child: const UpscApp(),
    ),
  );
}

class UpscApp extends StatelessWidget {
  const UpscApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UPSC Test Series',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: Consumer<ApiClient>(
        builder: (context, apiClient, _) {
          // Show a blank loading canvas while SharedPreferences token retrieval is initializing
          if (!apiClient.isInitialized) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.civic),
              ),
            );
          }

          // If token exists and authenticated or in guest mode, redirect to bottom navigation screens, else show login panel
          if (apiClient.isAuthenticated || apiClient.isGuestMode) {
            return const NavigationHome();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
