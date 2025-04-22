import 'my_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primarySwatch: primarySwatch,
  primaryColor: primarySwatch[300],
  scaffoldBackgroundColor: const Color(0xFF121212),
  cardColor: const Color(0xFF232323),
  dialogBackgroundColor: const Color(0xFF2C2C2C),
  appBarTheme: AppBarTheme(
    color: const Color(0xFF1C2833),
    iconTheme: IconThemeData(color: primarySwatch[300]),
    titleTextStyle: GoogleFonts.raleway(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  ),
  colorScheme: ColorScheme.dark(
    primary: primarySwatch[300]!,
    secondary: primarySwatch[400]!,
    surface: const Color(0xFF1E1E1E),
    onPrimary: Colors.white,
    onSecondary: Colors.white70,
    onSurface: Colors.white70,
    onError: Colors.black,
    error: Colors.redAccent,
  ),
  buttonTheme: ButtonThemeData(
    buttonColor: primarySwatch[400],
    textTheme: ButtonTextTheme.primary,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primarySwatch[300],
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primarySwatch[300],
      side: BorderSide(color: primarySwatch[300]!),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: primarySwatch[300],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  ),
  iconTheme: IconThemeData(color: primarySwatch[300]),
  inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2E2E2E),
      labelStyle: TextStyle(color: primarySwatch[400]),
      hintStyle: const TextStyle(color: Colors.white60),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: primarySwatch[600]!.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(4),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: primarySwatch[600]!),
        borderRadius: BorderRadius.circular(4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(4),
      )),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: primarySwatch[500],
    foregroundColor: Colors.white,
  ),
  textTheme: GoogleFonts.ralewayTextTheme(ThemeData.dark().textTheme),
      // .copyWith(
      //     bodyLarge: const TextStyle(fontSize: 14, color: Colors.white), // Default is 16
      //     bodyMedium: const TextStyle(fontSize: 13, color: Colors.white), // Default is 14
      //     bodySmall: const TextStyle(fontSize: 12, color: Colors.white)),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: const Color(0xFF1E1E1E),
    selectedItemColor: primarySwatch[300],
    unselectedItemColor: Colors.grey,
  ),
  sliderTheme: SliderThemeData(
    activeTrackColor: primarySwatch[300],
    inactiveTrackColor: Colors.white24,
    thumbColor: primarySwatch[300],
    overlayColor: primarySwatch[300]?.withOpacity(0.3),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return primarySwatch[300];
      }
      return null;
    }),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected)
            ? primarySwatch[300]
            : const Color.fromARGB(255, 85, 85, 85)),
    trackColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected)
            ? primarySwatch[600]
            : const Color.fromARGB(255, 31, 35, 37)),
  ),
  dividerTheme: const DividerThemeData(
    color: Colors.white12,
    thickness: 1,
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: primarySwatch[700]?.withOpacity(0.9),
      borderRadius: BorderRadius.circular(4),
    ),
    textStyle: const TextStyle(color: Colors.white),
  ),
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: primarySwatch[300],
    linearTrackColor: primarySwatch[100]?.withOpacity(0.2),
  ),
);

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primarySwatch: primarySwatch,
  primaryColor: primarySwatch[700],
  scaffoldBackgroundColor: Colors.white,
  cardColor: Colors.white,
  appBarTheme: AppBarTheme(
    color: primarySwatch[700],
    iconTheme: const IconThemeData(color: Colors.white),
    titleTextStyle: GoogleFonts.raleway(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  ),
  colorScheme: ColorScheme.light(
    primary: primarySwatch[700]!,
    secondary: primarySwatch[500]!,
    surface: Colors.white,
    onPrimary: Colors.white,
    onSecondary: Colors.black,
    onSurface: primarySwatch[800]!,
    onError: Colors.white,
    error: Colors.red,
  ),
  buttonTheme: ButtonThemeData(
    buttonColor: primarySwatch[700],
    textTheme: ButtonTextTheme.primary,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primarySwatch[700],
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: primarySwatch[700],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primarySwatch[700],
      side: BorderSide(color: primarySwatch[700]!),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  ),
  iconTheme: IconThemeData(color: primarySwatch[700]),
  inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: TextStyle(color: primarySwatch[700]),
      hintStyle: TextStyle(color: primarySwatch[700]?.withOpacity(0.6)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: primarySwatch[800]!.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: primarySwatch[600]!),
        borderRadius: BorderRadius.circular(4),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(4),
      )),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: primarySwatch[500],
    foregroundColor: Colors.white,
  ),
  textTheme: GoogleFonts.ralewayTextTheme()
    ..apply(
      bodyColor: primarySwatch.shade900,
      displayColor: primarySwatch.shade900,
    ).copyWith(
        bodyLarge: const TextStyle(fontSize: 14), // Default is 16
        bodyMedium: const TextStyle(fontSize: 13), // Default is 14
        bodySmall: const TextStyle(fontSize: 12)),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: primarySwatch[700],
    unselectedItemColor: Colors.grey,
  ),
  sliderTheme: SliderThemeData(
    activeTrackColor: primarySwatch[700],
    thumbColor: primarySwatch[700],
    overlayColor: primarySwatch[700]?.withOpacity(0.3),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return primarySwatch[700];
      }
      return null;
    }),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected)
            ? primarySwatch[700]
            : const Color.fromARGB(255, 143, 143, 143)),
    trackColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected)
            ? primarySwatch[400]
            : const Color.fromARGB(255, 184, 184, 184)),
  ),
  dividerTheme: const DividerThemeData(
    color: Colors.black12,
    thickness: 1,
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: primarySwatch[700]?.withOpacity(0.9),
      borderRadius: BorderRadius.circular(4),
    ),
    textStyle: const TextStyle(color: Colors.white),
  ),
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: primarySwatch[700],
    linearTrackColor: primarySwatch[100],
  ),
);
