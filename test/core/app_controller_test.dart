import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_book_writer/core/services/app_controller.dart';
import 'package:my_ai_book_writer/core/services/assistant_service.dart';
import 'package:my_ai_book_writer/core/storage/settings_storage.dart';
import 'package:my_ai_book_writer/core/storage/workspace_storage.dart';
import 'package:my_ai_book_writer/features/import_export/import_export_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'initializes seeded workspace and supports scene edit undo redo',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'my_ai_book_writer_controller_test',
      );
      final settingsStorage = SettingsStorage();
      final controller = AppController(
        workspaceStorage: WorkspaceStorage(
          baseDirectoryPath: tempDirectory.path,
        ),
        settingsStorage: settingsStorage,
        assistantService: AssistantService(settingsStorage: settingsStorage),
        importExportService: const ImportExportService(),
      );

      addTearDown(() async {
        controller.dispose();
        await tempDirectory.delete(recursive: true);
      });

      await controller.initialize();

      expect(controller.books, isNotEmpty);
      expect(controller.activeBook, isNotNull);
      expect(controller.selectedScene, isNotNull);

      final original = controller.selectedSceneContent;
      controller.updateSceneContent('Updated scene text');
      expect(controller.selectedSceneContent, 'Updated scene text');

      controller.undo();
      expect(controller.selectedSceneContent, original);

      controller.redo();
      expect(controller.selectedSceneContent, 'Updated scene text');
    },
  );

  test('can create a new book and set it active', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'my_ai_book_writer_controller_books',
    );
    final settingsStorage = SettingsStorage();
    final controller = AppController(
      workspaceStorage: WorkspaceStorage(baseDirectoryPath: tempDirectory.path),
      settingsStorage: settingsStorage,
      assistantService: AssistantService(settingsStorage: settingsStorage),
      importExportService: const ImportExportService(),
    );

    addTearDown(() async {
      controller.dispose();
      await tempDirectory.delete(recursive: true);
    });

    await controller.initialize();
    final initialCount = controller.books.length;

    controller.createBook(title: 'Second Book');

    expect(controller.books.length, initialCount + 1);
    expect(controller.activeBook?.title, 'Second Book');
    expect(controller.selectedScene, isNotNull);
  });

  test('can rename book hierarchy items and remove a book', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'my_ai_book_writer_controller_rename_remove',
    );
    final settingsStorage = SettingsStorage();
    final controller = AppController(
      workspaceStorage: WorkspaceStorage(baseDirectoryPath: tempDirectory.path),
      settingsStorage: settingsStorage,
      assistantService: AssistantService(settingsStorage: settingsStorage),
      importExportService: const ImportExportService(),
    );

    addTearDown(() async {
      controller.dispose();
      await tempDirectory.delete(recursive: true);
    });

    await controller.initialize();

    final seedBook = controller.activeBook!;
    final seedPart = seedBook.parts.first;
    final seedChapter = seedPart.chapters.first;
    final seedScene = seedChapter.scenes.first;

    controller.renameBook(bookId: seedBook.id, title: 'Renamed Book');
    controller.renamePart(partId: seedPart.id, title: 'Renamed Part');
    controller.renameChapter(
      chapterId: seedChapter.id,
      title: 'Renamed Chapter',
    );
    controller.renameScene(sceneId: seedScene.id, title: 'Renamed Scene');

    expect(controller.activeBook?.title, 'Renamed Book');
    expect(controller.activeBook?.parts.first.title, 'Renamed Part');
    expect(
      controller.activeBook?.parts.first.chapters.first.title,
      'Renamed Chapter',
    );
    expect(
      controller.activeBook?.parts.first.chapters.first.scenes.first.title,
      'Renamed Scene',
    );

    controller.createBook(title: 'Second Book');
    final removableBookId = controller.activeBook!.id;

    controller.removeBook(removableBookId);

    expect(controller.books.any((book) => book.id == removableBookId), isFalse);
    expect(controller.activeBook, isNotNull);
    expect(controller.activeBook?.title, 'Renamed Book');
  });

  test('can remove last remaining book', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'my_ai_book_writer_controller_remove_last',
    );
    final settingsStorage = SettingsStorage();
    final controller = AppController(
      workspaceStorage: WorkspaceStorage(baseDirectoryPath: tempDirectory.path),
      settingsStorage: settingsStorage,
      assistantService: AssistantService(settingsStorage: settingsStorage),
      importExportService: const ImportExportService(),
    );

    addTearDown(() async {
      controller.dispose();
      await tempDirectory.delete(recursive: true);
    });

    await controller.initialize();

    controller.removeBook(controller.books.first.id);

    expect(controller.books, isEmpty);
    expect(controller.activeBook, isNull);
    expect(controller.selectedScene, isNull);
  });
}
