// lib/services/message_storage_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whatsapp_interceptor/models/message.dart';

/// Servicio para almacenar y recuperar mensajes interceptados
class MessageStorageService {
  static final MessageStorageService _instance = MessageStorageService._internal();
  factory MessageStorageService() => _instance;
  
  MessageStorageService._internal();
  
  // Clave para almacenar mensajes en SharedPreferences
  static const String _messagesKey = 'intercepted_messages';
  static const String _contactIdentifiersKey = 'contact_identifiers';
  
  // Referencia a SharedPreferences
  late SharedPreferences _prefs;
  
  // Controlador para notificar cambios en los mensajes
  final _messagesController = StreamController<List<WhatsAppMessage>>.broadcast();
  Stream<List<WhatsAppMessage>> get messagesStream => _messagesController.stream;
  
  // Caché de mensajes en memoria
  List<WhatsAppMessage> _messages = [];
  
  // Set para evitar duplicados
  Set<String> _messageIds = {};
  
  // Mapa para mantener la relación entre diferentes identificadores de contacto
  // Clave: identificador (senderName o recipientName), Valor: identificador normalizado
  Map<String, String> _contactIdentifiers = {};
  
  /// Inicializa el servicio de almacenamiento
  Future<void> init() async {
    try {
      // Obtener instancia de SharedPreferences
      _prefs = await SharedPreferences.getInstance();
      
      // Cargar mensajes almacenados
      await _loadMessages();
      
      // Cargar identificadores de contacto
      await _loadContactIdentifiers();
      
      // Inicializar set de IDs de mensajes para prevenir duplicados
      _refreshMessageIdsSet();
      
      _logDebug('Servicio de almacenamiento inicializado con ${_messages.length} mensajes');
    } catch (e) {
      _logDebug('Error al inicializar servicio de almacenamiento: $e');
      rethrow;
    }
  }
  
  // Actualiza el set de IDs de mensajes para detectar duplicados
  void _refreshMessageIdsSet() {
    _messageIds = _messages.map((msg) => 
      '${msg.content}_${msg.timestamp.millisecondsSinceEpoch}_${msg.direction.toString()}'
    ).toSet();
  }
  
  // Verifica si un mensaje es duplicado
  bool _isDuplicate(WhatsAppMessage message) {
    final messageId = '${message.content}_${message.timestamp.millisecondsSinceEpoch}_${message.direction.toString()}';
    return _messageIds.contains(messageId);
  }
  
  /// Carga los mensajes almacenados desde SharedPreferences
  Future<void> _loadMessages() async {
    try {
      final String? messagesJson = _prefs.getString(_messagesKey);
      
      if (messagesJson != null && messagesJson.isNotEmpty) {
        // Decodificar JSON a lista de mapas
        final List<dynamic> messagesList = jsonDecode(messagesJson);
        
        // Convertir cada mapa a objeto WhatsAppMessage
        _messages = messagesList
            .map((data) => WhatsAppMessage.fromJson(data))
            .toList();
        
        // Ordenar mensajes por timestamp (más reciente primero)
        _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        // Eliminar posibles duplicados
        final uniqueMessages = <WhatsAppMessage>[];
        final uniqueIds = <String>{};
        
        for (final message in _messages) {
          final messageId = '${message.content}_${message.timestamp.millisecondsSinceEpoch}_${message.direction.toString()}';
          if (!uniqueIds.contains(messageId)) {
            uniqueIds.add(messageId);
            uniqueMessages.add(message);
          }
        }
        
        _messages = uniqueMessages;
        
        // Notificar a los oyentes
        _messagesController.add(_messages);
        
        _logDebug('Mensajes cargados: ${_messages.length}');
      } else {
        _messages = [];
        _messagesController.add(_messages);
        _logDebug('No hay mensajes almacenados');
      }
    } catch (e) {
      _logDebug('Error al cargar mensajes: $e');
      _messages = [];
      _messagesController.add(_messages);
    }
  }
  
  /// Carga los identificadores de contacto desde SharedPreferences
  Future<void> _loadContactIdentifiers() async {
    try {
      final String? identifiersJson = _prefs.getString(_contactIdentifiersKey);
      
      if (identifiersJson != null && identifiersJson.isNotEmpty) {
        // Decodificar JSON a mapa
        final Map<String, dynamic> identifiersMap = jsonDecode(identifiersJson);
        
        // Convertir a Map<String, String>
        _contactIdentifiers = identifiersMap.map((key, value) => 
          MapEntry(key, value.toString()));
        
        _logDebug('Identificadores de contacto cargados: ${_contactIdentifiers.length}');
      } else {
        _contactIdentifiers = {};
        _logDebug('No hay identificadores de contacto almacenados');
      }
    } catch (e) {
      _logDebug('Error al cargar identificadores de contacto: $e');
      _contactIdentifiers = {};
    }
  }
  
