// lib/services/notes_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whatsapp_interceptor/utils/logger.dart';
import 'package:whatsapp_interceptor/models/note_model.dart';

class NotesService {
  static const String _tag = "NotesService";
  static const String _notesKey = "saved_notes";

  // Obtener todas las notas
  Future<List<NoteModel>> getNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = prefs.getStringList(_notesKey) ?? [];
      
      List<NoteModel> notes = notesJson
        .map((noteStr) => NoteModel.fromMap(jsonDecode(noteStr)))
        .toList();
      
      // Ordenar por fecha de modificación (más reciente primero)
      notes.sort((a, b) => b.dateModified.compareTo(a.dateModified));
      
      logger.d(_tag, "Notas recuperadas: ${notes.length}");
      return notes;
    } catch (e) {
      logger.e(_tag, "Error al obtener notas", e);
      return [];
    }
  }

  // Obtener una nota por su ID
  Future<NoteModel?> getNoteById(int id) async {
    try {
      final notes = await getNotes();
      return notes.firstWhere((note) => note.id == id);
    } catch (e) {
      logger.e(_tag, "Error al obtener nota con ID $id", e);
      return null;
    }
  }

  // Guardar una lista de notas
  Future<void> _saveNotes(List<NoteModel> notes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = notes
        .map((note) => jsonEncode(note.toMap()))
        .toList();
      
      await prefs.setStringList(_notesKey, notesJson);
      logger.d(_tag, "Notas guardadas: ${notes.length}");
    } catch (e) {
      logger.e(_tag, "Error al guardar notas", e);
    }
  }

  // Crear una nueva nota
  Future<NoteModel> createNote(String title, String content) async {
    try {
      final notes = await getNotes();
      
      // Generar un ID único (el mayor ID existente + 1)
      int maxId = notes.isEmpty ? 0 : notes.map((note) => note.id).reduce((max, id) => id > max ? id : max);
      int newId = maxId + 1;
      
      final now = DateTime.now();
      final newNote = NoteModel(
        id: newId,
        title: title,
        content: content,
        dateCreated: now,
        dateModified: now,
      );
      
      notes.add(newNote);
      await _saveNotes(notes);
      
      logger.d(_tag, "Nota creada con ID: $newId");
      return newNote;
    } catch (e) {
      logger.e(_tag, "Error al crear nota", e);
      throw Exception("No se pudo crear la nota");
    }
  }

  // Actualizar una nota existente
  Future<NoteModel> updateNote(int id, String title, String content) async {
    try {
      final notes = await getNotes();
      int index = notes.indexWhere((note) => note.id == id);
      
      if (index == -1) {
        throw Exception("Nota no encontrada");
      }
      
      final updatedNote = notes[index].copyWith(
        title: title,
        content: content,
        dateModified: DateTime.now(),
      );
      
      notes[index] = updatedNote;
      await _saveNotes(notes);
      
      logger.d(_tag, "Nota actualizada con ID: $id");
      return updatedNote;
    } catch (e) {
      logger.e(_tag, "Error al actualizar nota con ID $id", e);
      throw Exception("No se pudo actualizar la nota");
    }
  }

  // Eliminar una nota
  Future<bool> deleteNote(int id) async {
    try {
      final notes = await getNotes();
      final initialLength = notes.length;
      
      notes.removeWhere((note) => note.id == id);
      
      if (notes.length == initialLength) {
        // No se encontró la nota para eliminar
        return false;
      }
      
      await _saveNotes(notes);
      logger.d(_tag, "Nota eliminada con ID: $id");
      return true;
    } catch (e) {
      logger.e(_tag, "Error al eliminar nota con ID $id", e);
      return false;
    }
  }
  
  // Crear notas por defecto si no hay ninguna
  Future<void> createDefaultNotes() async {
    try {
      final notes = await getNotes();
      
      if (notes.isEmpty) {
        await createNote(
          "Bienvenido a Notas", 
          "Esta es tu primera nota. Puedes crear, editar y eliminar notas.\n\n"
          "• Toca una nota para verla o editarla\n"
          "• Usa el botón + para crear una nueva nota\n"
          "• Desliza una nota para eliminarla"
        );
        
        await createNote(
          "Lista de compras", 
          "🛒 Comprar:\n"
          "- Leche\n"
          "- Pan\n"
          "- Huevos\n"
          "- Frutas\n"
          "- Verduras"
        );
        
        logger.d(_tag, "Notas por defecto creadas");
      }
    } catch (e) {
      logger.e(_tag, "Error al crear notas por defecto", e);
    }
  }
}

// Instancia global del servicio
final notesService = NotesService();