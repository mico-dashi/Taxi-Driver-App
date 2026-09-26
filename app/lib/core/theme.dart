import 'package:flutter/material.dart';

/// Rent AL colours: racing red on graphite and near-black.
class AppColors {
  static const primary = Color(0xFFEC0618); // racing red
  static const primaryLight = Color(0xFFFF4B58); // red text/icons on dark
  static const primarySoft = Color(0xFF3A0B10); // red-tinted surface
  static const ink = Color(0xFFFFFFFF); // main text
  static const inkSoft = Color(0xFFA3A6AD);
  static const inkFaint = Color(0xFF6E727A);
  static const background = Color(0xFF010101);
  static const surface = Color(0xFF212325); // cards
  static const surfaceHigh = Color(0xFF2B2E31); // tiles inside cards
  static const sheet = Color(0xFF161819); // bottom sheets and dialogs
  static const border = Color(0xFF303337);
  static const danger = Color(0xFFFF5A61);
  static const dangerSoft = Color(0xFF3A1416);
  static const success = Color(0xFF36C77E);
  static const successSoft = Color(0xFF10301F);
  static const info = Color(0xFF5B9BFF);
  static const infoSoft = Color(0xFF14233F);
  static const star = Color(0xFFFFC53D);
  static const pickup = primary;
  static const destination = Color(0xFFFFFFFF);
  static const verified = info;
}

class AppTheme {
  static const font = 'Manrope';

  static ThemeData get dark {
    final scheme = const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.primary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.surfaceHigh,
      onSecondaryContainer: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSoft,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.sheet,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surface,
      surfaceContainerHighest: AppColors.surfaceHigh,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      error: AppColors.danger,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: font,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
    );
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
        fontFamily: font,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: font,
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceHigh,
          disabledForegroundColor: AppColors.inkFaint,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          shape: pill,
          textStyle: const TextStyle(
            fontFamily: font,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: AppColors.border),
          shape: pill,
          textStyle: const TextStyle(
            fontFamily: font,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          textStyle: const TextStyle(
            fontFamily: font,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.inkFaint),
        labelStyle: const TextStyle(color: AppColors.inkSoft),
        floatingLabelStyle: const TextStyle(color: AppColors.primaryLight),
        prefixIconColor: AppColors.inkSoft,
        suffixIconColor: AppColors.inkSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        disabledColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(
          fontFamily: font,
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: font,
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        iconTheme: const IconThemeData(color: AppColors.ink, size: 16),
        shape: const StadiumBorder(),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.inkSoft,
          selectedBackgroundColor: AppColors.primary,
          selectedForegroundColor: Colors.white,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.inkSoft,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.surfaceHigh,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.inkFaint,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        circularTrackColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.inkSoft,
        textColor: AppColors.ink,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.sheet,
        modalBackgroundColor: AppColors.sheet,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.sheet,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.sheet,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.sheet,
        headerForegroundColor: AppColors.ink,
        rangePickerBackgroundColor: AppColors.background,
        rangePickerHeaderBackgroundColor: AppColors.background,
        rangePickerHeaderForegroundColor: AppColors.ink,
        rangeSelectionBackgroundColor: AppColors.primarySoft,
        todayForegroundColor: const WidgetStatePropertyAll(
          AppColors.primaryLight,
        ),
        todayBorder: const BorderSide(color: AppColors.primary),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: TextStyle(fontFamily: font, color: AppColors.ink),
        actionTextColor: AppColors.primaryLight,
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        textStyle: TextStyle(fontFamily: font, color: AppColors.ink),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    );
  }
}
