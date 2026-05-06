// lib/services/app_visibility_service.dart
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whatsapp_interceptor/utils/logger.dart';

class AppVisibilityService {
  static const String _tag = "AppVisibilityService";
  static const String _visibilityKey = "app_is_invisible";
  
  bool _isInvisible = false;
  
  // Stream para notificar cambios en el estado de visibilidad
  final _visibilityController = StreamController<bool>.broadcast();
  Stream<bool> get visibilityStream => _visibilityController.stream;
  
  // Getter para el estado actual
  bool get isInvisible => _isInvisible;
  
  // Inicializar el servicio
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isInvisible = prefs.getBool(_visibilityKey) ?? false;
      _visibilityController.add(_isInvisible);
      
      logger.d(_tag, "Servicio inicializado. Estado de invisibilidad: $_isInvisible");
    } catch (e) {
      logger.e(_tag, "Error al inicializar servicio de visibilidad", e);
      // Por defecto, si hay error, la app no estará invisible
      _isInvisible = false;
      _visibilityController.add(_isInvisible);
    }
  }
  
  // Cambiar el estado de visibilidad
  Future<void> toggleVisibility() async {
    try {
      _isInvisible = !_isInvisible;
      
      // Guardar el nuevo estado en preferencias
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_visibilityKey, _isInvisible);
      
      // Notificar a los oyentes
      _visibilityController.add(_isInvisible);
      
      logger.d(_tag, "Estado de visibilidad cambiado a: $_isInvisible");
    } catch (e) {
      logger.e(_tag, "Error al cambiar estado de visibilidad", e);
    }
  }
  
  // Método para establecer directamente el estado de visibilidad
  Future<void> setInvisible(bool invisible) async {
    if (_isInvisible != invisible) {
      try {
        _isInvisible = invisible;
        
        // Guardar el nuevo estado en preferencias
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_visibilityKey, _isInvisible);
        
        // Notificar a los oyentes
        _visibilityController.add(_isInvisible);
        
        logger.d(_tag, "Estado de visibilidad establecido a: $_isInvisible");
      } catch (e) {
        logger.e(_tag, "Error al establecer estado de visibilidad", e);
      }
    }
  }
  
  // Método para liberar recursos
  void dispose() {
    _visibilityController.close();
  }
}

// Instancia global del servicio
final appVisibilityService = AppVisibilityService();