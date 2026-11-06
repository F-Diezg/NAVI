import 'package:flutter/material.dart';

const naviSeed = Color(0xFF2EC4B6); // turquesa
const naviNight = Color(0xFF101828); // fondo del icono

ThemeData naviTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(
    seedColor: naviSeed,
    brightness: b,
    tertiary: const Color(0xFFB794F6),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        b == Brightness.dark ? naviNight : scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: b == Brightness.dark ? naviNight : scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 12),
    ),
  );
}
