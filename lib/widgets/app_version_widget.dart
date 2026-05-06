// lib/widgets/app_version_widget.dart
import 'package:flutter/material.dart';

class AppVersionWidget extends StatefulWidget {
  final Color? textColor;
  
  const AppVersionWidget({
    Key? key,
    this.textColor,
  }) : super(key: key);

  @override
  State<AppVersionWidget> createState() => _AppVersionWidgetState();
}

class _AppVersionWidgetState extends State<AppVersionWidget> {
  // Versiones hardcodeadas sin necesidad de package_info_plus
  final String _version = '1.0.0';
  final String _buildNumber = '1';
  
  @override
  Widget build(BuildContext context) {
    return Text(
      'Versión $_version (Build $_buildNumber)',
      style: TextStyle(
        fontSize: 12,
        color: widget.textColor ?? Colors.grey[600],
      ),
      textAlign: TextAlign.center,
    );
  }
}