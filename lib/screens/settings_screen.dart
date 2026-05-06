import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _autoStartEnabled = false;
  bool _showNotifications = true;
  int _maxStoredMessages = 100;
  bool _darkModeEnabled = false;
  
  final _maxMessagesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _autoStartEnabled = prefs.getBool('auto_start_enabled') ?? false;
        _showNotifications = prefs.getBool('show_notifications') ?? true;
        _maxStoredMessages = prefs.getInt('max_stored_messages') ?? 100;
        _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
        
        _maxMessagesController.text = _maxStoredMessages.toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackbar('Error al cargar configuración: $e');
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('auto_start_enabled', _autoStartEnabled);
      await prefs.setBool('show_notifications', _showNotifications);
      await prefs.setInt('max_stored_messages', _maxStoredMessages);
      await prefs.setBool('dark_mode_enabled', _darkModeEnabled);
      
      setState(() {
        _isLoading = false;
      });
      
      _showSuccessSnackbar('Configuración guardada');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackbar('Error al guardar configuración: $e');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _resetSettings() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restablecer configuración'),
        content: const Text('¿Estás seguro de que quieres restablecer la configuración a los valores predeterminados?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _autoStartEnabled = false;
        _showNotifications = true;
        _maxStoredMessages = 100;
        _darkModeEnabled = false;
        _maxMessagesController.text = '100';
      });
      
      await _saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetSettings,
            tooltip: 'Restablecer configuración',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('General'),
                  SwitchListTile(
                    title: const Text('Tema oscuro'),
                    subtitle: const Text('Usar tema oscuro en la aplicación'),
                    value: _darkModeEnabled,
                    onChanged: (value) {
                      setState(() {
                        _darkModeEnabled = value;
                      });
                    },
                  ),
                  const Divider(),
                  
                  _buildSectionTitle('Interceptor'),
                  SwitchListTile(
                    title: const Text('Iniciar automáticamente'),
                    subtitle: const Text('Activar el interceptor al iniciar la aplicación'),
                    value: _autoStartEnabled,
                    onChanged: (value) {
                      setState(() {
                        _autoStartEnabled = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Mostrar notificaciones'),
                    subtitle: const Text('Notificar cuando se captura un mensaje'),
                    value: _showNotifications,
                    onChanged: (value) {
                      setState(() {
                        _showNotifications = value;
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _maxMessagesController,
                            decoration: const InputDecoration(
                              labelText: 'Máximo de mensajes almacenados',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              final intValue = int.tryParse(value) ?? 100;
                              setState(() {
                                _maxStoredMessages = intValue;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  
                  _buildSectionTitle('Información'),
                  const ListTile(
                    title: Text('Versión de la aplicación'),
                    subtitle: Text('1.0.0'),
                    leading: Icon(Icons.info_outline),
                  ),
                  ListTile(
                    title: const Text('Desarrollador'),
                    subtitle: const Text('Tu Nombre'),
                    leading: const Icon(Icons.code),
                    onTap: () {
                      // Abrir enlace al desarrollador
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Guardar configuración'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _maxMessagesController.dispose();
    super.dispose();
  }
}