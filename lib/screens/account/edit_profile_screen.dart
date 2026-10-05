import 'package:flutter/material.dart';
import 'personal_data_screen.dart';

export 'personal_data_screen.dart';

/// Pantalla de edición de datos personales (retrocompatibilidad)
class EditProfileScreen extends StatelessWidget {
  final int initialTabIndex;

  const EditProfileScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    return const PersonalDataScreen();
  }
}

