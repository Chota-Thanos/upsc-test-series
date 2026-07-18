import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color ink = Color(0xFF0F172A); // Slate 900
  static const Color paper = Color(0xFFF1F5FB); // Background grey-blue
  static const Color line = Color(0xFFDDE6F0); // Borders
  static const Color surface = Color(0xFFFFFFFF); // Cards background
  static const Color civic = Color(0xFF4F46E5); // Indigo 600 (Primary branding)
  static const Color brand = Color(
    0xFF2563EB,
  ); // Blue 600 (Alternate brand blue)
  static const Color saffron = Color(
    0xFFF59E0B,
  ); // Amber 500 (Warnings/Pending)
  static const Color berry = Color(0xFFE11D48); // Rose 600 (Errors/Incorrect)
  static const Color emerald = Color(
    0xFF059669,
  ); // Emerald 600 (Correct/Success)
  static const Color muted = Color(0xFF64748B); // Slate 500 (Muted texts)

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

/// The single source of truth for text styling. Every screen should reach
/// for one of these instead of hand-typing `GoogleFonts.plusJakartaSans(
/// fontSize: ..., fontWeight: ...)` inline -- that pattern is exactly how
/// the app ended up with 16 near-duplicate sizes (8.5, 9, 9.5, 10, 10.5, 11,
/// 11.5, 12, 12.5, 13, 13.5...) and the same visual role (e.g. "locked"
/// color) implemented independently in multiple places, each one capable of
/// drifting out of sync with the others.
///
/// Roles are named for what they're *for*, not their pixel size, so the
/// scale itself can change in one place without every call site changing.
/// Each style bakes in a sensible default color; override per-instance with
/// `.copyWith(color: ...)` only when a specific context genuinely needs a
/// different color (e.g. "locked" or "done" states).
class AppTypography {
  /// Plan/page-level heading. E.g. a study plan's title on its detail page.
  static final TextStyle title = GoogleFonts.plusJakartaSans(
    fontSize: 19,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    height: 1.25,
  );

  /// Section headers, e.g. "Course Schedule", "What you'll master".
  static final TextStyle sectionHeader = GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  /// Card/row titles -- a day step, a week name, a catalog card's title.
  static final TextStyle cardTitle = GoogleFonts.plusJakartaSans(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  /// A prominent standalone number: a price, a percentage, a stat.
  static final TextStyle statValue = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  /// Button/CTA label text. Deliberately has no baked-in color -- a filled
  /// button typically needs white, an outlined one typically needs the
  /// brand color, so this inherits the button's own foregroundColor unless
  /// a specific context overrides it.
  static final TextStyle button = GoogleFonts.plusJakartaSans(
    fontSize: 12.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.3,
  );

  /// Uppercase micro-label above a title, e.g. "WEEK 1 · LOCKED".
  static final TextStyle eyebrowLarge = GoogleFonts.plusJakartaSans(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.6,
    color: AppColors.civic,
  );

  /// A smaller/secondary eyebrow nested under a eyebrowLarge, e.g. a day
  /// step's "DAY 1 · READING" under a week's "WEEK 1".
  static final TextStyle eyebrowSmall = GoogleFonts.plusJakartaSans(
    fontSize: 9,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
    color: AppColors.muted,
  );

  /// Paragraph/description text.
  static final TextStyle body = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
    height: 1.5,
  );

  /// Secondary caption/meta text -- smaller than body, still legible (not a
  /// dumping ground for "make it tiny", which is how the old scale grew to
  /// 5 different sizes all doing this same job).
  static final TextStyle caption = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.muted,
  );
}

/// Corner-radius scale. Screens had drifted to 9/10/12/14/16/18px corners
/// for visually-identical "card" and "pill" shapes -- consolidated here into
/// named roles so a card and the InkWell clipping it can't silently disagree
/// again (that mismatch was a real bug: a catalog card's ripple used 14px
/// while its own decoration used 16px).
class AppRadius {
  /// Small buttons and inline action chips.
  static const double sm = 9;

  /// Standard cards, bubbles, banners, thumbnails.
  static const double md = 12;

  /// Prominent/outer cards -- matches [AppTheme.cardDecoration].
  static const double lg = 16;

  /// Top corners of a bottom sheet or slide-up panel.
  static const double sheet = 18;

  /// Fully-rounded pills and circular icon buttons.
  static const double pill = 999;
}

/// Named opacity values for state treatments. Reduced opacity on a
/// saturated color doesn't desaturate it -- civic indigo at 0.5 opacity on
/// white reads as light purple, not grey -- so "locked" dimming must always
/// be layered on top of an already-correct locked color, never used alone to
/// simulate one. Naming the value here stops it from drifting out of sync
/// between the week and day-row locked treatments the way it did before.
class AppOpacity {
  static const double locked = 0.5;
}

/// Shared filled/outlined button shapes so a button's color can't silently
/// fall back to the app's default black [ElevatedButtonThemeData] again --
/// every call site here explicitly states its color instead of hoping the
/// theme default matches.
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
    Color borderColor = AppColors.line,
    Color textColor = AppColors.civic,
    double radius = AppRadius.sm,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: textColor,
      side: BorderSide(color: borderColor),
      padding: padding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
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
        hintStyle: GoogleFonts.inter(
          color: AppColors.muted.withOpacity(0.6),
          fontSize: 13,
        ),
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
      BoxShadow(color: Color(0x060F172A), offset: Offset(0, 4), blurRadius: 12),
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
      image: AssetImage(
        'assets/images/glow_bg.png',
      ), // Fallback if available, else standard color
      fit: BoxFit.cover,
      opacity: 0.1,
    ),
  );
}
