// lib/screens/contacts_screen.dart
import 'package:flutter/material.dart';
import 'package:whatsapp_interceptor/models/message.dart';
import 'package:whatsapp_interceptor/screens/messages_screen.dart';
import 'package:whatsapp_interceptor/services/firebase_message_service.dart';
import 'package:whatsapp_interceptor/utils/logger.dart';
import 'package:whatsapp_interceptor/widgets/empty_placeholder.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  static const String _tag = "ContactsScreen";
  
  final TextEditingController _searchController = TextEditingController();
  List<String> _contacts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Map<String, int> _unreadCounts = {};
  
  @override
  void initState() {
    super.initState();
    
    // Verificar que el servicio de Firebase esté inicializado
    FirebaseMessageService().init().then((success) {
      logger.d(_tag, "Firebase inicializado: $success");
      if (success) {
        // Cargar contactos iniciales después de inicializar Firebase
        _loadContacts();
      }
    });
    
    // Agregar listener para búsqueda
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
    
    // Escuchar cambios en los mensajes
    FirebaseMessageService().messagesStream.listen((messages) {
      if (mounted) {
        _loadContacts();
      }
    });
  }
  
  void _loadContacts() {
    logger.d(_tag, "Cargando contactos desde Firebase...");
    
    // Establecer estado de carga
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Obtener todos los mensajes
      final messages = FirebaseMessageService().getMessages();
      logger.d(_tag, "Mensajes cargados desde Firebase: ${messages.length}");
      
      // Usar un mapa para normalizar contactos
      // La clave es el nombre original, el valor es el nombre normalizado
      final Map<String, String> normalizedContacts = {};
      final contactSet = <String>{};
      final unreadCounts = <String, int>{};
      
      // Primero, procesar los mensajes salientes para establecer los nombres oficiales
      for (final message in messages) {
        if (message.direction == MessageDirection.outgoing) {
          final contactName = message.recipientName;
          normalizedContacts[contactName.toLowerCase()] = contactName;
          contactSet.add(contactName);
        }
      }
      
      // Luego, procesar los mensajes entrantes
      for (final message in messages) {
        if (message.direction == MessageDirection.incoming) {
          // CAMBIO AQUÍ: Usar recipientName como respaldo cuando senderName es null
          final sender = message.senderName ?? message.recipientName;
          
          // Intentar encontrar un nombre normalizado existente
          final lowerSender = sender.toLowerCase();
          String normalizedName = sender;
          
          if (normalizedContacts.containsKey(lowerSender)) {
            // Usar el nombre normalizado existente
            normalizedName = normalizedContacts[lowerSender]!;
          } else {
            // Si no existe, agregar este como el normalizado
            normalizedContacts[lowerSender] = sender;
          }
          
          contactSet.add(normalizedName);
          
          // Contar mensajes no leídos
          if (!message.isRead) {
            unreadCounts[normalizedName] = (unreadCounts[normalizedName] ?? 0) + 1;
          }
        }
      }
      
      logger.d(_tag, "Contactos cargados: ${contactSet.length}");
      
      // Actualizar el estado
      setState(() {
        _contacts = contactSet.toList()..sort();
        _unreadCounts = unreadCounts;
        _isLoading = false;
      });
    } catch (e) {
      logger.e(_tag, "Error al cargar contactos", e);
      // Manejar errores
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // Filtrar contactos por búsqueda
  List<String> _getFilteredContacts() {
    if (_searchQuery.isEmpty) {
      return _contacts;
    }
    
    final query = _searchQuery.toLowerCase();
    return _contacts.where((contact) => 
      contact.toLowerCase().contains(query)
    ).toList();
  }
  
  // Confirmación y eliminación de un contacto y sus mensajes
  Future<void> _deleteContact(String contactName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar contacto'),
        content: Text('¿Estás seguro de que deseas eliminar a "$contactName" y todos sus mensajes? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eliminando mensajes...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      try {
        // Eliminar mensajes del contacto
        await FirebaseMessageService().clearContactMessages(contactName);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$contactName eliminado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        logger.e(_tag, "Error al eliminar contacto", e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar contacto: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  // Confirmación y eliminación de todos los contactos
  Future<void> _confirmDeleteAllContacts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar todos los contactos'),
        content: const Text('¿Estás seguro de que deseas borrar TODOS los contactos y mensajes? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar todo', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eliminando todos los mensajes...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      try {
        // Eliminar todos los mensajes
        await FirebaseMessageService().clearAllMessages();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Todos los contactos y mensajes eliminados correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        logger.e(_tag, "Error al eliminar todos los contactos", e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar contactos: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final filteredContacts = _getFilteredContacts();
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Contactos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Botón para borrar todos los contactos
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _contacts.isEmpty ? null : _confirmDeleteAllContacts,
            tooltip: 'Borrar todos los contactos',
          ),
          // Botón de recarga
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContacts,
            tooltip: 'Recargar contactos',
          ),
        ],
      ),
      body: PopScope(
        canPop: true,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (!didPop) {
            Navigator.of(context).pop();
          }
        },
        child: Column(
          children: [
            // Barra de búsqueda
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar contactos...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                ),
              ),
            ),
            
            // Lista de contactos
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : filteredContacts.isEmpty
                  ? const EmptyPlaceholder(
                      icon: Icons.person,
                      title: 'No hay contactos',
                      subtitle: 'Los contactos aparecerán aquí cuando haya mensajes',
                    )
                  : ListView.builder(
                      itemCount: filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = filteredContacts[index];
                        final unreadCount = _unreadCounts[contact] ?? 0;
                        
                        return Dismissible(
                          key: Key('contact_$contact'),
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20.0),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Eliminar contacto'),
                                content: Text('¿Estás seguro de que deseas eliminar a "$contact" y todos sus mensajes?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (direction) {
                            FirebaseMessageService().clearContactMessages(contact);
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$contact eliminado'),
                                action: SnackBarAction(
                                  label: 'Deshacer',
                                  onPressed: () {
                                    // No podemos realmente deshacer esto, pero recargamos para actualizarlo
                                    _loadContacts();
                                  },
                                ),
                              ),
                            );
                          },
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal,
                              child: Text(
                                contact.isNotEmpty 
                                    ? contact[0].toUpperCase() 
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              contact,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'Desliza para eliminar',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Indicador de mensajes no leídos
                                if (unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      unreadCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey,
                                  size: 16,
                                ),
                              ],
                            ),
                            onTap: () {
                              // Navegar a la pantalla de mensajes filtrada por este contacto
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => MessagesScreen(
                                    contactId: '',  // Deja vacío si no tienes ID
                                    contactName: contact,  // El nombre del contacto
                                  ),
                                ),
                              );
                            },
                            onLongPress: () {
                              _deleteContact(contact);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}