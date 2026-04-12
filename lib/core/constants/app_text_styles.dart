import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Use Inter font
  // All text styles follow an 8pt baseline grid

  // Display: 32/40px — for hero numbers and big headings
  static TextStyle get display => GoogleFonts.inter(
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w700,
        color: AppColors.ink900,
      );

  // Title: 22px — screen titles
  static TextStyle get title => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.ink900,
      );

  // Subtitle: 17px — card headings
  static TextStyle get subtitle => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.ink900,
      );

  // Body: 15px — body copy
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.ink700,
      );

  // Caption: 13px — hints, labels
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.ink500,
      );

  // Micro: 11px — badges, chips
  static TextStyle get micro => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.ink500,
      );
}
