// lib/services/incoming_message_detector.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Clase que detecta y gestiona mensajes entrantes de WhatsApp
/// a través del servicio de notificaciones.
class IncomingMessageDetector {
  static final IncomingMessageDetector _instance = IncomingMessageDetector._internal();
  factory IncomingMessageDetector() => _instance;
  
  IncomingMessageDetector._internal();
  
  /// Canal de método para comunicación con el código nativo
  static const _methodChannel = MethodChannel('com.example.whatsapp_interceptor/incoming_message_detector');
  
  /// Controlador de stream para mensajes interceptados
  final _messageStreamController = StreamController<Map<String, dynamic>>.broadcast();
  
  /// Obtener stream de mensajes interceptados
  Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;
  
  /// Controlador para el estado del servicio
  final _serviceStatusController = StreamController<bool>.broadcast();
  
  /// Stream para monitorear el estado del servicio
  Stream<bool> get serviceStatusStream => _serviceStatusController.stream;
  
  /// Estado de inicialización
  bool _isInitialized = false;
  final _initCompleter = Completer<void>();
  Future<void> get initialized => _initCompleter.future;
  
  /// Estado actual del servicio
  bool _isServiceRunning = false;
  
  /// Control de mensajes duplicados
  final Set<String> _recentMessageSignatures = {};
  final int _maxRecentMessages = 100;
  
  /// Inicializa el detector de mensajes
  Future<void> init() async {
    if (_isInitialized) {
      return initialized;
    }
    
    try {
      // Configurar manejador de métodos para recibir eventos desde nativo
      _methodChannel.setMethodCallHandler(_handleMethodCall);
      
      // Verificar estado inicial del servicio
      _isServiceRunning = await isServiceRunning();
      _serviceStatusController.add(_isServiceRunning);
      
      // Iniciar limpieza periódica del cache de mensajes
      _startPeriodicCacheCleaning();
      
      if (kDebugMode) {
        print('[IncomingMessageDetector] Detector inicializado, servicio activo: $_isServiceRunning');
      }
      
      _isInitialized = true;
      _initCompleter.complete();
    } catch (e) {
      if (kDebugMode) {
        print('[IncomingMessageDetector] Error al inicializar: $e');
      }
      _initCompleter.completeError(e);
    }
    
    return initialized;
  }
  
  /// Inicia limpieza periódica del cache de mensajes
  void _startPeriodicCacheCleaning() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_recentMessageSignatures.length > _maxRecentMessages ~/ 2) {
        if (kDebugMode) {
          print('[IncomingMessageDetector] Limpiando cache de mensajes');
        }
        _recentMessageSignatures.clear();
      }
    });
  }
  
  /// Genera una firma única para un mensaje
  String _generateMessageSignature(Map<dynamic, dynamic> messageData) {
    final content = messageData['content'] as String;
    final sender = messageData['senderName'] as String? ?? 'unknown';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // Considerar solo los últimos 10 segundos como ventana de duplicados
    final timeWindow = (timestamp ~/ 10000).toString();
    
    return '$content|$sender|$timeWindow';
  }
  
  /// Verifica si un mensaje es duplicado
  bool _isDuplicate(Map<dynamic, dynamic> messageData) {
    final signature = _generateMessageSignature(messageData);
    if (_recentMessageSignatures.contains(signature)) {
      return true;
    }
    
    // Si no es duplicado, añadirlo al conjunto
    _recentMessageSignatures.add(signature);
    
    // Limitar tamaño del conjunto
    if (_recentMessageSignatures.length > _maxRecentMessages) {
      _recentMessageSignatures.remove(_recentMessageSignatures.first);
    }
    
    return false;
  }
  
  /// Maneja llamadas desde el código nativo
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onMessageIntercepted':
        // Recibimos un mensaje entrante
        final data = call.arguments as Map<dynamic, dynamic>;
        
        // Verificar si el mensaje es un duplicado
        if (_isDuplicate(data)) {
          if (kDebugMode) {
            print('[IncomingMessageDetector] Mensaje duplicado descartado: ${data['content']}');
          }
          return;
        }
        
        // Verificar que se tenga información de remitente
        final senderName = data['senderName'];
        if (senderName == null) {
          if (kDebugMode) {
            print('[IncomingMessageDetector] Advertencia: se recibió mensaje sin remitente');
          }
          
          // Para mensajes individuales, usar el recipientName como senderName
          // ya que en ese caso recipientName contiene el nombre del contacto
          if (data['recipientType'] == 'contact') {
            data['senderName'] = data['recipientName'];
            
            if (kDebugMode) {
              print('[IncomingMessageDetector] Inferido remitente: ${data['senderName']}');
            }
          } else {
            // Si no podemos determinar el remitente, usar un valor por defecto
            data['senderName'] = 'Desconocido';
          }
        }
        
        // Verificar timestamp
        if (data['timestamp'] is String) {
          try {
            // Convertir String a int si es necesario
            final timestampStr = data['timestamp'] as String;
            final timestamp = int.tryParse(timestampStr) ?? DateTime.now().millisecondsSinceEpoch;
            data['timestamp'] = timestamp;
          } catch (e) {
            // En caso de error, usar timestamp actual
            data['timestamp'] = DateTime.now().millisecondsSinceEpoch;
          }
        }
        
        // Emitir mensaje
        final Map<String, dynamic> messageData = Map<String, dynamic>.from(data);
        _messageStreamController.add(messageData);
        
        if (kDebugMode) {
          print('[IncomingMessageDetector] Mensaje interceptado: ${messageData['content']} - De: ${messageData['senderName']}');
        }
        break;
      
      case 'onNotificationServiceConnected':
        // El servicio de notificaciones se ha conectado
        _isServiceRunning = true;
        _serviceStatusController.add(true);
        
        if (kDebugMode) {
          print('[IncomingMessageDetector] Servicio de notificaciones conectado');
        }
        break;
      
      default:
        if (kDebugMode) {
          print('[IncomingMessageDetector] Método desconocido: ${call.method}');
        }
    }
  }
  
  /// Verifica si el servicio de notificaciones está activo
  Future<bool> isServiceRunning() async {
    try {
      final bool isRunning = await _methodChannel.invokeMethod('isServiceRunning');
      _isServiceRunning = isRunning;
      
      if (kDebugMode) {
        print('[IncomingMessageDetector] Servicio activo: $isRunning');
      }
      
      return isRunning;
    } catch (e) {
      if (kDebugMode) {
        print('[IncomingMessageDetector] Error al verificar servicio: $e');
      }
      return false;
    }
  }
  
  /// Método para verificar periódicamente el estado del servicio
  /// (Compatible con la versión anterior - checkServiceRunning)
  Future<bool> checkServiceRunning() async {
    final bool status = await isServiceRunning();
    _serviceStatusController.add(status);
    return status; // Devolver el estado para poder usarlo en expresiones
  }
  
  /// Abre la configuración de acceso a notificaciones
  Future<bool> openNotificationSettings() async {
    try {
      final bool result = await _methodChannel.invokeMethod('openNotificationSettings');
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('[IncomingMessageDetector] Error al abrir configuración: $e');
      }
      return false;
    }
  }
  
  /// Libera recursos
  void dispose() {
    _messageStreamController.close();
    _serviceStatusController.close();
  }
}

/// Instancia global del detector de mensajes entrantes
final incomingMessageDetector = IncomingMessageDetector();