  /// Guarda los mensajes en SharedPreferences
  Future<void> _saveMessages() async {
    try {
      // Convertir mensajes a JSON
      final List<Map<String, dynamic>> messagesList = _messages
          .map((message) => message.toJson())
          .toList();
      
      // Codificar a string JSON
      final String messagesJson = jsonEncode(messagesList);
      
      // Guardar en SharedPreferences
      await _prefs.setString(_messagesKey, messagesJson);
      
      // Actualizar set de IDs de mensajes
      _refreshMessageIdsSet();
      
      _logDebug('Mensajes guardados: ${_messages.length}');
    } catch (e) {
      _logDebug('Error al guardar mensajes: $e');
      rethrow;
    }
  }
  
  /// Guarda los identificadores de contacto en SharedPreferences
  Future<void> _saveContactIdentifiers() async {
    try {
      // Codificar a string JSON
      final String identifiersJson = jsonEncode(_contactIdentifiers);
      
      // Guardar en SharedPreferences
      await _prefs.setString(_contactIdentifiersKey, identifiersJson);
      
      _logDebug('Identificadores de contacto guardados: ${_contactIdentifiers.length}');
    } catch (e) {
      _logDebug('Error al guardar identificadores de contacto: $e');
      rethrow;
    }
  }
  
  /// Unifica identificadores de contactos similares
  void _normalizeContactIdentifiers() {
    // Primero construir un mapa de nombres normalizados (lowercase) a nombres originales
    final Map<String, String> normalizedMap = {};
    
    // Recolectar todos los nombres de contactos de los mensajes
    for (final message in _messages) {
      if (message.direction == MessageDirection.outgoing) {
        final name = message.recipientName;
        normalizedMap[name.toLowerCase()] = name;
      } else {
        final name = message.senderName ?? 'Desconocido';
        normalizedMap[name.toLowerCase()] = name;
      }
    }
    
    // Identificar nombres similares y unificarlos
    final Map<String, String> similarNames = {};
    
    // Asignar un identificador preferido para cada grupo de nombres similares
    for (final entry1 in normalizedMap.entries) {
      for (final entry2 in normalizedMap.entries) {
        if (entry1.key != entry2.key) {
          // Verificar si hay una coincidencia parcial significativa
          if (entry1.key.contains(entry2.key) || entry2.key.contains(entry1.key)) {
            // Preferir el nombre más largo como el principal
            if (entry1.value.length >= entry2.value.length) {
              similarNames[entry2.value] = entry1.value;
            } else {
              similarNames[entry1.value] = entry2.value;
            }
          }
        }
      }
    }
    
    // Actualizar _contactIdentifiers con estas relaciones
    _contactIdentifiers.addAll(similarNames);
  }
  
  /// Encuentra o crea un identificador único para un contacto
  String getContactIdentifier(WhatsAppMessage message) {
    String contactKey;
    
    if (message.direction == MessageDirection.incoming) {
      // Para mensajes entrantes, el identificador es el remitente
      contactKey = message.senderName ?? 'Desconocido';
    } else {
      // Para mensajes salientes, el identificador es el destinatario
      contactKey = message.recipientName;
    }
    
    // Verificar si ya tenemos un identificador para este contacto
    if (_contactIdentifiers.containsKey(contactKey)) {
      return _contactIdentifiers[contactKey]!;
    }
    
    // Buscar si existe otro nombre (número de teléfono, etc.) para este contacto
    // Esto es importante para vincular números con nombres o diferentes formatos del mismo número
    for (final msg in _messages) {
      // Verificar si hay mensajes entrantes de este contacto
      if (msg.direction == MessageDirection.incoming) {
        final sender = msg.senderName ?? 'Desconocido';
        if (sender.toLowerCase().contains(contactKey.toLowerCase()) || 
            contactKey.toLowerCase().contains(sender.toLowerCase())) {
          _contactIdentifiers[contactKey] = sender;
          return sender;
        }
      }
      
      // Verificar si hay mensajes salientes a este contacto
      if (msg.direction == MessageDirection.outgoing) {
        if (msg.recipientName.toLowerCase().contains(contactKey.toLowerCase()) || 
            contactKey.toLowerCase().contains(msg.recipientName.toLowerCase())) {
          _contactIdentifiers[contactKey] = msg.recipientName;
          return msg.recipientName;
        }
      }
    }
    
    // Si no encontramos un identificador existente, usar el actual
    _contactIdentifiers[contactKey] = contactKey;
    return contactKey;
  }
  
  /// Obtiene todos los mensajes almacenados
  List<WhatsAppMessage> getMessages() {
    return List.unmodifiable(_messages);
  }
  
