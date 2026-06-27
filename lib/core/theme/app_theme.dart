import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color ink = Color(0xFF0F172A);         // Slate 900
  static const Color paper = Color(0xFFF1F5FB);       // Background grey-blue
  static const Color line = Color(0xFFDDE6F0);        // Borders
  static const Color surface = Color(0xFFFFFFFF);     // Cards background
  static const Color civic = Color(0xFF4F46E5);       // Indigo 600 (Primary branding)
  static const Color brand = Color(0xFF2563EB);       // Blue 600 (Alternate brand blue)
  static const Color saffron = Color(0xFFF59E0B);     // Amber 500 (Warnings/Pending)
  static const Color berry = Color(0xFFE11D48);       // Rose 600 (Errors/Incorrect)
  static const Color emerald = Color(0xFF059669);     // Emerald 600 (Correct/Success)
  static const Color muted = Color(0xFF64748B);       // Slate 500 (Muted texts)

  // Gradients matching web Hero background
  static const LinearGradient heroGradient = LinearGradient(
    colors: [
      Color(0xFF0F172A), // slate-900
      Color(0xFF1E1B4B), // indigo-950
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.civic,
        secondary: AppColors.brand,
        background: AppColors.paper,
        surface: AppColors.surface,
        error: AppColors.berry,
      ),
      scaffoldBackgroundColor: AppColors.paper,
      dividerColor: AppColors.line,
      
      // Typography: Headings using Plus Jakarta Sans and Roboto; Body using Inter/Google Sans Text
      textTheme: TextTheme(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          letterSpacing: 0,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          letterSpacing: 0,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          letterSpacing: 0,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.ink,
          height: 1.4,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.muted,
          height: 1.35,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
      ),

      // Input fields (styled like web app forms but sized for mobile)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.civic, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.berry, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: AppColors.muted, fontSize: 13),
        hintStyle: GoogleFonts.inter(color: AppColors.muted.withOpacity(0.6), fontSize: 13),
      ),

      // Premium Elevate Button Styles
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line, width: 1),
        ),
      ),
    );
  }

  // Common premium card box decoration with soft shadow
  static BoxDecoration cardDecoration = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.line, width: 1),
    boxShadow: const [
      BoxShadow(
        color: Color(0x060F172A),
        offset: Offset(0, 4),
        blurRadius: 12,
      )
    ],
  );

  static BoxDecoration innerCardDecoration = BoxDecoration(
    color: AppColors.paper.withOpacity(0.5),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.line, width: 1),
  );

  // Background decoration mirroring the web page styling
  static BoxDecoration scaffoldBackgroundDecoration = const BoxDecoration(
    color: AppColors.paper,
    image: DecorationImage(
      image: AssetImage('assets/images/glow_bg.png'), // Fallback if available, else standard color
      fit: BoxFit.cover,
      opacity: 0.1,
    ),
  );
}
