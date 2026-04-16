import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_ai_book_writer/app.dart';
import 'package:my_ai_book_writer/core/services/app_controller.dart';
import 'package:my_ai_book_writer/core/services/assistant_service.dart';
import 'package:my_ai_book_writer/core/storage/settings_storage.dart';
import 'package:my_ai_book_writer/core/storage/workspace_storage.dart';
import 'package:my_ai_book_writer/features/import_export/import_export_service.dart';

void main() {
  testWidgets('App shows loading shell before initialization', (
    WidgetTester tester,
  ) async {
    final settingsStorage = SettingsStorage();
    final controller = AppController(
      workspaceStorage: WorkspaceStorage(),
      settingsStorage: settingsStorage,
      assistantService: AssistantService(settingsStorage: settingsStorage),
      importExportService: const ImportExportService(),
    );

    addTearDown(() {
      controller.dispose();
    });

    await tester.pumpWidget(MyAiBookWriterApp(controller: controller));

    expect(find.byType(MyAiBookWriterApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
