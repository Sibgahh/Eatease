import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App theme utility class that provides consistent styling across the app
class AppTheme {
  AppTheme._(); // Private constructor to prevent instantiation
  
  // App Colors
  static const Color primaryColor = Color(0xFF2196F3);  // Blue
  static const Color accentColor = Color(0xFFFF9800);   // Orange
  static const Color backgroundColor = Color(0xFFF5F5F5); // Light grey
  static const Color errorColor = Color(0xFFE53935);    // Red
  static const Color successColor = Color(0xFF4CAF50);  // Green
  static const Color textPrimaryColor = Color(0xFF212121); // Dark grey
  static const Color textSecondaryColor = Color(0xFF757575); // Medium grey
  static const Color dividerColor = Color(0xFFBDBDBD);  // Light grey
  
  // Font Weights
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  
  // Text Styles with Poppins font
  static TextStyle getTextStyle(double fontSize, FontWeight fontWeight, Color color) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
  
  static TextStyle headingLarge({Color color = textPrimaryColor}) {
    return getTextStyle(26, bold, color);
  }
  
  static TextStyle headingMedium({Color color = textPrimaryColor}) {
    return getTextStyle(22, semiBold, color);
  }
  
  static TextStyle headingSmall({Color color = textPrimaryColor}) {
    return getTextStyle(18, semiBold, color);
  }
  
  static TextStyle bodyLarge({Color color = textPrimaryColor}) {
    return getTextStyle(16, regular, color);
  }
  
  static TextStyle bodyMedium({Color color = textPrimaryColor}) {
    return getTextStyle(14, regular, color);
  }
  
  static TextStyle bodySmall({Color color = textSecondaryColor}) {
    return getTextStyle(12, regular, color);
  }
  
  static TextStyle buttonText({Color color = Colors.white}) {
    return getTextStyle(16, medium, color);
  }
  
  // Custom shadows
  static List<BoxShadow> getShadow({Color? color, double opacity = 0.2, double blurRadius = 8}) {
    return [
      BoxShadow(
        color: (color ?? Colors.black).withOpacity(opacity),
        blurRadius: blurRadius,
        offset: const Offset(0, 3),
      ),
    ];
  }
  
  // App theme data
  static ThemeData getThemeData(BuildContext context) {
    return ThemeData(
      primarySwatch: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: GoogleFonts.poppins().fontFamily,
      
      // Apply Poppins to text theme
      textTheme: GoogleFonts.poppinsTextTheme(
        Theme.of(context).textTheme,
      ),
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 2,
        titleTextStyle: getTextStyle(20, semiBold, Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      
      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          textStyle: buttonText(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        fillColor: Colors.white,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: errorColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: errorColor, width: 2),
        ),
        labelStyle: bodyMedium(color: textSecondaryColor),
        hintStyle: bodyMedium(color: textSecondaryColor.withOpacity(0.7)),
        errorStyle: bodySmall(color: errorColor),
        prefixIconColor: textSecondaryColor,
        suffixIconColor: textSecondaryColor,
      ),
      
      // Card theme
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
      ),
    );
  }
} 