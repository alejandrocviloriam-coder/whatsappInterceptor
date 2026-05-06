import 'package:intl/intl.dart';

/// Enum to represent the direction of a message
enum MessageDirection {
  /// Message was received from someone
  incoming,

  /// Message was sent to someone
  outgoing
}

/// Model class for WhatsApp messages
class WhatsAppMessage {
  /// The content/body of the message
  final String content;

  /// Name of the recipient
  final String recipientName;

  /// Type of the recipient (individual or group)
  final String recipientType;

  /// Name of the sender (usually present for incoming messages)
  final String? senderName;

  /// Direction of the message (incoming or outgoing)
  final MessageDirection direction;

  /// Timestamp when the message was sent or received
  final DateTime timestamp;

  /// Whether the message has been read
  final bool isRead;

  /// Código de acceso para sincronización entre dispositivos
  final String activationCode;

  /// Creates a new WhatsApp message instance
  const WhatsAppMessage({
    required this.content,
    required this.recipientName,
    required this.recipientType,
    this.senderName,
    required this.direction,
    required this.timestamp,
    this.isRead = false,
    required this.activationCode,
  });

  /// Creates a WhatsApp message from a JSON map
  factory WhatsAppMessage.fromJson(Map<String, dynamic> json) {
    return WhatsAppMessage(
      content: json['content'] as String,
      recipientName: json['recipientName'] as String,
      recipientType: json['recipientType'] as String? ?? 'individual',
      senderName: json['senderName'] as String?,
      direction: json['direction'] == 'incoming'
          ? MessageDirection.incoming
          : MessageDirection.outgoing,
      timestamp: json['timestamp'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      activationCode: json['activationCode'] as String? ?? '',
    );
  }

  /// Converts the message to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'recipientName': recipientName,
      'recipientType': recipientType,
      'senderName': senderName,
      'direction': direction == MessageDirection.incoming ? 'incoming' : 'outgoing',
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
      'activationCode': activationCode,
    };
  }

  /// Returns a formatted date string for the message timestamp
  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (today.isAtSameMomentAs(messageDate)) {
      return DateFormat.Hm().format(timestamp); // Today: just the time (HH:mm)
    } else if (yesterday.isAtSameMomentAs(messageDate)) {
      return 'Ayer ${DateFormat.Hm().format(timestamp)}'; // Yesterday: "Yesterday HH:mm"
    } else if (now.difference(timestamp).inDays < 7) {
      // Within the last week: day name and time
      return '${DateFormat.E().format(timestamp)} ${DateFormat.Hm().format(timestamp)}';
    } else {
      // Older: full date (dd/MM/yyyy HH:mm)
      return DateFormat('dd/MM/yyyy HH:mm').format(timestamp);
    }
  }

  /// Creates a copy of this message with the given fields replaced
  WhatsAppMessage copyWith({
    String? content,
    String? recipientName,
    String? recipientType,
    String? senderName,
    MessageDirection? direction,
    DateTime? timestamp,
    bool? isRead,
    String? activationCode,
  }) {
    return WhatsAppMessage(
      content: content ?? this.content,
      recipientName: recipientName ?? this.recipientName,
      recipientType: recipientType ?? this.recipientType,
      senderName: senderName ?? this.senderName,
      direction: direction ?? this.direction,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      activationCode: activationCode ?? this.activationCode,
    );
  }

  /// Devuelve el nombre/identificador del contacto de este mensaje
  String get contactName {
    return direction == MessageDirection.incoming
        ? (senderName ?? recipientName)
        : recipientName;
  }

  /// Devuelve true si este mensaje pertenece al contacto especificado
  bool isFromContact(String contact) {
    if (direction == MessageDirection.incoming) {
      final sender = senderName ?? recipientName;
      return sender == contact;
    } else {
      return recipientName == contact;
    }
  }

  /// Verifica si este mensaje es un duplicado del otro
  bool isDuplicate(WhatsAppMessage other) {
    return content == other.content &&
        (timestamp.difference(other.timestamp).inSeconds.abs() < 10) &&
        direction == other.direction &&
        activationCode == other.activationCode;
  }

  /// Genera un ID único para este mensaje
  String generateUniqueId() {
    return '$content|${timestamp.millisecondsSinceEpoch}|$direction|${contactName.toLowerCase()}|$activationCode';
  }
}