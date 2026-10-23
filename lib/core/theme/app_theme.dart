import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primaryDark,
      secondaryContainer: AppColors.primarySoft,
      onSecondaryContainer: AppColors.primaryDark,
      surface: AppColors.background,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerHighest: AppColors.surfaceMuted,
      outline: AppColors.border,
      error: AppColors.error,
    );

    // Set weights on Material's plain styles first, then hand them to
    // google_fonts. It loads each weight as its own family, so changing
    // fontWeight on an already-Poppins style keeps the old file.
    final base = ThemeData.light().textTheme;

    TextStyle? w(TextStyle? style, FontWeight weight) =>
        style?.copyWith(fontWeight: weight);

    final weighted = base.copyWith(
      displayLarge: w(base.displayLarge, FontWeight.w600),
      displayMedium: w(base.displayMedium, FontWeight.w600),
      displaySmall: w(base.displaySmall, FontWeight.w600),
      headlineLarge: w(base.headlineLarge, FontWeight.w700),
      headlineMedium: w(base.headlineMedium, FontWeight.w700),
      headlineSmall: w(base.headlineSmall, FontWeight.w700),
      titleLarge: w(base.titleLarge, FontWeight.w600),
      titleMedium: w(base.titleMedium, FontWeight.w600),
      titleSmall: w(base.titleSmall, FontWeight.w600),
      labelLarge: w(base.labelLarge, FontWeight.w600),
      labelMedium: w(base.labelMedium, FontWeight.w600),
      labelSmall: w(base.labelSmall, FontWeight.w600),
      // w500 because typed text in fields uses bodyLarge
      bodyLarge: w(base.bodyLarge, FontWeight.w500),
      bodyMedium: w(base.bodyMedium, FontWeight.w400),
      bodySmall: w(base.bodySmall, FontWeight.w400),
    );

    final textTheme = GoogleFonts.dmSansTextTheme(
      weighted,
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.text);

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,

      // surfaceTintColor is cleared on raised surfaces so M3 doesn't wash them green
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 72,
        titleTextStyle: textTheme.headlineSmall,
      ),

      cardTheme: CardThemeData(
        color: AppColors.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceMuted,
        selectedColor: AppColors.primarySoft,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 2,
        shape: CircleBorder(),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.titleLarge,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.text,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.onPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primarySoft,
      ),

      dividerTheme: const DividerThemeData(color: AppColors.border),

      // Fields are tinted so they stand out on the white page
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        hintStyle: const TextStyle(color: AppColors.hint),
        prefixIconColor: AppColors.hint,
        suffixIconColor: AppColors.hint,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.primary, 1.5),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error, 1.5),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(64, 52),
          shape: const StadiumBorder(),
          textStyle: textTheme.titleMedium,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 52),
          shape: const StadiumBorder(),
          textStyle: textTheme.titleMedium,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
    );
  }
}
