import 'package:flutter/material.dart';

// ── Base palette (single source of truth for shared hex values) ──

class _Palette {
  const _Palette._();

  static const Color orange = Color(0xFFFF8C42);
  static const Color green = Color(0xFF2EBD85);
  static const Color purple = Color(0xFF7C5CFC);
  static const Color blue = Color(0xFF2196F3);
  static const Color slate = Color(0xFF546E7A);

  static const Color red = Color(0xFFE53935);
  static const Color amber = Color(0xFFFFA726);
  static const Color lightBlue = Color(0xFF42A5F5);
  static const Color lightGreen = Color(0xFF66BB6A);

  static const Color statusGreen = Color(0xFF4CAF50);
  static const Color statusLime = Color(0xFF8BC34A);
  static const Color statusYellow = Color(0xFFFFC107);
  static const Color statusOrange = Color(0xFFFF9800);

  static const Color backgroundGrey = Color(0xFFF8F9FA);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textBody = Color(0xFF616161);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textDisabled = Color(0xFFBDBDBD);

  static const Color financeGradientEnd = Color(0xFF1B8C5E);
  static const Color greyFill = Color(0xFFF5F5F5);
}

/// 5-module color system for Life OS.
/// Each module has a primary identity color used for its tab icon,
/// accent elements, and deep-linked content throughout the app.
class ModuleColors {
  ModuleColors._();

  // Module identity
  static const Color home = _Palette.orange;
  static const Color finance = _Palette.green;
  static const Color analytics = _Palette.purple;
  static const Color daily = _Palette.blue;
  static const Color profile = _Palette.slate;

  // Quadrant (Eisenhower matrix)
  static const Color quadrantA = _Palette.red;
  static const Color quadrantB = _Palette.amber;
  static const Color quadrantC = _Palette.lightBlue;
  static const Color quadrantD = _Palette.lightGreen;

  // Pet status levels
  static const Color statusExcellent = _Palette.statusGreen;
  static const Color statusNormal = _Palette.statusLime;
  static const Color statusTired = _Palette.statusYellow;
  static const Color statusSick = _Palette.statusOrange;
  static const Color statusCritical = _Palette.red;

  // Semantic
  static const Color income = _Palette.green;
  static const Color expense = _Palette.red;
  static const Color transfer = _Palette.lightBlue;
  static const Color warning = _Palette.amber;
  static const Color success = _Palette.statusGreen;
}

/// Typography scale used across the app.
class AppTypography {
  AppTypography._();

  static const _fontFamily = 'PingFang SC';

  static const TextStyle headline1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const TextStyle headline2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle title = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyBold = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle small = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  static const TextStyle amountLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle amountMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
}

/// Material 3 theme factory.
class AppTheme {
  AppTheme._();

  static final ThemeData light = _buildLight();

  static ThemeData _buildLight() {
    const seed = ModuleColors.home;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _Palette.backgroundGrey,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: _Palette.backgroundGrey,
        foregroundColor: _Palette.textPrimary,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: _Palette.backgroundGrey,
        selectedItemColor: _Palette.textPrimary,
        unselectedItemColor: _Palette.textDisabled,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      // 不在此处写死 shape —— 全局设 CircleBorder() 会把 FAB.extended（本该是
      // 胶囊形）也强制成圆形，导致「记录饮食」这类带文字的 FAB 文字溢出被裁切。
      // 留空则各形态用各自的默认形状（普通 FAB 圆形、extended 胶囊形）。
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
