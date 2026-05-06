import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whatsapp_interceptor/services/auth_service.dart';
import 'package:whatsapp_interceptor/screens/home_screen.dart';
import 'package:whatsapp_interceptor/utils/logger.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({Key? key}) : super(key: key);

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  static const String _tag = "ActivationScreen";
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  // Canal para guardar el activationCode en Android
  static const MethodChannel _channel =
      MethodChannel('com.example.whatsapp_interceptor/activation');

  // Colores de WhatsApp
  final Color _whatsappGreen = const Color(0xFF128C7E);
  final Color _backgroundColor = const Color(0xFF121B22);

  @override
  void initState() {
    super.initState();
    logger.d(_tag, 'Pantalla de activación inicializada');
  }

  Future<void> _saveActivationCodeNative(String code) async {
    try {
      await _channel.invokeMethod('saveActivationCode', {'code': code});
      logger.d(_tag, 'ActivationCode guardado en Android');
    } catch (e) {
      logger.e(_tag, 'Error guardando activationCode en Android', e);
    }
  }

  Future<void> _activateWithCode() async {
    final code = _codeController.text.trim();

    if (code.length != 8) {
      setState(() => _errorMessage = 'El código debe tener 8 dígitos');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      logger.d(_tag, 'Intentando activar con código: $code');

      // Verificar código con Firebase
      final activationResult = await authService.activateDevice(code);

      if (activationResult == 'success') {
        // Guardar activationCode en Android nativo
        await _saveActivationCodeNative(code);

        if (!mounted) return;

        // Navegar a la pantalla principal
        logger.d(_tag, 'Activación exitosa, navegando a pantalla principal');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen())
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = activationResult;
        });
        logger.w(_tag, 'Error de activación: $activationResult');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error de conexión. Inténtalo de nuevo.';
      });
      logger.e(_tag, 'Error al activar código', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_whatsappGreen),
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.message,
                      color: _whatsappGreen,
                      size: 80,
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'WhatsApp Interceptor',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ingresa el código de activación',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _codeController,
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                      decoration: InputDecoration(
                        hintText: '12345678',
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        filled: true,
                        fillColor: Colors.grey.shade800,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.vpn_key, color: _whatsappGreen),
                      ),
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                    ),
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _activateWithCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _whatsappGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'ACTIVAR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}