// lib/screens/notes_app_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:whatsapp_interceptor/services/app_visibility_service.dart';
import 'package:whatsapp_interceptor/services/notes_service.dart';
import 'package:whatsapp_interceptor/models/note_model.dart';
import 'package:whatsapp_interceptor/screens/note_editor_screen.dart';
import 'package:whatsapp_interceptor/utils/logger.dart';
import 'package:whatsapp_interceptor/screens/home_screen.dart'; // Nueva importación

class NotesAppScreen extends StatefulWidget {
  const NotesAppScreen({Key? key}) : super(key: key);

  @override
  State<NotesAppScreen> createState() => _NotesAppScreenState();
}

class _NotesAppScreenState extends State<NotesAppScreen> {
  static const String _tag = "NotesAppScreen";
  List<NoteModel> _notes = [];
  bool _isLoading = true;
  int _clickCounter = 0;
  int? _activeNoteForClicking;
  
  // Timer para reiniciar el contador de clics
  Timer? _clickResetTimer;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _clickResetTimer?.cancel();
    super.dispose();
  }

  // Cargar las notas desde el servicio
  Future<void> _loadNotes() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      await notesService.createDefaultNotes(); // Asegurar que hay notas predeterminadas
      final notes = await notesService.getNotes();
      
      if (mounted) {
        setState(() {
          _notes = notes;
          _isLoading = false;
        });
      }
    } catch (e) {
      logger.e(_tag, "Error al cargar notas", e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al cargar las notas'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Manejar clic en título para contar
  void _handleTitleClick(int noteId) {
    // Si cambiamos de nota, reiniciar contador
    if (_activeNoteForClicking != noteId) {
      _clickCounter = 0;
      _activeNoteForClicking = noteId;
    }
    
    // Cancelar timer anterior si existe
    _clickResetTimer?.cancel();
    
    // Incrementar contador
    setState(() {
      _clickCounter++;
    });
    
    // Si llegamos a 10 clics, activar modo original
    if (_clickCounter >= 10) {
      _activateOriginalApp();
      _clickCounter = 0;
    }
    
    // Reiniciar contador después de 3 segundos de inactividad
    _clickResetTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _clickCounter = 0;
        });
      }
    });
  }
  
  // Activar la app original
  void _activateOriginalApp() async {
    try {
      await appVisibilityService.setInvisible(false);
      
      // Verificar si el widget aún está montado antes de usar el context
      if (mounted) {
        // Usar pushReplacement en lugar de pushReplacementNamed
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        
        logger.d(_tag, "Modo original activado");
      }
    } catch (e) {
      logger.e(_tag, "Error al activar modo original", e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Notas'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? _buildEmptyState()
              : _buildNotesList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (!mounted) return;
          
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NoteEditorScreen(),
            ),
          );
          
          if (result == true && mounted) {
            _loadNotes();
          }
        },
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  // Construir la lista de notas
  Widget _buildNotesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        return _buildNoteCard(note);
      },
    );
  }
  
  // Construir tarjeta para una nota
  Widget _buildNoteCard(NoteModel note) {
    // Formatear fecha
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(note.dateModified);
    
    return Dismissible(
      key: Key('note_${note.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        if (!mounted) return false;
        
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: const Text('¿Estás seguro de que quieres eliminar esta nota?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
        
        // Verificar nuevamente si el widget todavía está montado
        if (!mounted) return false;
        
        return result ?? false;
      },
      onDismissed: (direction) async {
        try {
          await notesService.deleteNote(note.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Nota eliminada'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          logger.e(_tag, "Error al eliminar nota", e);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error al eliminar la nota'),
                backgroundColor: Colors.red,
              ),
            );
            _loadNotes(); // Recargar para mostrar la nota que no se pudo eliminar
          }
        }
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          onTap: () async {
            if (!mounted) return;
            
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NoteEditorScreen(noteId: note.id),
              ),
            );
            
            if (result == true && mounted) {
              _loadNotes();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _handleTitleClick(note.id),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          note.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_activeNoteForClicking == note.id && _clickCounter > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_clickCounter/10',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  note.content,
                  style: TextStyle(color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Estado vacío cuando no hay notas
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_alt_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay notas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca el botón + para crear una nueva nota',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}