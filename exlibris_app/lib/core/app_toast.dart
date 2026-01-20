import 'package:flutter/material.dart';

/// Types de notifications disponibles
enum ToastType { success, error, info, warning }

/// Utilitaire pour afficher des notifications élégantes
class AppToast {
  /// Affiche un toast stylisé
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final config = _getConfig(type);
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: config.iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                config.icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: config.bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: config.borderColor, width: 1),
        ),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  /// Affiche un toast de succès
  static void success(BuildContext context, String message) {
    show(context, message: message, type: ToastType.success);
  }

  /// Affiche un toast d'erreur
  static void error(BuildContext context, String message) {
    show(context, message: message, type: ToastType.error);
  }

  /// Affiche un toast d'info
  static void info(BuildContext context, String message) {
    show(context, message: message, type: ToastType.info);
  }

  /// Affiche un toast d'avertissement
  static void warning(BuildContext context, String message) {
    show(context, message: message, type: ToastType.warning);
  }

  static _ToastConfig _getConfig(ToastType type) {
    switch (type) {
      case ToastType.success:
        return _ToastConfig(
          icon: Icons.check_circle_rounded,
          bgColor: const Color(0xFF1A3A2A),
          iconBgColor: const Color(0xFF22C55E),
          borderColor: const Color(0xFF22C55E).withOpacity(0.3),
        );
      case ToastType.error:
        return _ToastConfig(
          icon: Icons.error_rounded,
          bgColor: const Color(0xFF3A1A1A),
          iconBgColor: const Color(0xFFEF4444),
          borderColor: const Color(0xFFEF4444).withOpacity(0.3),
        );
      case ToastType.warning:
        return _ToastConfig(
          icon: Icons.warning_rounded,
          bgColor: const Color(0xFF3A2A1A),
          iconBgColor: const Color(0xFFF59E0B),
          borderColor: const Color(0xFFF59E0B).withOpacity(0.3),
        );
      case ToastType.info:
        return _ToastConfig(
          icon: Icons.info_rounded,
          bgColor: const Color(0xFF1A2A3A),
          iconBgColor: const Color(0xFF3B82F6),
          borderColor: const Color(0xFF3B82F6).withOpacity(0.3),
        );
    }
  }
}

class _ToastConfig {
  final IconData icon;
  final Color bgColor;
  final Color iconBgColor;
  final Color borderColor;

  _ToastConfig({
    required this.icon,
    required this.bgColor,
    required this.iconBgColor,
    required this.borderColor,
  });
}
