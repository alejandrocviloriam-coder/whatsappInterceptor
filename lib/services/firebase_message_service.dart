import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whatsapp_interceptor/models/message.dart';
import 'package:whatsapp_interceptor/utils/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:whatsapp_interceptor/services/auth_service.dart';

/// Servicio para operaciones con Firebase
class FirebaseMessageService {
  static final FirebaseMessageService _instance = FirebaseMessageService._internal();
  factory FirebaseMessageService() => _instance;

  FirebaseMessageService._internal();

  static const String _tag = "FirebaseMessageService";

  // Clave para almacenar el ID del dispositivo en SharedPreferences
  static const String _deviceIdKey = 'device_id';

  // Referencia a Firestore
  late FirebaseFirestore _firestore;

  // ID único para este dispositivo
  String? _deviceId;

  // Código de activación actual
  String? _activationCode;

  // Controlador para notificar cambios en los mensajes
  final _messagesController = StreamController<List<WhatsAppMessage>>.broadcast();
  Stream<List<WhatsAppMessage>> get messagesStream => _messagesController.stream;

  // Caché de mensajes en memoria
  List<WhatsAppMessage> _messages = [];

  // Set para evitar duplicados
  final Set<String> _messageIds = {};

  // Timer para refresco periódico
  Timer? _refreshTimer;

  /// Inicializa el servicio de Firebase
  Future<bool> init() async {
    try {
      // Inicializar Firebase (si no está ya inicializado)
      await Firebase.initializeApp();

      // Obtener instancia de Firestore
      _firestore = FirebaseFirestore.instance;

      // Obtener o generar ID de dispositivo
      await _getOrCreateDeviceId();

      // Obtener código de activación actual
      _activationCode = await authService.getSavedCode();

      // Escuchar cambios en la colección de mensajes
      _setupMessagesListener();

      // Registrar último momento de sincronización
      await _updateSyncStatus();

      // Iniciar refresco periódico automáticamente
      startPeriodicRefresh();

      logger.d(_tag, 'Servicio de Firebase inicializado correctamente. Device ID: $_deviceId, ActivationCode: $_activationCode');
      return true;
    } catch (e) {
      logger.e(_tag, 'Error al inicializar servicio de Firebase', e);
      return false;
    }
  }

