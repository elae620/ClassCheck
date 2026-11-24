import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:classcheck/core/theme/app_colors.dart';

/// Styles de texte (police Poppins) utilisés dans toute l'application.
class AppText {
  AppText._();

  static TextStyle get grandTitre => GoogleFonts.poppins(
      fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.texte, height: 1.15);
  static TextStyle get titre => GoogleFonts.poppins(
      fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.texte);
  static TextStyle get entete => GoogleFonts.poppins(
      fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.texte);
  static TextStyle get sousTitre => GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.texte);
  static TextStyle get corps => GoogleFonts.poppins(
      fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.texte);
  static TextStyle get secondaire => GoogleFonts.poppins(
      fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.texteSecondaire);
  static TextStyle get petit => GoogleFonts.poppins(
      fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.texteSecondaire);
  static TextStyle get valeur => GoogleFonts.poppins(
      fontSize: 30, fontWeight: FontWeight.w600, color: AppColors.texte);
  static TextStyle get lien => GoogleFonts.poppins(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.lien,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.lien);
}

class AppTheme {
  AppTheme._();

  static ThemeData clair() {
    final schema = ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      surface: AppColors.fond,
    ).copyWith(
      primary: AppColors.texte,
      onPrimary: AppColors.blanc,
      secondary: AppColors.violet,
      error: const Color(0xFFC0392B),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: schema);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.fond,
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: AppColors.texte,
        displayColor: AppColors.texte,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.texte,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.texte,
        contentTextStyle: GoogleFonts.poppins(color: AppColors.blanc, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.texte),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
