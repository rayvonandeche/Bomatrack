import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary brand colors - teal/blue shade
  static const Color primaryColor = Color(0xFF006888); // Main brand color
  static const Color primaryLight = Color(0xFF3E95B5); // Lighter variant
  static const Color primaryDark = Color(0xFF00475E); // Darker variant

  // Accent colors for highlights and CTAs
  static const Color accentColor = Color(0xFFFF7E36); // Orange accent
  static const Color accentLight = Color(0xFFFFAC7B); // Light orange
  static const Color accentDark = Color(0xFFCC5000); // Dark orange

  // Supporting colors
  static const Color successColor = Color(0xFF4CAF50); // Green
  static const Color warningColor = Color(0xFFFFC107); // Amber
  static const Color errorColor = Color(0xFFE53935); // Red
  static const Color infoColor = Color(0xFF2196F3); // Blue

  // Background colors
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color backgroundDark = Color(0xFF121212);

  // Text colors
  static const Color textDark = Color(0xFF212121);
  static const Color textMedium = Color(0xFF666666);
  static const Color textLight = Color(0xFFFFFFFF);

  // Card colors
  static const Color cardBackgroundLight = Color(0xFFFFFFFF);
  static const Color cardBackgroundDark = Color(0xFF1E1E1E);

  // Border colors
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFF333333);

  // Standard Font Sizes (Material Design 3 Typography Scale)
  static const double displayLarge = 57.0;    // Display Large
  static const double displayMedium = 45.0;   // Display Medium
  static const double displaySmall = 36.0;    // Display Small
  
  static const double headlineLarge = 32.0;   // Headline Large
  static const double headlineMedium = 28.0;  // Headline Medium
  static const double headlineSmall = 24.0;   // Headline Small
  
  static const double titleLarge = 22.0;      // Title Large
  static const double titleMedium = 16.0;     // Title Medium
  static const double titleSmall = 14.0;      // Title Small
  
  static const double bodyLarge = 16.0;       // Body Large
  static const double bodyMedium = 14.0;      // Body Medium
  static const double bodySmall = 12.0;       // Body Small
  
  static const double labelLarge = 14.0;      // Label Large
  static const double labelMedium = 12.0;     // Label Medium
  static const double labelSmall = 11.0;      // Label Small

  // Get light theme
  static ThemeData get lightTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      onPrimary: Colors.white,
      secondary: accentColor,
      onSecondary: Colors.white,
      error: errorColor,
      onError: Colors.white,
      background: backgroundLight,
      onBackground: textDark,
      surface: cardBackgroundLight,
      onSurface: textDark,
      brightness: Brightness.light,
    );

    return _baseTheme(colorScheme).copyWith(
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: _appBarTheme(colorScheme, Brightness.light),
      cardTheme: _cardTheme(Brightness.light),
      elevatedButtonTheme: _elevatedButtonTheme(colorScheme),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme, Brightness.light),
      textButtonTheme: _textButtonTheme(colorScheme),
      inputDecorationTheme: _inputDecorationTheme(colorScheme, Brightness.light),
      floatingActionButtonTheme: _floatingActionButtonTheme(colorScheme),
      bottomSheetTheme: _bottomSheetTheme(Brightness.light),
      dialogTheme: _dialogTheme(Brightness.light),
      dividerTheme: _dividerTheme(Brightness.light),
      snackBarTheme: _snackBarTheme(Brightness.light),
      chipTheme: _chipTheme(colorScheme, Brightness.light),
    );
  }

  // Get dark theme
  static ThemeData get darkTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryLight, // Use lighter primary for dark theme
      onPrimary: Colors.white,
      secondary: accentLight, // Use lighter accent for dark theme
      onSecondary: Colors.black,
      error: errorColor,
      onError: Colors.white,
      background: backgroundDark,
      onBackground: Colors.white,
      surface: cardBackgroundDark,
      onSurface: Colors.white,
      brightness: Brightness.dark,
    );

    return _baseTheme(colorScheme).copyWith(
      scaffoldBackgroundColor: backgroundDark,
      appBarTheme: _appBarTheme(colorScheme, Brightness.dark),
      cardTheme: _cardTheme(Brightness.dark),
      elevatedButtonTheme: _elevatedButtonTheme(colorScheme),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme, Brightness.dark),
      textButtonTheme: _textButtonTheme(colorScheme),
      inputDecorationTheme: _inputDecorationTheme(colorScheme, Brightness.dark),
      floatingActionButtonTheme: _floatingActionButtonTheme(colorScheme),
      bottomSheetTheme: _bottomSheetTheme(Brightness.dark),
      dialogTheme: _dialogTheme(Brightness.dark),
      dividerTheme: _dividerTheme(Brightness.dark),
      snackBarTheme: _snackBarTheme(Brightness.dark),
      chipTheme: _chipTheme(colorScheme, Brightness.dark),
    );
  }

  // Base theme settings shared between light and dark themes
  static ThemeData _baseTheme(ColorScheme colorScheme) {
    final textTheme = _createTextTheme(colorScheme.brightness);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      primaryColor: colorScheme.primary,
      textTheme: textTheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // Animation durations for consistent feel
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
  
  // Create standardized text theme with Material Design 3 typography scale
  static TextTheme _createTextTheme(Brightness brightness) {
    final baseTextTheme = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;
    
    return GoogleFonts.ralewayTextTheme(baseTextTheme).copyWith(
      // Display styles
      displayLarge: GoogleFonts.raleway(
        fontSize: displayLarge,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        height: 1.12,
      ),
      displayMedium: GoogleFonts.raleway(
        fontSize: displayMedium,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.16,
      ),
      displaySmall: GoogleFonts.raleway(
        fontSize: displaySmall,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.22,
      ),
      
      // Headline styles
      headlineLarge: GoogleFonts.raleway(
        fontSize: headlineLarge,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.25,
      ),
      headlineMedium: GoogleFonts.raleway(
        fontSize: headlineMedium,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.29,
      ),
      headlineSmall: GoogleFonts.raleway(
        fontSize: headlineSmall,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.33,
      ),
      
      // Title styles
      titleLarge: GoogleFonts.raleway(
        fontSize: titleLarge,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.27,
      ),
      titleMedium: GoogleFonts.raleway(
        fontSize: titleMedium,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        height: 1.5,
      ),
      titleSmall: GoogleFonts.raleway(
        fontSize: titleSmall,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.43,
      ),
      
      // Body styles
      bodyLarge: GoogleFonts.raleway(
        fontSize: bodyLarge,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.raleway(
        fontSize: bodyMedium,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.43,
      ),
      bodySmall: GoogleFonts.raleway(
        fontSize: bodySmall,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.33,
      ),
      
      // Label styles
      labelLarge: GoogleFonts.raleway(
        fontSize: labelLarge,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.43,
      ),
      labelMedium: GoogleFonts.raleway(
        fontSize: labelMedium,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.33,
      ),
      labelSmall: GoogleFonts.raleway(
        fontSize: labelSmall,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.45,
      ),
    );
  }

  // AppBar theme
  static AppBarTheme _appBarTheme(ColorScheme colorScheme, Brightness brightness) {
    return AppBarTheme(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: colorScheme.onPrimary),
      titleTextStyle: GoogleFonts.raleway(
        color: colorScheme.onPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // Card theme
  static CardTheme _cardTheme(Brightness brightness) {
    return CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: brightness == Brightness.light ? cardBackgroundLight : cardBackgroundDark,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      clipBehavior: Clip.antiAliasWithSaveLayer,
    );
  }

  // Elevated button theme
  static ElevatedButtonThemeData _elevatedButtonTheme(ColorScheme colorScheme) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.raleway(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Outlined button theme
  static OutlinedButtonThemeData _outlinedButtonTheme(ColorScheme colorScheme, Brightness brightness) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        side: BorderSide(
          color: colorScheme.primary,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.raleway(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Text button theme
  static TextButtonThemeData _textButtonTheme(ColorScheme colorScheme) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        textStyle: GoogleFonts.raleway(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Input decoration theme
  static InputDecorationTheme _inputDecorationTheme(ColorScheme colorScheme, Brightness brightness) {
    return InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.light 
          ? Colors.grey.shade50 
          : Colors.grey.shade900,
      contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(
          width: 1.0,
          color: brightness == Brightness.light ? borderLight : borderDark,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(
          width: 1.0,
          color: brightness == Brightness.light ? borderLight : borderDark,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(
          width: 2.0,
          color: colorScheme.primary,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(
          width: 1.0,
          color: colorScheme.error,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(
          width: 2.0,
          color: colorScheme.error,
        ),
      ),
      labelStyle: TextStyle(
        color: brightness == Brightness.light ? textMedium : Colors.grey.shade300,
      ),
      hintStyle: TextStyle(
        color: brightness == Brightness.light ? Colors.grey.shade400 : Colors.grey.shade600,
      ),
      errorStyle: TextStyle(
        color: colorScheme.error,
        fontSize: 12,
      ),
    );
  }

  // Floating action button theme
  static FloatingActionButtonThemeData _floatingActionButtonTheme(ColorScheme colorScheme) {
    return FloatingActionButtonThemeData(
      backgroundColor: colorScheme.secondary,
      foregroundColor: colorScheme.onSecondary,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  // Bottom sheet theme
  static BottomSheetThemeData _bottomSheetTheme(Brightness brightness) {
    return BottomSheetThemeData(
      backgroundColor: brightness == Brightness.light ? cardBackgroundLight : cardBackgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      modalBackgroundColor: brightness == Brightness.light ? cardBackgroundLight : cardBackgroundDark,
      modalElevation: 8.0,
    );
  }

  // Dialog theme
  static DialogTheme _dialogTheme(Brightness brightness) {
    return DialogTheme(
      backgroundColor: brightness == Brightness.light ? cardBackgroundLight : cardBackgroundDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8.0,
    );
  }

  // Divider theme
  static DividerThemeData _dividerTheme(Brightness brightness) {
    return DividerThemeData(
      color: brightness == Brightness.light ? Colors.grey.shade200 : Colors.grey.shade800,
      thickness: 1,
      space: 24,
    );
  }

  // SnackBar theme
  static SnackBarThemeData _snackBarTheme(Brightness brightness) {
    return SnackBarThemeData(
      backgroundColor: brightness == Brightness.light ? textDark : cardBackgroundDark,
      contentTextStyle: GoogleFonts.raleway(
        color: brightness == Brightness.light ? textLight : textLight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      behavior: SnackBarBehavior.floating,
    );
  }

  // Chip theme
  static ChipThemeData _chipTheme(ColorScheme colorScheme, Brightness brightness) {
    return ChipThemeData(
      backgroundColor: brightness == Brightness.light
          ? Colors.grey.shade100
          : Colors.grey.shade800,
      disabledColor: Colors.grey.shade300,
      selectedColor: colorScheme.primary.withOpacity(0.2),
      secondarySelectedColor: colorScheme.secondary.withOpacity(0.2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: brightness == Brightness.light 
              ? Colors.grey.shade300
              : Colors.grey.shade700,
          width: 1,
        ),
      ),
      labelStyle: GoogleFonts.raleway(
        fontSize: 14,
        color: brightness == Brightness.light ? textDark : textLight,
      ),
      secondaryLabelStyle: GoogleFonts.raleway(
        fontSize: 14,
        color: colorScheme.primary,
      ),
      brightness: brightness,
    );
  }

  // Status colors for common UI elements based on state
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'paid':
      case 'approved':
      case 'completed':
        return successColor;
      case 'pending':
      case 'processing':
      case 'in progress':
        return warningColor;
      case 'inactive':
      case 'unpaid':
      case 'overdue':
      case 'rejected':
      case 'failed':
        return errorColor;
      default:
        return infoColor;
    }
  }
}