// lib/models/note_model.dart
class NoteModel {
  final int id;
  final String title;
  final String content;
  final DateTime dateCreated;
  final DateTime dateModified;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.dateCreated,
    required this.dateModified,
  });

  // Crear desde un mapa (JSON)
  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] as int,
      title: map['title'] as String,
      content: map['content'] as String,
      dateCreated: DateTime.parse(map['dateCreated'] as String),
      dateModified: DateTime.parse(map['dateModified'] as String),
    );
  }

  // Convertir a mapa (para JSON)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'dateCreated': dateCreated.toIso8601String(),
      'dateModified': dateModified.toIso8601String(),
    };
  }

  // Crear copia con cambios
  NoteModel copyWith({
    int? id,
    String? title,
    String? content,
    DateTime? dateCreated,
    DateTime? dateModified,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      dateCreated: dateCreated ?? this.dateCreated,
      dateModified: dateModified ?? this.dateModified,
    );
  }
}