  /// Inicia un refresco periódico para actualizaciones más frecuentes
  void startPeriodicRefresh() {
    // Cancelar timer existente si lo hay
    _refreshTimer?.cancel();

    // Crear un nuevo timer que se ejecuta cada 2 segundos
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _manualRefresh();
    });

    logger.d(_tag, 'Refresco periódico iniciado');
  }

  /// Realiza una actualización manual de los mensajes
  Future<void> _manualRefresh() async {
    try {
      _activationCode = await authService.getSavedCode();
      if (_activationCode == null) return;

      final snapshot = await _firestore
          .collection('messages')
          .where('activationCode', isEqualTo: _activationCode)
          .orderBy('timestamp', descending: true)
          .get();

      logger.d(_tag, 'Refresco manual: ${snapshot.docs.length} mensajes obtenidos');
      _processMessagesSnapshot(snapshot);
    } catch (e) {
      logger.e(_tag, 'Error en refresco manual', e);
    }
  }

  /// Libera recursos cuando ya no se necesita el servicio
  void dispose() {
    _refreshTimer?.cancel();
    _messagesController.close();
    logger.d(_tag, 'Servicio de Firebase finalizado');
  }

  /// Obtiene o crea un ID único para este dispositivo
  Future<void> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_deviceIdKey);

    if (_deviceId == null) {
      // Generar nuevo ID
      _deviceId = const Uuid().v4();
      // Guardar para uso futuro
      await prefs.setString(_deviceIdKey, _deviceId!);
    }
  }

  /// Establece un listener para cambios en los mensajes de Firestore
  void _setupMessagesListener() async {
    _activationCode = await authService.getSavedCode();
    if (_activationCode == null) return;

    _firestore
        .collection('messages')
        .where('activationCode', isEqualTo: _activationCode)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _processMessagesSnapshot(snapshot);
    }, onError: (error) {
      logger.e(_tag, 'Error al escuchar cambios en mensajes', error);
    });
  }

  /// Procesa un snapshot de mensajes de Firestore
  void _processMessagesSnapshot(QuerySnapshot snapshot) {
    try {
      final List<WhatsAppMessage> messages = [];
      final Set<String> messageIds = {};

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;

          // Convertir datos de Firestore a WhatsAppMessage
          final message = _convertFirestoreToWhatsAppMessage(doc.id, data);

          // Verificar si es un mensaje nuevo
          final messageId = message.generateUniqueId();
          if (!messageIds.contains(messageId)) {
            messageIds.add(messageId);
            messages.add(message);
          }
        } catch (e) {
          logger.e(_tag, 'Error al procesar documento', e);
        }
      }

      // Ordenar mensajes por timestamp (más reciente primero)
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Actualizar datos en memoria
      _messages = messages;
      _messageIds.addAll(messageIds);

      // Notificar a los oyentes
      _messagesController.add(_messages);

      logger.d(_tag, 'Mensajes cargados desde Firestore: ${_messages.length}');
    } catch (e) {
      logger.e(_tag, 'Error al procesar snapshot de mensajes', e);
    }
  }

  /// Convierte datos de Firestore a un objeto WhatsAppMessage
  WhatsAppMessage _convertFirestoreToWhatsAppMessage(String docId, Map<String, dynamic> data) {
    final String content = data['content'] ?? '';
    int timestamp;
    try {
      if (data['timestamp'] is int) {
        timestamp = data['timestamp'];
      } else if (data['timestamp'] is String) {
        timestamp = int.parse(data['timestamp']);
      } else {
        timestamp = DateTime.now().millisecondsSinceEpoch;
      }
    } catch (e) {
      timestamp = DateTime.now().millisecondsSinceEpoch;
      logger.e(_tag, 'Error al convertir timestamp', e);
    }
    final String recipientName = data['recipientName'] ?? 'Desconocido';
    final String recipientType = data['recipientType'] ?? 'individual';
    final String direction = data['direction'] ?? 'outgoing';
    final bool isRead = data['isRead'] ?? true;
    final String? senderName = data['senderName'];
    final String activationCode = data['activationCode'] ?? '';

    final DateTime messageTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

    return WhatsAppMessage(
      content: content,
      timestamp: messageTime,
      recipientName: recipientName,
      recipientType: recipientType,
      direction: direction == 'incoming' ? MessageDirection.incoming : MessageDirection.outgoing,
      senderName: senderName,
      isRead: isRead,
      activationCode: activationCode,
    );
  }

  /// Actualiza el estado de sincronización en Firestore
  Future<void> _updateSyncStatus() async {
    try {
      if (_deviceId == null) {
        await _getOrCreateDeviceId();
      }

      await _firestore.collection('sync_records').doc(_deviceId).set({
        'deviceId': _deviceId,
        'lastSync': DateTime.now().millisecondsSinceEpoch,
        'status': 'active',
      }, SetOptions(merge: true));

      logger.d(_tag, 'Estado de sincronización actualizado');
    } catch (e) {
      logger.e(_tag, 'Error al actualizar estado de sincronización', e);
    }
  }

  /// Obtiene todos los mensajes almacenados
  List<WhatsAppMessage> getMessages() {
    return List.unmodifiable(_messages);
  }

  /// Elimina un mensaje específico
  Future<bool> deleteMessage(WhatsAppMessage message) async {
    try {
      final String messageId = message.generateUniqueId();

      final querySnapshot = await _firestore.collection('messages')
          .where('content', isEqualTo: message.content)
          .where('timestamp', isEqualTo: message.timestamp.millisecondsSinceEpoch)
          .where('activationCode', isEqualTo: message.activationCode)
          .get();

      if (querySnapshot.docs.isEmpty) {
        logger.w(_tag, 'No se encontró el mensaje para eliminar');
        return false;
      }

      for (final doc in querySnapshot.docs) {
        await _firestore.collection('messages').doc(doc.id).delete();
      }

      _messageIds.remove(messageId);

      logger.d(_tag, 'Mensaje eliminado: ${message.content}');
      return true;
    } catch (e) {
      logger.e(_tag, 'Error al eliminar mensaje', e);
      return false;
    }
  }

  /// Actualiza un mensaje existente con información normalizada
  Future<bool> updateMessage(WhatsAppMessage message) async {
    try {
      final messageId = message.generateUniqueId();

      final querySnapshot = await _firestore.collection('messages')
          .where('content', isEqualTo: message.content)
          .where('timestamp', isEqualTo: message.timestamp.millisecondsSinceEpoch)
          .where('activationCode', isEqualTo: message.activationCode)
          .get();

      if (querySnapshot.docs.isEmpty) {
        logger.w(_tag, 'No se encontró el mensaje para actualizar');
        return false;
      }

      for (final doc in querySnapshot.docs) {
        final Map<String, dynamic> updateData = {};

        if (message.direction == MessageDirection.incoming) {
          updateData['senderName'] = message.senderName;
        } else {
          updateData['recipientName'] = message.recipientName;
        }

        await _firestore.collection('messages').doc(doc.id).update(updateData);
      }

      final index = _messages.indexWhere((msg) => msg.generateUniqueId() == messageId);
      if (index >= 0) {
        _messages[index] = message;
        _messagesController.add(_messages);
      }

      logger.d(_tag, 'Mensaje actualizado: ${message.content}');
      return true;
    } catch (e) {
      logger.e(_tag, 'Error al actualizar mensaje', e);
      return false;
    }
  }

  /// Marca un mensaje como leído
  Future<bool> markMessageAsRead(WhatsAppMessage message) async {
    try {
      final querySnapshot = await _firestore.collection('messages')
          .where('content', isEqualTo: message.content)
          .where('timestamp', isEqualTo: message.timestamp.millisecondsSinceEpoch)
          .where('activationCode', isEqualTo: message.activationCode)
          .get();

      if (querySnapshot.docs.isEmpty) {
        logger.w(_tag, 'No se encontró el mensaje para marcar como leído');
        return false;
      }

      for (final doc in querySnapshot.docs) {
        await _firestore.collection('messages').doc(doc.id).update({
          'isRead': true
        });
      }

      logger.d(_tag, 'Mensaje marcado como leído: ${message.content}');
      return true;
    } catch (e) {
      logger.e(_tag, 'Error al marcar mensaje como leído', e);
      return false;
    }
  }

  /// Marca todos los mensajes de un contacto como leídos
  Future<void> markContactMessagesAsRead(String contactName) async {
    try {
      final contactMessages = _messages.where((msg) {
        if (msg.direction == MessageDirection.incoming) {
          final sender = msg.senderName ?? 'Desconocido';
          return sender == contactName && !msg.isRead;
        }
        return false;
      }).toList();

      for (final message in contactMessages) {
        await markMessageAsRead(message);
      }

      logger.d(_tag, 'Marcados ${contactMessages.length} mensajes como leídos para $contactName');
    } catch (e) {
      logger.e(_tag, 'Error al marcar mensajes como leídos', e);
    }
  }

  /// Elimina todos los mensajes
  Future<void> clearAllMessages() async {
    try {
      if (_activationCode == null) return;
      final snapshot = await _firestore.collection('messages')
          .where('activationCode', isEqualTo: _activationCode)
          .get();

      for (final doc in snapshot.docs) {
        await _firestore.collection('messages').doc(doc.id).delete();
      }

      _messageIds.clear();

      logger.d(_tag, 'Todos los mensajes eliminados');
    } catch (e) {
      logger.e(_tag, 'Error al eliminar todos los mensajes', e);
    }
  }

  /// Elimina los mensajes de un contacto específico
  Future<void> clearContactMessages(String contactName) async {
    try {
      if (_activationCode == null) return;
      final snapshot = await _firestore.collection('messages')
          .where('recipientName', isEqualTo: contactName)
          .where('activationCode', isEqualTo: _activationCode)
          .get();

      final snapshot2 = await _firestore.collection('messages')
          .where('senderName', isEqualTo: contactName)
          .where('activationCode', isEqualTo: _activationCode)
          .get();

      for (final doc in snapshot.docs) {
        await _firestore.collection('messages').doc(doc.id).delete();
      }

      for (final doc in snapshot2.docs) {
        await _firestore.collection('messages').doc(doc.id).delete();
      }

      logger.d(_tag, 'Mensajes eliminados para el contacto: $contactName');
    } catch (e) {
      logger.e(_tag, 'Error al eliminar mensajes del contacto', e);
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
    return _messages.where((msg) {
      if (msg.direction == MessageDirection.outgoing) {
        return msg.recipientName == contactName;
      } else {
        final sender = msg.senderName ?? 'Desconocido';
        return sender == contactName;
      }
    }).toList();
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
  DateTime? getLatestMessageTimestamp() {
    if (_messages.isEmpty) return null;
    return _messages.first.timestamp;
  }

  /// Obtiene estadísticas de mensajes
  Map<String, int> getMessageStats() {
    final stats = <String, int>{
      'total': _messages.length,
      'incoming': 0,
      'outgoing': 0,
      'today': countMessagesToday(),
    };

    for (final message in _messages) {
      if (message.direction == MessageDirection.incoming) {
        stats['incoming'] = (stats['incoming'] ?? 0) + 1;
      } else {
        stats['outgoing'] = (stats['outgoing'] ?? 0) + 1;
      }
    }

    return stats;
  }
}

// Instancia global
final firebaseMessageService = FirebaseMessageService();