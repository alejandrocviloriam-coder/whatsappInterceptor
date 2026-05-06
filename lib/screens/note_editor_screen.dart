// lib/screens/note_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:whatsapp_interceptor/services/notes_service.dart';
import 'package:whatsapp_interceptor/utils/logger.dart';

class NoteEditorScreen extends StatefulWidget {
  final int? noteId;
  
  const NoteEditorScreen({Key? key, this.noteId}) : super(key: key);

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  static const String _tag = "NoteEditorScreen";
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isEditing = false;
  
  @override
  void initState() {
    super.initState();
    _isEditing = widget.noteId != null;
    
    if (_isEditing) {
      _loadNote();
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
  
  // Cargar nota existente
  Future<void> _loadNote() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final note = await notesService.getNoteById(widget.noteId!);
      
      if (note != null && mounted) {
        setState(() {
          _titleController.text = note.title;
          _contentController.text = note.content;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nota no encontrada'),
              backgroundColor: Colors.red,
            ),
          );
          
          Navigator.pop(context);
        }
      }
    } catch (e) {
      logger.e(_tag, "Error al cargar nota", e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al cargar la nota'),
            backgroundColor: Colors.red,
          ),
        );
        
        Navigator.pop(context);
      }
    }
  }
  
  // Guardar nota (crear o actualizar)
  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      final title = _titleController.text;
      final content = _contentController.text;
      
      if (_isEditing) {
        // Actualizar nota existente
        await notesService.updateNote(widget.noteId!, title, content);
      } else {
        // Crear nueva nota
        await notesService.createNote(title, content);
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Nota actualizada' : 'Nota creada'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context, true);
      }
    } catch (e) {
      logger.e(_tag, "Error al guardar nota", e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar la nota'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Nota' : 'Nueva Nota'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveNote,
            tooltip: 'Guardar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, introduce un título';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _contentController,
                        decoration: const InputDecoration(
                          labelText: 'Contenido',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}