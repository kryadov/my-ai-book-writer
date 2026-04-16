import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/app_controller.dart';
import 'core/services/assistant_service.dart';
import 'core/storage/settings_storage.dart';
import 'core/storage/workspace_storage.dart';
import 'features/import_export/import_export_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsStorage = SettingsStorage();
  final workspaceStorage = WorkspaceStorage();
  final assistantService = AssistantService(settingsStorage: settingsStorage);
  final importExportService = const ImportExportService();

  final controller = AppController(
    workspaceStorage: workspaceStorage,
    settingsStorage: settingsStorage,
    assistantService: assistantService,
    importExportService: importExportService,
  );
  await controller.initialize();

  runApp(MyAiBookWriterApp(controller: controller));
}
