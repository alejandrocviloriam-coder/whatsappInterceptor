// lib/services/message_handler.dart
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whatsapp_interceptor/models/message.dart';
import 'package:whatsapp_interceptor/services/contact_normalizer.dart';
import 'package:whatsapp_interceptor/services/accessibility_service.dart';
import 'package:whatsapp_interceptor/services/incoming_message_detector.dart';
import 'package:whatsapp_interceptor/services/firebase_message_service.dart';
import 'package:whatsapp_interceptor/utils/logger.dart';

/// Servicio central para manejar todos los mensajes interceptados
/// y garantizar la correcta asociación entre contactos y mensajes
class MessageHandler {
  static final MessageHandler _instance = MessageHandler._internal();
  factory MessageHandler() => _instance;
  
  static const String _tag = "MessageHandler";
  
  MessageHandler._internal();
  
  // Set para detectar mensajes duplicados
  final Set<String> _processedMessageIds = {};
  
  // Control de flujo
  bool _isInitialized = false;
  final _initCompleter = Completer<void>();
  Future<void> get initialized => _initCompleter.future;
  
  // Suscripciones a servicios
  StreamSubscription? _accessibilitySubscription;
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _firebaseMessagesSubscription;
  
  // Referencia a servicios
  final _firebaseService = firebaseMessageService;
  
  /// Inicializa el manejador de mensajes
  Future<void> init() async {
    if (_isInitialized) return initialized;
    
    try {
      // Inicializar servicios dependientes
      await contactNormalizer.loadContactIdentifiers();
      
      // Inicializar detector de duplicados
      await _loadProcessedIds();
      
      // Suscribirse a los mensajes de Firebase
      _firebaseMessagesSubscription = _firebaseService.messagesStream.listen((messages) {
        logger.d(_tag, "Actualizados ${messages.length} mensajes desde Firebase");
      });
      
      // Suscribirse a los servicios de intercepción de mensajes
      // Nota: estos servicios ahora solo notifican, no almacenan directamente
      _accessibilitySubscription = accessibilityService.messageStream.listen(_handleAccessibilityMessage);
      _notificationSubscription = incomingMessageDetector.messageStream.listen(_handleIncomingMessage);
      
      logger.d(_tag, "Manejador de mensajes inicializado");
      
      // Marcar como inicializado
      _isInitialized = true;
      _initCompleter.complete();
    } catch (e) {
      logger.e(_tag, "Error al inicializar", e);
      _initCompleter.completeError(e);
    }
    
    return initialized;
  }
  
  // Carga los IDs de mensajes procesados desde preferencias
  Future<void> _loadProcessedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? ids = prefs.getStringList('processed_message_ids');
      
