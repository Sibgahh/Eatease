import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App theme utility class that provides consistent styling across the app
class AppTheme {
  AppTheme._(); // Private constructor to prevent instantiation
  
  // Theme Colors for different roles
  static const Color customerPrimaryColor = Color(0xFF2D664A);  // Primary Green
  static const Color customerSecondaryColor = Color(0xFFEEAD55);  // Secondary Orange
  static const Color customerAccentColor = Color(0xFFF6E8CF);  // Light Beige
  static const Color merchantPrimaryColor = Color(0xFF2D664A);  // Green
  static const Color merchantSecondaryColor = Color(0xFF3F51B5);  // Indigo Blue
  static const Color adminPrimaryColor = Color(0xFF212121);     // Dark Grey
  
  // Common Colors
  static const Color backgroundColor = Color(0xFFF5F5F5); // Light grey
  static const Color errorColor = Color(0xFFE53935);    // Red
  static const Color successColor = Color(0xFF4CAF50);  // Green
  static const Color textPrimaryColor = Color(0xFF212121); // Dark grey
  static const Color textSecondaryColor = Color(0xFF757575); // Medium grey
  static const Color dividerColor = Color(0xFFBDBDBD);  // Light grey
  
  // Neumorphism Colors
  static const Color neumorphismLight = Color(0xFFFFFFFF);
  static const Color neumorphismDark = Color(0xFFE0E0E0);
  static const Color neumorphismBackground = Color(0xFFF0F0F0);
  
  // Font Weights
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  
  // Get primary color based on user role
  static Color getPrimaryColor(String role) {
    switch (role.toLowerCase()) {
      case 'customer':
        return customerPrimaryColor;
      case 'merchant':
        return merchantPrimaryColor;
      case 'admin':
        return adminPrimaryColor;
      default:
        return customerPrimaryColor;
    }
  }

  // Get secondary color based on user role
  static Color getSecondaryColor(String role) {
    switch (role.toLowerCase()) {
      case 'customer':
        return customerSecondaryColor;
      case 'merchant':
        return merchantSecondaryColor;
      case 'admin':
        return adminPrimaryColor;
      default:
        return customerSecondaryColor;
    }
  }

  // Get accent color based on user role
  static Color getAccentColor(String role) {
    switch (role.toLowerCase()) {
      case 'customer':
        return customerAccentColor;
      case 'merchant':
        return merchantPrimaryColor;
      case 'admin':
        return adminPrimaryColor;
      default:
        return customerAccentColor;
    }
  }

  // Get primary color from context
  static Color get primaryColor {
    // Default to customer color if no context is available
    return customerPrimaryColor;
  }

  // Get secondary color from context
  static Color get secondaryColor {
    return customerSecondaryColor;
  }

  // Get accent color from context
  static Color get accentColor {
    return customerAccentColor;
  }
  
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
  
  // Neumorphism Shadows
  static List<BoxShadow> getNeumorphismShadow({bool isPressed = false}) {
    if (isPressed) {
      return [
        BoxShadow(
          color: neumorphismDark,
          offset: const Offset(2, 2),
          blurRadius: 2,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: neumorphismLight,
          offset: const Offset(-2, -2),
          blurRadius: 2,
          spreadRadius: 1,
        ),
      ];
    }
    return [
      BoxShadow(
        color: neumorphismDark,
        offset: const Offset(4, 4),
        blurRadius: 8,
        spreadRadius: 1,
      ),
      BoxShadow(
        color: neumorphismLight,
        offset: const Offset(-4, -4),
        blurRadius: 8,
        spreadRadius: 1,
      ),
    ];
  }

  // Neumorphism Container Decoration
  static BoxDecoration getNeumorphismDecoration({
    bool isPressed = false,
    double borderRadius = 12,
    Color? color,
  }) {
    return BoxDecoration(
      color: color ?? neumorphismBackground,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: getNeumorphismShadow(isPressed: isPressed),
    );
  }

  // Neumorphism Button Style
  static ButtonStyle getNeumorphismButtonStyle({
    bool isPressed = false,
    double borderRadius = 12,
    Color? backgroundColor,
  }) {
    return ButtonStyle(
      backgroundColor: MaterialStateProperty.all(backgroundColor ?? neumorphismBackground),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      elevation: MaterialStateProperty.all(0),
      shadowColor: MaterialStateProperty.all(Colors.transparent),
      overlayColor: MaterialStateProperty.all(neumorphismDark.withOpacity(0.1)),
    );
  }
  
  // App theme data
  static ThemeData getThemeData(BuildContext context, {String role = 'customer'}) {
    final primaryColor = getPrimaryColor(role);
    final secondaryColor = getSecondaryColor(role);
    final accentColor = getAccentColor(role);
    final isAdmin = role.toLowerCase() == 'admin';
    
    return ThemeData(
      primaryColor: primaryColor,
      primarySwatch: _createMaterialColor(primaryColor),
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: Colors.white,
        background: isAdmin ? Colors.white : backgroundColor,
        error: errorColor,
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: isAdmin ? Colors.white : backgroundColor,
      fontFamily: GoogleFonts.poppins().fontFamily,
      
      // Apply Poppins to text theme
      textTheme: GoogleFonts.poppinsTextTheme(
        Theme.of(context).textTheme,
      ),
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        elevation: isAdmin ? 0 : 2,
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
          elevation: isAdmin ? 0 : 2,
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        fillColor: Colors.white,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isAdmin ? Colors.grey.shade300 : dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isAdmin ? Colors.grey.shade300 : dividerColor),
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
        elevation: isAdmin ? 0 : 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
      ),
    );
  }
  
  // Helper method to create MaterialColor from a single color
  static MaterialColor _createMaterialColor(Color color) {
    List<double> strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    
    return MaterialColor(color.value, swatch);
  }
} 