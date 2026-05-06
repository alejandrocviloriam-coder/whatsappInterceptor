// lib/firebase_config.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Clase para manejar la configuración de Firebase
class FirebaseConfig {
  // Opciones de Firebase
  static FirebaseOptions? _options;
  
  // Flag para controlar inicialización
  static bool _isInitialized = false;
  
  /// Obtiene o crea las opciones de Firebase
  static Future<FirebaseOptions> getOptions() async {
    if (_options != null) {
      return _options!;
    }
    
    try {
      // En Android, las opciones están en google-services.json
      // y son manejadas automáticamente por Firebase
      
      // Para web o testing podemos cargar un archivo de configuración
      // Pero en este caso no es necesario ya que estamos en Android
      
      _options = const FirebaseOptions(
        apiKey: 'default',
        appId: 'default',
        messagingSenderId: 'default',
        projectId: 'default',
      );
      
      return _options!;
    } catch (e) {
      if (kDebugMode) {
        print('[FirebaseConfig] Error obteniendo opciones: $e');
      }
      
      // Proporcionar opciones predeterminadas para no bloquear la app
      return const FirebaseOptions(
        apiKey: 'default',
        appId: 'default',
        messagingSenderId: 'default',
        projectId: 'default',
      );
    }
  }
  
  /// Inicializa Firebase con las opciones correspondientes
  static Future<void> initializeApp() async {
    if (_isInitialized) return;
    
    try {
      // En Android la inicialización es automática y usa google-services.json
      await Firebase.initializeApp();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('[FirebaseConfig] Firebase inicializado correctamente');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[FirebaseConfig] Error inicializando Firebase: $e');
      }
      rethrow;
    }
  }
  
  /// Verifica si Firebase está disponible
  static Future<bool> checkAvailability() async {
    try {
      if (!_isInitialized) {
        await initializeApp();
      }
      
      // Si llegamos aquí, Firebase está disponible
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[FirebaseConfig] Firebase no disponible: $e');
      }
      return false;
    }
  }
}