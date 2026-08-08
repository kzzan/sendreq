import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'form_control_metrics.dart';

/// 应用主题构建器：统一提供亮色/暗色 ThemeData。
abstract final class SendreqTheme {
  /// 构建暗色主题。
  static ThemeData dark({String? fontFamily}) {
    // 全主题共用的基础文字样式（字体与颜色）。
    final baseText = TextStyle(
      color: AppColors.text,
      fontFamily: fontFamily,
      letterSpacing: 0,
    );

    return _buildTheme(Brightness.dark, baseText);
  }

  /// 构建亮色主题。
  static ThemeData light({String? fontFamily}) {
    // 全主题共用的基础文字样式（字体与颜色）。
    final baseText = TextStyle(
      color: AppColors.text,
      fontFamily: fontFamily,
      letterSpacing: 0,
    );
    return _buildTheme(Brightness.light, baseText);
  }

  /// 构建桌面工作台共享主题。所有表单、弹层和操作反馈从这里继承，
  /// 让高频编辑时的层级、密度和键盘焦点保持一致。
  static ThemeData _buildTheme(Brightness brightness, TextStyle baseText) {
    final compactShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: AppColors.outline),
    );
    final focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    );
    final disabledInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: AppColors.outline.withValues(alpha: 0.6)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: AppColors.background,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      // 以语义色板驱动 Material 配色。
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        error: AppColors.danger,
      ),
      // 按信息层级定义标题、正文与标签样式。
      textTheme: TextTheme(
        titleLarge: baseText.copyWith(
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: baseText.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: baseText.copyWith(fontSize: 13, height: 1.35),
        bodySmall: baseText.copyWith(
          fontSize: 12,
          height: 1.25,
          color: AppColors.textMuted,
        ),
        labelSmall: baseText.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textFaint,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        // 表单使用低层级表面；统一 36px 基线且不抢占数据内容。
        fillColor: AppColors.surfaceLow,
        constraints: FormControlMetrics.standardConstraints,
        contentPadding: FormControlMetrics.inputPadding,
        prefixIconConstraints: FormControlMetrics.iconConstraints,
        suffixIconConstraints: FormControlMetrics.iconConstraints,
        hintStyle: baseText.copyWith(
          color: AppColors.textFaint,
          fontSize: 12,
          height: 1.25,
        ),
        labelStyle: baseText.copyWith(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: baseText.copyWith(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        helperStyle: baseText.copyWith(
          color: AppColors.textFaint,
          fontSize: 11,
          height: 1.3,
        ),
        errorStyle: baseText.copyWith(
          color: AppColors.danger,
          fontSize: 11,
          height: 1.3,
        ),
        counterStyle: baseText.copyWith(
          color: AppColors.textFaint,
          fontSize: 10,
        ),
        prefixIconColor: AppColors.textFaint,
        suffixIconColor: AppColors.textFaint,
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: disabledInputBorder,
        focusedBorder: focusedInputBorder,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceLow,
          constraints: FormControlMetrics.standardConstraints,
          contentPadding: FormControlMetrics.inputPadding,
          prefixIconConstraints: FormControlMetrics.iconConstraints,
          suffixIconConstraints: FormControlMetrics.iconConstraints,
          border: inputBorder,
          enabledBorder: inputBorder,
          focusedBorder: focusedInputBorder,
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.surfaceHighest),
          side: WidgetStatePropertyAll(BorderSide(color: AppColors.outline)),
          shape: WidgetStatePropertyAll(compactShape),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 4),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.onPrimary
              : AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.primaryContainer
              : AppColors.surfaceHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.outlineStrong;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.primaryContainer
              : Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(AppColors.onPrimary),
        side: BorderSide(color: AppColors.outlineStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.outlineStrong;
        }),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: 0.28),
        selectionHandleColor: AppColors.primary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          backgroundColor: AppColors.primaryContainer,
          foregroundColor: AppColors.onPrimary,
          textStyle: baseText.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          shape: compactShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          foregroundColor: AppColors.text,
          side: BorderSide(color: AppColors.outline),
          textStyle: baseText.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          shape: compactShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          foregroundColor: AppColors.primary,
          textStyle: baseText.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          shape: compactShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textMuted,
          disabledForegroundColor: AppColors.textFaint.withValues(alpha: 0.55),
          shape: compactShape,
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.surfaceHighest),
          side: WidgetStatePropertyAll(BorderSide(color: AppColors.outline)),
          shape: WidgetStatePropertyAll(compactShape),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 4),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceHighest,
        shape: compactShape,
        textStyle: baseText.copyWith(fontSize: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        titleTextStyle: baseText.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: baseText.copyWith(
          fontSize: 13,
          color: AppColors.textMuted,
          height: 1.45,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHighest,
        contentTextStyle: baseText.copyWith(fontSize: 12),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          AppColors.outlineStrong.withValues(alpha: 0.65),
        ),
        trackColor: WidgetStatePropertyAll(AppColors.surfaceHigh),
        radius: const Radius.circular(3),
        thickness: const WidgetStatePropertyAll(6),
      ),
      // 统一工具提示的容器与文字样式。
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceHighest,
          border: Border.all(color: AppColors.outline),
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: TextStyle(color: AppColors.text, fontSize: 12),
      ),
    );
  }
}
