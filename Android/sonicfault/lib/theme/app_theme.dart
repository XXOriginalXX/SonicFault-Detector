import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Automobile-inspired palette
  static const bg       = Color(0xFF0A0C10);   // near-black carbon
  static const surface  = Color(0xFF13161D);   // dashboard panel
  static const card     = Color(0xFF1C2030);   // gauge card
  static const accent   = Color(0xFFFF6B00);   // racing orange
  static const accentDim= Color(0x33FF6B00);
  static const green    = Color(0xFF39FF14);   // neon OK
  static const red      = Color(0xFFFF3131);   // alert red
  static const textPri  = Color(0xFFE8EAF0);
  static const textSec  = Color(0xFF6B7280);
  static const border   = Color(0xFF2A3045);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: green,
      surface: surface,
      error: red,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      headlineLarge: GoogleFonts.orbitron(
          color: textPri, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 2),
      headlineMedium: GoogleFonts.orbitron(
          color: textPri, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 1.5),
      titleLarge: GoogleFonts.orbitron(
          color: textPri, fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.inter(color: textPri, fontSize: 15),
      bodyMedium: GoogleFonts.inter(color: textSec, fontSize: 13),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.orbitron(fontWeight: FontWeight.w600, letterSpacing: 1),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: accent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: textSec),
      hintStyle: const TextStyle(color: textSec),
    ),
    cardTheme: CardTheme(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: border),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.orbitron(
          color: textPri, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.5),
      iconTheme: const IconThemeData(color: textPri),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: accent,
      unselectedItemColor: textSec,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
  );
}