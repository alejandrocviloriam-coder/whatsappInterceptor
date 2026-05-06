import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class WhatsAppDetectorService {
  static const _channel = MethodChannel('com.example.whatsapp_interceptor/whatsapp');
  
  // Estado del detector
  bool _isDetecting = false;
  bool _isWhatsAppInstalled = false;
  bool _isWhatsAppActive = false;
  
  // Stream para notificar cambios de estado
  final _stateStreamController = StreamController<Map<String, bool>>.broadcast();
  Stream<Map<String, bool>> get stateStream => _stateStreamController.stream;
  
  // Singleton
  static final WhatsAppDetectorService _instance = WhatsAppDetectorService._internal();
  factory WhatsAppDetectorService() => _instance;
  WhatsAppDetectorService._internal();
  
  // Timer para el polling
  Timer? _detectionTimer;
  
  Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
    
    try {
      // Verificar si WhatsApp está instalado
      final isInstalled = await _channel.invokeMethod<bool>('isWhatsAppInstalled') ?? false;
      _isWhatsAppInstalled = isInstalled;
      
      if (isInstalled) {
        // Cargar configuración de preferencias
        final prefs = await SharedPreferences.getInstance();
        final autoStart = prefs.getBool('auto_start_enabled') ?? false;
        
        if (autoStart) {
          startDetection();
        }
      }
      
      // Notificar estado inicial
      _notifyState();
    } catch (e) {
      debugPrint('Error al inicializar detector de WhatsApp: $e');
    }
  }
  
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'whatsAppStateChanged':
        final isActive = call.arguments as bool;
        _isWhatsAppActive = isActive;
        _notifyState();
        break;
      default:
        break;
    }
    return null;
  }
  
  void _notifyState() {
    _stateStreamController.add({
      'isDetecting': _isDetecting,
      'isWhatsAppInstalled': _isWhatsAppInstalled,
      'isWhatsAppActive': _isWhatsAppActive,
    });
  }
  
  // Iniciar detección
  Future<void> startDetection() async {
    if (_isDetecting) return;
    
    try {
      await _channel.invokeMethod('startWhatsAppDetection');
      _isDetecting = true;
      
      // Iniciar polling periódico para verificar si WhatsApp está en primer plano
      _detectionTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        try {
          final isActive = await _channel.invokeMethod<bool>('isWhatsAppInForeground') ?? false;
          if (_isWhatsAppActive != isActive) {
            _isWhatsAppActive = isActive;
            _notifyState();
          }
        } catch (e) {
          debugPrint('Error en polling de estado de WhatsApp: $e');
        }
      });
      
      _notifyState();
    } catch (e) {
      debugPrint('Error al iniciar detección de WhatsApp: $e');
    }
  }
  
  // Detener detección
  Future<void> stopDetection() async {
    if (!_isDetecting) return;
    
    try {
      await _channel.invokeMethod('stopWhatsAppDetection');
      _isDetecting = false;
      _isWhatsAppActive = false;
      
      _detectionTimer?.cancel();
      _detectionTimer = null;
      
      _notifyState();
    } catch (e) {
      debugPrint('Error al detener detección de WhatsApp: $e');
    }
  }
  
  // Verificar si WhatsApp está instalado
  Future<bool> isWhatsAppInstalled() async {
    try {
      return await _channel.invokeMethod<bool>('isWhatsAppInstalled') ?? false;
    } catch (e) {
      debugPrint('Error al verificar si WhatsApp está instalado: $e');
      return false;
    }
  }
  
  void dispose() {
    _detectionTimer?.cancel();
    _stateStreamController.close();
  }
}