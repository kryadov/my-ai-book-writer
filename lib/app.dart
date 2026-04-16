import 'package:flutter/material.dart';

import 'core/services/app_controller.dart';
import 'features/workspace/workspace_shell.dart';

class MyAiBookWriterApp extends StatelessWidget {
  const MyAiBookWriterApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My AI Book Writer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: WorkspaceShell(controller: controller),
    );
  }
}
