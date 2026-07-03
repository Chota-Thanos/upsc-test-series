import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';

class AuthInterceptionHelper {
  /// Checks if the user is in guest mode. If so, shows a dialog prompting them
  /// to sign in and returns true. If they are already authenticated, returns false.
  static bool checkAuthAndPrompt(BuildContext context, ApiClient apiClient) {
    if (!apiClient.isGuestMode && apiClient.isAuthenticated) {
      return false; // User is authenticated, proceed with action
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: AppColors.civic, size: 24),
              const SizedBox(width: 8),
              Text(
                "Sign In Required",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          content: Text(
            "Create a free account or sign in to unlock this feature, build custom mock tests, book topper mentors, and sync your preparation progress across devices.",
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.muted,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.civic,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                Navigator.pop(context);
                // Turning off guest mode triggers the main wrapper to show LoginScreen
                apiClient.setGuestMode(false);
              },
              child: Text(
                "Sign In / Register",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        );
      },
    );

    return true; // Intercepted
  }
}