      if (ids != null) {
        _processedMessageIds.addAll(ids);
        
        logger.d(_tag, "Cargados ${ids.length} IDs de mensajes procesados");
      }
    } catch (e) {
      logger.e(_tag, "Error al cargar IDs procesados", e);
    }
  }
  
  // Guarda los IDs de mensajes procesados en preferencias
  Future<void> _saveProcessedIds() async {
    try {
      // Limitar el tamaño del conjunto a los 200 más recientes
      final List<String> recentIds = _processedMessageIds.toList();
      if (recentIds.length > 200) {
        recentIds.removeRange(0, recentIds.length - 200);
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('processed_message_ids', recentIds);
      
      logger.d(_tag, "Guardados ${recentIds.length} IDs de mensajes");
    } catch (e) {
      logger.e(_tag, "Error al guardar IDs procesados", e);
    }
  }
  
  // Verifica si un mensaje ya ha sido procesado
  bool _isAlreadyProcessed(WhatsAppMessage message) {
    final messageId = message.generateUniqueId();
    return _processedMessageIds.contains(messageId);
  }
  
  // Marca un mensaje como procesado
  void _markAsProcessed(WhatsAppMessage message) {
    final messageId = message.generateUniqueId();
    _processedMessageIds.add(messageId);
    
    // Guardar periódicamente para evitar pérdidas
    if (_processedMessageIds.length % 10 == 0) {
      _saveProcessedIds();
    }
  }
  
  // Nuevo método para procesar mensajes del servicio de accesibilidad
  Future<void> _handleAccessibilityMessage(Map<String, dynamic> data) async {
    try {
      // Determinar la dirección del mensaje
      final direction = data['direction'] as String?;
      
      if (direction == 'incoming') {
        // Procesar como mensaje entrante
        await _handleIncomingMessage(data);
      } else {
        // Procesar como mensaje saliente
        await _handleOutgoingMessage(data);
      }
    } catch (e) {
      logger.e(_tag, "Error procesando mensaje de accesibilidad", e);
    }
  }
  
  /// Procesa un mensaje saliente interceptado
  Future<void> _handleOutgoingMessage(Map<String, dynamic> data) async {
    try {
      // Crear mensaje desde los datos
      final message = WhatsAppMessage.fromJson(data);
      
      // Verificar si es un duplicado
      if (_isAlreadyProcessed(message)) {
        logger.d(_tag, "Mensaje saliente duplicado descartado: ${message.content}");
        return;
      }
      
      // Aplicar normalización de contacto
      final normalizedMessage = contactNormalizer.processMessage(message);
      
      // Simplemente marcamos el mensaje como procesado para evitar duplicación
      _markAsProcessed(normalizedMessage);
      
      logger.d(_tag, "Mensaje saliente procesado para: ${normalizedMessage.recipientName}");
      
      // Analizar mensajes para mejorar relaciones de contactos
      _analyzeContactRelations();
    } catch (e) {
      logger.e(_tag, "Error procesando mensaje saliente", e);
    }
  }
  
  /// Procesa un mensaje entrante interceptado
  Future<void> _handleIncomingMessage(Map<String, dynamic> data) async {
    try {
      // Crear mensaje desde los datos
      var message = WhatsAppMessage.fromJson(data);
      
      // Si el remitente es desconocido, intentar asignarle un contacto
      if (message.senderName == null || message.senderName == 'Desconocido') {
        logger.d(_tag, "Mensaje entrante con remitente desconocido, intentando inferir contacto...");
        
        // Buscar mensajes recientes para ver si podemos inferir el contacto
        final recentMessages = _firebaseService.getMessages().take(20).toList();
        
        // Buscar algún mensaje saliente reciente
        for (final recentMsg in recentMessages) {
          if (recentMsg.direction == MessageDirection.outgoing) {
            logger.d(_tag, "Aplicando coincidencia encontrada: ${recentMsg.recipientName}");
            
            // Actualizar el mensaje con el nombre inferido
            // Creamos una copia del mapa original para modificarlo
            final updatedData = Map<String, dynamic>.from(data);
            updatedData['senderName'] = recentMsg.recipientName;
            
            // Recrear el mensaje con los datos actualizados
            message = WhatsAppMessage.fromJson(updatedData);
            break; // Usar el primer match encontrado
          }
        }
      }
      
      // Normalizar mensaje usando sistema de contactos
      final normalizedMessage = contactNormalizer.processMessage(message);
      
      // Verificar si es un duplicado DESPUÉS de la normalización
      if (_isAlreadyProcessed(normalizedMessage)) {
        logger.d(_tag, "Mensaje entrante duplicado descartado: ${normalizedMessage.content}");
        return;
      }
      
      // Marcar como procesado localmente
      _markAsProcessed(normalizedMessage);
      
      logger.d(_tag, "Mensaje entrante procesado de: ${normalizedMessage.senderName}");
      
      // Analizar mensajes para mejorar relaciones de contactos
      _analyzeContactRelations();
    } catch (e) {
      logger.e(_tag, "Error procesando mensaje entrante", e);
    }
  }
  
  // Lanza un análisis de contactos en segundo plano
  void _analyzeContactRelations() {
    // Usar Timer para ejecutar en segundo plano
    Timer(const Duration(seconds: 1), () {
      final messages = _firebaseService.getMessages();
      contactNormalizer.analyzeMessages(messages);
      
      // Una vez analizados, buscamos mensajes con información actualizada
      _updateNormalizedMessages(messages);
    });
  }
  
  // Actualiza mensajes con información de contactos normalizada
  Future<void> _updateNormalizedMessages(List<WhatsAppMessage> messages) async {
    bool hasChanges = false;
    
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final normalizedMessage = contactNormalizer.processMessage(message);
      
      // Verificar si el mensaje fue modificado
      if (message.direction == MessageDirection.incoming) {
        if (message.senderName != normalizedMessage.senderName) {
          // Actualizar el mensaje con el nombre normalizado
          await _firebaseService.updateMessage(normalizedMessage);
          logger.d(_tag, "Actualizado remitente: ${message.senderName} -> ${normalizedMessage.senderName}");
          hasChanges = true;
        }
      } else {
        if (message.recipientName != normalizedMessage.recipientName) {
          // Actualizar el mensaje con el nombre normalizado
          await _firebaseService.updateMessage(normalizedMessage);
          logger.d(_tag, "Actualizado destinatario: ${message.recipientName} -> ${normalizedMessage.recipientName}");
          hasChanges = true;
        }
      }
    }
    
    // Si hay cambios, lo registramos
    if (hasChanges) {
      logger.d(_tag, "Se realizaron actualizaciones de normalización de contactos");
    }
  }
  
  /// Detenemos suscripciones y liberamos recursos
  void dispose() {
    _accessibilitySubscription?.cancel();
    _notificationSubscription?.cancel();
    _firebaseMessagesSubscription?.cancel();
    _saveProcessedIds();
  }
}

// Instancia global
final messageHandler = MessageHandler();