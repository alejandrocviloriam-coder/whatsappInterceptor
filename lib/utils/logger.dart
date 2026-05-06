// lib/utils/logger.dart
import 'package:flutter/foundation.dart' show kDebugMode;

/// Clase sencilla para registro de logs en la aplicación
class Logger {
  /// Registra un mensaje de depuración
  void d(String tag, String message) {
    if (kDebugMode) {
      print('[DEBUG] [$tag] $message');
    }
  }

  /// Registra un mensaje de advertencia
  void w(String tag, String message) {
    if (kDebugMode) {
      print('[WARN] [$tag] $message');
    }
  }

  /// Registra un mensaje de error
  void e(String tag, String message, [Object? error]) {
    if (kDebugMode) {
      print('[ERROR] [$tag] $message');
      if (error != null) {
        print('[ERROR] [$tag] Stack: $error');
      }
    }
  }

  /// Registra un mensaje informativo
  void i(String tag, String message) {
    if (kDebugMode) {
      print('[INFO] [$tag] $message');
    }
  }
}

/// Instancia global para usar en toda la app
final logger = Logger();