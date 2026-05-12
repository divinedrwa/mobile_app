import 'package:flutter/material.dart';

/// Application color palette — premium teal-and-gold theme
class AppColors {
  // Primary Colors (Deep Teal)
  static const Color primary = Color(0xFF0F766E);        // Teal 700
  static const Color primaryLight = Color(0xFF14B8A6);   // Teal 500
  static const Color primaryDark = Color(0xFF115E59);    // Teal 800
  static const Color primaryContainer = Color(0xFFCCFBF1); // Teal 100

  // Secondary Colors (Warm Amber)
  static const Color secondary = Color(0xFFD97706);      // Amber 600
  static const Color secondaryLight = Color(0xFFF59E0B); // Amber 500
  static const Color secondaryDark = Color(0xFFB45309);  // Amber 700
  static const Color secondaryContainer = Color(0xFFFEF3C7); // Amber 100

  // Accent Colors (Warm Amber)
  static const Color accent = Color(0xFFF59E0B);         // Amber 500
  static const Color accentLight = Color(0xFFFBBF24);    // Amber 400
  static const Color accentDark = Color(0xFFD97706);     // Amber 600
  
  // Semantic Colors
  static const Color success = Color(0xFF10B981);        // Emerald 500
  static const Color successLight = Color(0xFFD1FAE5);   // Emerald 100
  static const Color warning = Color(0xFFF59E0B);        // Amber 500
  static const Color warningLight = Color(0xFFFEF3C7);   // Amber 100
  static const Color error = Color(0xFFEF4444);          // Red 500
  static const Color errorLight = Color(0xFFFEE2E2);     // Red 100
  static const Color info = Color(0xFF14B8A6);           // Teal 500
  static const Color infoLight = Color(0xFFF0FDFA);      // Teal 50
  
  // Neutral Colors (Gray)
  static const Color textPrimary = Color(0xFF111827);    // Gray 900
  static const Color textSecondary = Color(0xFF6B7280);  // Gray 500
  static const Color textTertiary = Color(0xFF9CA3AF);   // Gray 400
  static const Color textDisabled = Color(0xFFD1D5DB);   // Gray 300
  
  // Background Colors
  static const Color background = Color(0xFFF0FDFA);     // Teal 50
  static const Color surface = Color(0xFFFFFFFF);        // White
  static const Color surfaceVariant = Color(0xFFF3F4F6); // Gray 100
  
  // Border Colors
  static const Color border = Color(0xFFE5E7EB);         // Gray 200
  static const Color borderDark = Color(0xFFD1D5DB);     // Gray 300
  static const Color divider = Color(0xFFF3F4F6);        // Gray 100
  
  // Special Colors
  static const Color shadow = Color(0x1A000000);         // Black 10%
  static const Color overlay = Color(0x80000000);        // Black 50%
  static const Color shimmer = Color(0xFFE5E7EB);        // Gray 200
  
  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Status Colors
  static const Color statusOnline = Color(0xFF10B981);   // Green
  static const Color statusOffline = Color(0xFF6B7280);  // Gray
  static const Color statusBusy = Color(0xFFEF4444);     // Red
  static const Color statusAway = Color(0xFFF59E0B);     // Amber
  
  // Chart Colors
  static const List<Color> chartColors = [
    Color(0xFF0F766E), // Teal
    Color(0xFFF59E0B), // Amber
    Color(0xFF10B981), // Emerald
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFFD97706), // Amber Dark
  ];

  // Role Colors
  static const Color roleAdmin = Color(0xFFEF4444);      // Red
  static const Color roleResident = Color(0xFF0F766E);   // Teal
  static const Color roleGuard = Color(0xFF10B981);      // Green
  
  // SOS Alert Colors
  static const Color sosMedical = Color(0xFFEF4444);     // Red
  static const Color sosFire = Color(0xFFF97316);        // Orange
  static const Color sosSecurity = Color(0xFFEAB308);    // Yellow
  static const Color sosOther = Color(0xFF6B7280);       // Gray
}
