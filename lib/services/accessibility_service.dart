import 'dart:async';
import 'package:flutter/services.dart';
import 'package:whatsapp_interceptor/utils/logger.dart';

/// Servicio para interactuar con el servicio de accesibilidad de Android
class AccessibilityService {
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  
  AccessibilityService._internal();
  
  static const String _tag = "AccessibilityService";
  
  // Canal principal para detector
  static const MethodChannel _channel = MethodChannel('com.example.whatsapp_interceptor/detector');
  // Canal específico para accesibilidad (solo para abrir settings)
  static const MethodChannel _accessibilityChannel = MethodChannel('com.example.whatsapp_interceptor/accessibility');
  
  // Si el servicio está inicializado correctamente
  bool _isInitialized = false;
  
  // Controladores para notificar cambios
  final _serviceStatusController = StreamController<bool>.broadcast();
  Stream<bool> get serviceStatusStream => _serviceStatusController.stream;
  
  final _messageStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;
  
  /// Inicializa el servicio
  Future<bool> init() async {
    try {
      // Verificar si los servicios están disponibles
      _isInitialized = true;
      
      // Verificar el estado inicial
      final isEnabled = await isAccessibilityServiceEnabled();
      _serviceStatusController.add(isEnabled);
      
      logger.d(_tag, "Servicio de accesibilidad inicializado");
      return true;
    } catch (e) {
      logger.e(_tag, "Error al inicializar servicio de accesibilidad", e);
      return false;
    }
  }
  
  /// Verifica periódicamente si el servicio está activado
  Future<bool> checkServiceRunning() async {
    final isEnabled = await isAccessibilityServiceEnabled();
    _serviceStatusController.add(isEnabled);
    return isEnabled;
  }
  
  /// Verifica si el servicio de accesibilidad está activado
  Future<bool> isAccessibilityServiceEnabled() async {
    if (!_isInitialized) {
      logger.w(_tag, "Servicio no inicializado");
      return false;
    }
    
    try {
      final bool isEnabled = await _channel.invokeMethod('isServiceRunning');
      logger.d(_tag, "Estado del servicio de accesibilidad: $isEnabled");
      return isEnabled;
    } catch (e) {
      logger.e(_tag, "Error al verificar servicio de accesibilidad", e);
      return false;
    }
  }
  
  /// Verifica si el servicio de notificaciones está activado
  Future<bool> isNotificationServiceEnabled() async {
    if (!_isInitialized) {
      logger.w(_tag, "Servicio no inicializado");
      return false;
    }
    
    try {
      final bool isEnabled = await _channel.invokeMethod('isNotificationServiceRunning');
      logger.d(_tag, "Estado del servicio de notificaciones: $isEnabled");
      return isEnabled;
    } catch (e) {
      logger.e(_tag, "Error al verificar servicio de notificaciones", e);
      return false;
    }
  }
  
  /// Abre la configuración de accesibilidad para activar el servicio
  Future<bool> openAccessibilitySettings() async {
    if (!_isInitialized) {
      logger.w(_tag, "Servicio no inicializado");
      return false;
    }
    
    try {
      await _accessibilityChannel.invokeMethod('openAccessibilitySettings');
      logger.d(_tag, "Abriendo configuración de accesibilidad");
      return true;
    } catch (e) {
      logger.e(_tag, "Error al abrir configuración de accesibilidad", e);
      return false;
    }
  }
  
  /// Abre la configuración de notificaciones para activar el servicio
  Future<bool> openNotificationSettings() async {
    if (!_isInitialized) {
      logger.w(_tag, "Servicio no inicializado");
      return false;
    }
    
    try {
      await _channel.invokeMethod('openNotificationSettings');
      logger.d(_tag, "Abriendo configuración de notificaciones");
      return true;
    } catch (e) {
      logger.e(_tag, "Error al abrir configuración de notificaciones", e);
      return false;
    }
  }
  
  /// Libera recursos
  void dispose() {
    _serviceStatusController.close();
    _messageStreamController.close();
  }
}

// Instancia global
final accessibilityService = AccessibilityService();