  /// Añade un nuevo mensaje
  Future<void> addMessage(WhatsAppMessage message) async {
    try {
      // Verificar si es un duplicado
      if (_isDuplicate(message)) {
        _logDebug('Mensaje duplicado ignorado: ${message.content}');
        return;
      }
      
      // Antes de añadir, normalizar contactos
      _normalizeContactIdentifiers();
      
      // Obtener identificador único para este contacto
      final contactIdentifier = getContactIdentifier(message);
      
      // Crear una copia del mensaje con información consistente de contacto
      WhatsAppMessage normalizedMessage;
      
      if (message.direction == MessageDirection.incoming) {
        normalizedMessage = message.copyWith(
          senderName: contactIdentifier
        );
      } else {
        normalizedMessage = message.copyWith(
          recipientName: contactIdentifier
        );
      }
      
      // Añadir el mensaje normalizado
      _messages.insert(0, normalizedMessage);
      
      // Actualizar set de IDs para evitar duplicados
      _messageIds.add('${normalizedMessage.content}_${normalizedMessage.timestamp.millisecondsSinceEpoch}_${normalizedMessage.direction.toString()}');
      
      // Guardar mensajes actualizados
      await _saveMessages();
      
      // Guardar identificadores de contacto
      await _saveContactIdentifiers();
      
      // Notificar a los oyentes
      _messagesController.add(_messages);
    } catch (e) {
      _logDebug('Error al añadir mensaje: $e');
      rethrow;
    }
  }
  
  /// Devuelve todos los contactos únicos
  List<String> getUniqueContacts() {
    final contactSet = <String>{};
    
    for (final message in _messages) {
      if (message.direction == MessageDirection.outgoing) {
        contactSet.add(message.recipientName);
      } else {
        final sender = message.senderName ?? 'Desconocido';
        contactSet.add(sender);
      }
    }
    
    return contactSet.toList();
  }
  
  /// Devuelve mensajes filtrados por contacto
  List<WhatsAppMessage> getMessagesByContact(String contactName) {
    // Buscar mensajes basados en el contacto normalizado
    final normalizedContactName = _contactIdentifiers[contactName] ?? contactName;
    
    return _messages.where((msg) {
      if (msg.direction == MessageDirection.outgoing) {
        return msg.recipientName == normalizedContactName || 
               msg.recipientName == contactName;
      } else {
        final sender = msg.senderName ?? 'Desconocido';
        return sender == normalizedContactName || 
               sender == contactName;
      }
    }).toList();
  }
  
  /// Marca todos los mensajes de un contacto como leídos
  Future<void> markContactMessagesAsRead(String contactName) async {
    bool hasChanges = false;
    
    for (int i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      
      if (!msg.isRead && 
          msg.direction == MessageDirection.incoming && 
          (msg.senderName ?? 'Desconocido') == contactName) {
        
        // Reemplazar mensaje con su versión leída
        _messages[i] = msg.copyWith(isRead: true);
        hasChanges = true;
      }
    }
    
    if (hasChanges) {
      // Guardar cambios
      await _saveMessages();
      
      // Notificar cambios
      _messagesController.add(_messages);
    }
  }
  
  /// Elimina un mensaje específico por su contenido y timestamp
  Future<bool> deleteMessage(WhatsAppMessage message) async {
    try {
      final messageId = '${message.content}_${message.timestamp.millisecondsSinceEpoch}_${message.direction.toString()}';
      
      final originalLength = _messages.length;
      _messages.removeWhere((msg) {
        final currentId = '${msg.content}_${msg.timestamp.millisecondsSinceEpoch}_${msg.direction.toString()}';
        return currentId == messageId;
      });
      
      if (_messages.length < originalLength) {
        // Guardar cambios
        await _saveMessages();
        
        // Notificar cambios
        _messagesController.add(_messages);
        
        return true;
      }
      
      return false;
    } catch (e) {
      _logDebug('Error al eliminar mensaje: $e');
      return false;
    }
  }
  
  /// Elimina todos los mensajes
  Future<void> clearAllMessages() async {
    _messages.clear();
    _messageIds.clear();
    await _saveMessages();
    _messagesController.add(_messages);
  }
  
  /// Elimina los mensajes de un contacto específico
  Future<void> clearContactMessages(String contactName) async {
    // Buscar mensajes basados en el contacto normalizado
    final normalizedContactName = _contactIdentifiers[contactName] ?? contactName;
    
    _messages.removeWhere((msg) {
      if (msg.direction == MessageDirection.outgoing) {
        return msg.recipientName == normalizedContactName || 
               msg.recipientName == contactName;
      } else {
        final sender = msg.senderName ?? 'Desconocido';
        return sender == normalizedContactName || 
               sender == contactName;
      }
    });
    
    // Actualizar set de IDs
    _refreshMessageIdsSet();
    
    await _saveMessages();
    _messagesController.add(_messages);
  }
  
  /// Cuenta el número de mensajes interceptados hoy
  int countMessagesToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    
    return _messages.where((msg) => 
      msg.timestamp.isAfter(today) && 
      msg.timestamp.isBefore(tomorrow)
    ).length;
  }
  
  /// Obtiene la fecha del mensaje más reciente
  DateTime? getLatestMessageTime() {
    if (_messages.isEmpty) {
      return null;
    }
    
    // Los mensajes ya están ordenados por fecha (más reciente primero)
    return _messages.first.timestamp;
  }
  
  /// Función auxiliar para loguear mensajes de depuración
  void _logDebug(String message) {
    if (kDebugMode) {
      print('[MessageStorageService] $message');
    }
  }
}

// Instancia global única del servicio
final messageStorageService = MessageStorageService();