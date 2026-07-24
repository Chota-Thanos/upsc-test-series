import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic colour tokens. Neutral tokens (ink/paper/line/surface/muted) are
/// theme-aware: they resolve to a light or dark value based on [brightness],
/// which the app updates from the active [Theme] on every rebuild. Because
/// almost every screen reads these tokens instead of raw `Color(0x..)`, dark
/// mode flips automatically without touching call sites.
///
/// Brand colours (civic/brand/saffron/berry/emerald) are the same in both
/// themes and stay `const` so they remain usable in `const` contexts.
class AppColors {
  // ── Brand (theme-independent, const) ──
  static const Color civic = Color(0xFF4F46E5); // Indigo 600 (Primary branding)
  static const Color brand = Color(0xFF2563EB); // Blue 600
  static const Color saffron = Color(0xFFF59E0B); // Amber 500 (Warnings/Pending)
  static const Color berry = Color(0xFFE11D48); // Rose 600 (Errors/Incorrect)
  static const Color emerald = Color(0xFF059669); // Emerald 600 (Correct/Success)

  // ── Light palette ──
  static const Color _inkLight = Color(0xFF0F172A); // Slate 900
  static const Color _paperLight = Color(0xFFF1F5FB); // Background grey-blue
  static const Color _lineLight = Color(0xFFDDE6F0); // Borders
  static const Color _surfaceLight = Color(0xFFFFFFFF); // Cards
  static const Color _mutedLight = Color(0xFF64748B); // Slate 500

  // ── Dark palette ──
  static const Color _inkDark = Color(0xFFE7ECF3); // Near-white primary text
  static const Color _paperDark = Color(0xFF0B1120); // App background
  static const Color _lineDark = Color(0xFF2C3A4F); // Borders on dark
  static const Color _surfaceDark = Color(0xFF1B2436); // Cards on dark
  static const Color _mutedDark = Color(0xFF93A2B7); // Secondary text on dark

  /// Whether the app is currently rendering in dark mode. Updated by the app
  /// shell from the active theme; see `main.dart`'s MaterialApp.builder.
  static bool _dark = false;
  static bool get isDark => _dark;
  static set brightness(Brightness value) => _dark = value == Brightness.dark;

  static Color get ink => _dark ? _inkDark : _inkLight;
  static Color get paper => _dark ? _paperDark : _paperLight;
  static Color get line => _dark ? _lineDark : _lineLight;
  static Color get surface => _dark ? _surfaceDark : _surfaceLight;
  static Color get muted => _dark ? _mutedDark : _mutedLight;

  // Gradients matching web Hero background (intentionally dark in both themes).
  static const LinearGradient heroGradient = LinearGradient(
    colors: [
      Color(0xFF0F172A), // slate-900
      Color(0xFF1E1B4B), // indigo-950
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// The single source of truth for text styling. Colours are read from the
/// theme-aware [AppColors] getters, so these styles are exposed as getters
/// (not `static final`) — each access recomputes with the current theme's
/// colour. Roles are named for what they're *for*, not their pixel size.
class AppTypography {
  /// Hero/marketing headline -- bigger than [title].
  static TextStyle get display => GoogleFonts.plusJakartaSans(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        height: 1.15,
      );

  /// Plan/page-level heading.
  static TextStyle get title => GoogleFonts.plusJakartaSans(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        height: 1.25,
      );

  /// Section headers, e.g. "Course Schedule".
  static TextStyle get sectionHeader => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      );

  /// Card/row titles.
  static TextStyle get cardTitle => GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      );

  /// A prominent standalone number: a price, a percentage, a stat.
  static TextStyle get statValue => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      );

  /// Button/CTA label text. No baked-in colour -- inherits the button's own
  /// foregroundColor unless a specific context overrides it.
  static TextStyle get button => GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      );

  /// Uppercase micro-label above a title, e.g. "WEEK 1 · LOCKED".
  static TextStyle get eyebrowLarge => GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: AppColors.civic,
      );

  /// A smaller/secondary eyebrow nested under an eyebrowLarge.
  static TextStyle get eyebrowSmall => GoogleFonts.plusJakartaSans(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: AppColors.muted,
      );

  /// Paragraph/description text.
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.muted,
        height: 1.5,
      );

  /// Secondary caption/meta text.
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
      );
}

/// Corner-radius scale.
class AppRadius {
  static const double sm = 9;
  static const double md = 12;
  static const double lg = 16;
  static const double sheet = 18;
  static const double pill = 999;
}

/// Named opacity values for state treatments.
class AppOpacity {
  static const double locked = 0.5;
}

/// Shared filled/outlined button shapes.
class AppButtonStyles {
  static ButtonStyle filled({
    required EdgeInsetsGeometry padding,
    Color color = AppColors.civic,
    double radius = AppRadius.sm,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: padding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  static ButtonStyle outlined({
    required EdgeInsetsGeometry padding,
    // Defaults resolve at call time because AppColors.line is theme-aware
    // (and therefore not a compile-time const).
    Color? borderColor,
    Color textColor = AppColors.civic,
    double radius = AppRadius.sm,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: textColor,
      side: BorderSide(color: borderColor ?? AppColors.line),
      padding: padding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(false);
  static ThemeData get darkTheme => _buildTheme(true);

  /// Builds a full [ThemeData] for the requested brightness. Uses the explicit
  /// palette for that brightness (not the global [AppColors] getters), since
  /// both themes are constructed once at startup regardless of the active mode.
  static ThemeData _buildTheme(bool dark) {
    final Color ink = dark ? AppColors._inkDark : AppColors._inkLight;
    final Color paper = dark ? AppColors._paperDark : AppColors._paperLight;
    final Color line = dark ? AppColors._lineDark : AppColors._lineLight;
    final Color surface = dark ? AppColors._surfaceDark : AppColors._surfaceLight;
    final Color muted = dark ? AppColors._mutedDark : AppColors._mutedLight;

    final base = dark ? const ColorScheme.dark() : const ColorScheme.light();

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: base.copyWith(
        primary: AppColors.civic,
        secondary: AppColors.brand,
        surface: surface,
        background: paper,
        error: AppColors.berry,
        onSurface: ink,
        onBackground: ink,
      ),
      scaffoldBackgroundColor: paper,
      dividerColor: line,
      iconTheme: IconThemeData(color: ink),

      textTheme: TextTheme(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: 0,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: ink,
          letterSpacing: 0,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: ink,
          letterSpacing: 0,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: ink,
          height: 1.4,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: muted,
          height: 1.35,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.civic, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.berry, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: muted, fontSize: 13),
        hintStyle: GoogleFonts.inter(color: muted.withOpacity(0.6), fontSize: 13),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // Dark mode uses the brand indigo (a near-white "ink" button would be
          // invisible); light mode keeps the original dark navy button.
          backgroundColor: dark ? AppColors.civic : ink,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: line, width: 1),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dialogTheme: DialogThemeData(backgroundColor: surface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface),
    );
  }

  // Common premium card box decoration with soft shadow (theme-aware).
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.isDark
                ? const Color(0x33000000)
                : const Color(0x060F172A),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      );

  static BoxDecoration get innerCardDecoration => BoxDecoration(
        color: AppColors.isDark
            ? AppColors.surface
            : AppColors.paper.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line, width: 1),
      );

  // Background decoration mirroring the web page styling.
  static BoxDecoration get scaffoldBackgroundDecoration => BoxDecoration(
        color: AppColors.paper,
        image: const DecorationImage(
          image: AssetImage('assets/images/glow_bg.png'),
          fit: BoxFit.cover,
          opacity: 0.1,
        ),
      );
}
