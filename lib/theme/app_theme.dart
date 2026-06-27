import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const _primary = Color(0xFFE53935);

  static TextTheme _poppinsDark() => GoogleFonts.poppinsTextTheme(const TextTheme(
        bodySmall: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodyLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ));

  static TextTheme _poppinsLight() => GoogleFonts.poppinsTextTheme(const TextTheme(
        bodySmall: TextStyle(color: Color(0xFF111111)),
        bodyMedium: TextStyle(color: Color(0xFF111111)),
        bodyLarge: TextStyle(color: Color(0xFF111111)),
        titleMedium: TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.bold),
      ));

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: _primary,
          onPrimary: Colors.white,
          secondary: _primary,
          onSecondary: Colors.white,
          surface: Color(0xFF1A1A1A),
          onSurface: Colors.white,
          error: Color(0xFFCF6679),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        canvasColor: const Color(0xFF1A1A1A),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF0D0D0D),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3),
          iconTheme: const IconThemeData(color: Colors.white),
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0D0D0D),
          selectedItemColor: _primary,
          unselectedItemColor: Color(0xFF888888),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        textTheme: _poppinsDark(),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF333333))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF333333))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary, width: 1.5)),
          labelStyle: const TextStyle(color: Color(0xFF888888)),
          fillColor: const Color(0xFF1A1A1A),
          filled: true,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            // Min height only (width 0) — forcing infinite width here made
            // FilledButtons crash inside Rows / dialog action bars. Screens that
            // want a full-width button wrap it in a double.infinity container.
            minimumSize: const Size(0, 52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5),
          ),
        ),
        sliderTheme: const SliderThemeData(
            activeTrackColor: _primary,
            thumbColor: _primary,
            inactiveTrackColor: Color(0xFF333333)),
        radioTheme: RadioThemeData(
            fillColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected)
                    ? _primary
                    : const Color(0xFF888888))),
        checkboxTheme: CheckboxThemeData(
            fillColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected)
                    ? _primary
                    : Colors.transparent),
            side: const BorderSide(color: Color(0xFF888888))),
        dividerColor: const Color(0xFF2A2A2A),
        cardColor: const Color(0xFF1A1A1A),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: _primary,
          onPrimary: Colors.white,
          secondary: _primary,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF111111),
          error: Color(0xFFB00020),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        canvasColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleTextStyle: GoogleFonts.poppins(
              color: const Color(0xFF111111),
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3),
          iconTheme: const IconThemeData(color: Color(0xFF111111)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: _primary,
          unselectedItemColor: Color(0xFF888888),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        textTheme: _poppinsLight(),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary, width: 1.5)),
          labelStyle: const TextStyle(color: Color(0xFF888888)),
          fillColor: Colors.white,
          filled: true,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            // Min height only (width 0) — forcing infinite width here made
            // FilledButtons crash inside Rows / dialog action bars. Screens that
            // want a full-width button wrap it in a double.infinity container.
            minimumSize: const Size(0, 52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5),
          ),
        ),
        sliderTheme: const SliderThemeData(
            activeTrackColor: _primary,
            thumbColor: _primary,
            inactiveTrackColor: Color(0xFFDDDDDD)),
        radioTheme: RadioThemeData(
            fillColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected)
                    ? _primary
                    : const Color(0xFF888888))),
        checkboxTheme: CheckboxThemeData(
            fillColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected)
                    ? _primary
                    : Colors.transparent),
            side: const BorderSide(color: Color(0xFF888888))),
        dividerColor: const Color(0xFFE0E0E0),
        cardColor: Colors.white,
      );
}
