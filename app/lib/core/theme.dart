import 'package:flutter/material.dart';

// 어두운 배경에 라임색 포인트. 글꼴은 기기 기본 글꼴(한글은 Noto Sans CJK)을 쓴다.
const _background = Color(0xFF0F110C);
const _surface = Color(0xFF1A1D16);
const _surfaceHigh = Color(0xFF272B22);
const _lime = Color(0xFFC6F135);
const _onLime = Color(0xFF172000);
const _textPrimary = Color(0xFFF2F4EC);
const _textSecondary = Color(0xFFA9AFA0);
const _outline = Color(0xFF4A5042);
const _error = Color(0xFFFF8A80);

/// 한 손으로 누르기 쉬운 기본 버튼 높이
const double buttonHeight = 56;

ThemeData buildAppTheme() {
  const colors = ColorScheme.dark(
    primary: _lime,
    onPrimary: _onLime,
    secondary: _lime,
    onSecondary: _onLime,
    surface: _background,
    onSurface: _textPrimary,
    onSurfaceVariant: _textSecondary,
    surfaceContainer: _surface,
    surfaceContainerHigh: _surfaceHigh,
    outline: _outline,
    error: _error,
    onError: Color(0xFF3B0A06),
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  const buttonText = TextStyle(fontSize: 17, fontWeight: FontWeight.w700);
  const buttonSize = Size(double.infinity, buttonHeight);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: _background,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 16),
      bodyMedium: TextStyle(fontSize: 14, color: _textSecondary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: buttonText,
        side: const BorderSide(color: _outline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _lime, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _error),
      ),
    ),
    cardTheme: CardThemeData(
      color: _surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: _surface,
      indicatorColor: _lime,
    ),
  );
}
