import 'package:flutter/material.dart';
import '../database/presentation/control_panel_database_screen.dart';

/// Legacy entry point: keep for backward compatibility.
class ControlPanelScreen extends StatelessWidget {
  const ControlPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ControlPanelDatabaseScreen();
  }
}