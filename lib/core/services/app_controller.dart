import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../features/import_export/import_export_service.dart';
import '../models/assistant_models.dart';
import '../models/book_models.dart';
import '../storage/settings_storage.dart';
import '../storage/workspace_storage.dart';
import 'assistant_service.dart';
import 'change_history.dart';

class AppController extends ChangeNotifier {
  AppController({
    required WorkspaceStorage workspaceStorage,
    required SettingsStorage settingsStorage,
    required AssistantService assistantService,
    required ImportExportService importExportService,
    Uuid? uuid,
  }) : _workspaceStorage = workspaceStorage,
       _settingsStorage = settingsStorage,
       _assistantService = assistantService,
       _importExportService = importExportService,
       _uuid = uuid ?? const Uuid();

  final WorkspaceStorage _workspaceStorage;
  final SettingsStorage _settingsStorage;
  final AssistantService _assistantService;
  final ImportExportService _importExportService;
  final Uuid _uuid;

  final Map<String, TextChangeHistory> _historyByScene =
      <String, TextChangeHistory>{};

  Timer? _autosaveTimer;

  WorkspaceData _workspace = WorkspaceData(
    books: const <Book>[],
    updatedAt: DateTime.now(),
  );
  AssistantPreferences _assistantPreferences = const AssistantPreferences(
    providers: <AiProviderType, ProviderSettings>{},
    taskModelMapping: <AssistantTask, String>{},
    defaultScope: AssistantScope.scene,
    temperature: 0.7,
    maxTokens: 1000,
  );

  bool _isLoading = true;
  bool _isSaving = false;
  bool _focusMode = false;
  bool _splitView = true;
  bool _assistantBusy = false;
  String _assistantOutput = '';
  String? _assistantError;
  AssistantTask _selectedTask = AssistantTask.rephrase;
  AssistantScope _selectedScope = AssistantScope.scene;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get focusMode => _focusMode;
  bool get splitView => _splitView;
  bool get assistantBusy => _assistantBusy;
  String get assistantOutput => _assistantOutput;
  String? get assistantError => _assistantError;
  WorkspaceData get workspace => _workspace;
  AssistantPreferences get assistantPreferences => _assistantPreferences;
  AssistantTask get selectedTask => _selectedTask;
  AssistantScope get selectedScope => _selectedScope;

  List<Book> get books => _workspace.books;

  Book? get activeBook {
    final activeId = _workspace.activeBookId;
    if (activeId == null) {
      return null;
    }
    for (final book in _workspace.books) {
      if (book.id == activeId) {
        return book;
      }
    }
    return null;
  }

  Scene? get selectedScene {
    final selectedId = _workspace.selectedSceneId;
    if (selectedId == null) {
      return null;
    }
    for (final book in _workspace.books) {
      for (final part in book.parts) {
        for (final chapter in part.chapters) {
          for (final scene in chapter.scenes) {
            if (scene.id == selectedId) {
              return scene;
            }
          }
        }
      }
    }
    return null;
  }

  String get selectedSceneContent => selectedScene?.content ?? '';

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _assistantPreferences = await _settingsStorage.loadAssistantPreferences();
    final workspace =
        await _workspaceStorage.loadWorkspace() ??
        await _workspaceStorage.loadRecoverySnapshot();
    _workspace = workspace ?? _seedWorkspace();
    _workspace = _ensureValidSelection(_workspace);

    final scene = selectedScene;
    if (scene != null) {
      _historyByScene[scene.id] = TextChangeHistory(
        initialValue: scene.content,
      );
    }

    _selectedScope = _assistantPreferences.defaultScope;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }

  void setFocusMode(bool value) {
    _focusMode = value;
    notifyListeners();
  }

  void setSplitView(bool value) {
    _splitView = value;
    notifyListeners();
  }

  void setAssistantTask(AssistantTask task) {
    _selectedTask = task;
    notifyListeners();
  }

  void setAssistantScope(AssistantScope scope) {
    _selectedScope = scope;
    notifyListeners();
  }

  Future<void> saveApiKey({
    required String alias,
    required String value,
  }) async {
    await _settingsStorage.saveApiKey(alias: alias, value: value);
  }

  Future<void> updateAssistantPreferences(
    AssistantPreferences preferences,
  ) async {
    _assistantPreferences = preferences;
    await _settingsStorage.saveAssistantPreferences(preferences);
    notifyListeners();
  }

  Future<void> saveNow() async {
    _isSaving = true;
    notifyListeners();
    final snapshot = _workspace.copyWith(updatedAt: DateTime.now());
    _workspace = snapshot;
    await _workspaceStorage.saveWorkspace(snapshot);
    await _workspaceStorage.saveRecoverySnapshot(snapshot);
    _isSaving = false;
    notifyListeners();
  }

  void createBook({String? title}) {
    final now = DateTime.now();
    final scene = Scene(
      id: _uuid.v4(),
      title: 'Scene 1',
      order: 1,
      content: '',
      createdAt: now,
      updatedAt: now,
    );
    final chapter = Chapter(
      id: _uuid.v4(),
      title: 'Chapter 1',
      order: 1,
      scenes: <Scene>[scene],
    );
    final part = BookPart(
      id: _uuid.v4(),
      title: 'Part 1',
      order: 1,
      chapters: <Chapter>[chapter],
    );
    final book = Book(
      id: _uuid.v4(),
      title: title?.trim().isNotEmpty == true
          ? title!.trim()
          : 'Book ${_workspace.books.length + 1}',
      description: '',
      parts: <BookPart>[part],
      storyBibleNotes: const <StoryBibleNote>[],
      createdAt: now,
      updatedAt: now,
    );

    _workspace = _workspace.copyWith(
      books: <Book>[..._workspace.books, book],
      activeBookId: book.id,
      selectedSceneId: scene.id,
      updatedAt: now,
    );
    _historyByScene[scene.id] = TextChangeHistory(initialValue: scene.content);
    _queueAutosave();
    notifyListeners();
  }

  void removeBook(String bookId) {
    final removedBook = _workspace.books
        .where((book) => book.id == bookId)
        .firstOrNull;
    if (removedBook == null) {
      return;
    }

    final updatedBooks = _workspace.books
        .where((book) => book.id != bookId)
        .toList(growable: false);
    for (final part in removedBook.parts) {
      for (final chapter in part.chapters) {
        for (final scene in chapter.scenes) {
          _historyByScene.remove(scene.id);
        }
      }
    }

    final now = DateTime.now();
    if (updatedBooks.isEmpty) {
      _workspace = _workspace.copyWith(
        books: updatedBooks,
        clearActiveBook: true,
        clearSelectedScene: true,
        updatedAt: now,
      );
      _queueAutosave();
      notifyListeners();
      return;
    }

    final currentActiveId = _workspace.activeBookId;
    final resolvedActiveBook =
        updatedBooks.where((book) => book.id == currentActiveId).firstOrNull ??
        updatedBooks.first;

    final selectedSceneId = _workspace.selectedSceneId;
    final resolvedSelectedSceneId =
        _findSceneById(resolvedActiveBook, selectedSceneId)?.id ??
        _firstSceneInBook(resolvedActiveBook)?.id;

    _workspace = _workspace.copyWith(
      books: updatedBooks,
      activeBookId: resolvedActiveBook.id,
      selectedSceneId: resolvedSelectedSceneId,
      clearSelectedScene: resolvedSelectedSceneId == null,
      updatedAt: now,
    );
    if (resolvedSelectedSceneId != null) {
      final scene = selectedScene;
      if (scene != null) {
        _historyByScene.putIfAbsent(
          scene.id,
          () => TextChangeHistory(initialValue: scene.content),
        );
      }
    }
    _queueAutosave();
    notifyListeners();
  }

  void renameBook({required String bookId, required String title}) {
    final nextTitle = title.trim();
    if (nextTitle.isEmpty) {
      return;
    }

    final now = DateTime.now();
    var changed = false;
    final books = _workspace.books
        .map((book) {
          if (book.id != bookId || book.title == nextTitle) {
            return book;
          }
          changed = true;
          return book.copyWith(title: nextTitle, updatedAt: now);
        })
        .toList(growable: false);

    if (!changed) {
      return;
    }
    _workspace = _workspace.copyWith(books: books, updatedAt: now);
    _queueAutosave();
    notifyListeners();
  }

  void renamePart({required String partId, required String title}) {
    final nextTitle = title.trim();
    if (nextTitle.isEmpty) {
      return;
    }

    final now = DateTime.now();
    var changed = false;
    final books = _workspace.books
        .map((book) {
          var bookChanged = false;
          final parts = book.parts
              .map((part) {
                if (part.id != partId || part.title == nextTitle) {
                  return part;
                }
                bookChanged = true;
                return part.copyWith(title: nextTitle);
              })
              .toList(growable: false);

          if (!bookChanged) {
            return book;
          }
          changed = true;
          return book.copyWith(parts: parts, updatedAt: now);
        })
        .toList(growable: false);

    if (!changed) {
      return;
    }
    _workspace = _workspace.copyWith(books: books, updatedAt: now);
    _queueAutosave();
    notifyListeners();
  }

  void renameChapter({required String chapterId, required String title}) {
    final nextTitle = title.trim();
    if (nextTitle.isEmpty) {
      return;
    }

    final now = DateTime.now();
    var changed = false;
    final books = _workspace.books
        .map((book) {
          var bookChanged = false;
          final parts = book.parts
              .map((part) {
                var partChanged = false;
                final chapters = part.chapters
                    .map((chapter) {
                      if (chapter.id != chapterId ||
                          chapter.title == nextTitle) {
                        return chapter;
                      }
                      partChanged = true;
                      return chapter.copyWith(title: nextTitle);
                    })
                    .toList(growable: false);

                if (!partChanged) {
                  return part;
                }
                bookChanged = true;
                return part.copyWith(chapters: chapters);
              })
              .toList(growable: false);

          if (!bookChanged) {
            return book;
          }
          changed = true;
          return book.copyWith(parts: parts, updatedAt: now);
        })
        .toList(growable: false);

    if (!changed) {
      return;
    }
    _workspace = _workspace.copyWith(books: books, updatedAt: now);
    _queueAutosave();
    notifyListeners();
  }

  void renameScene({required String sceneId, required String title}) {
    final nextTitle = title.trim();
    if (nextTitle.isEmpty) {
      return;
    }

    final now = DateTime.now();
    var changed = false;
    final books = _workspace.books
        .map((book) {
          var bookChanged = false;
          final parts = book.parts
              .map((part) {
                var partChanged = false;
                final chapters = part.chapters
                    .map((chapter) {
                      var chapterChanged = false;
                      final scenes = chapter.scenes
                          .map((scene) {
                            if (scene.id != sceneId ||
                                scene.title == nextTitle) {
                              return scene;
                            }
                            chapterChanged = true;
                            return scene.copyWith(
                              title: nextTitle,
                              updatedAt: now,
                            );
                          })
                          .toList(growable: false);

                      if (!chapterChanged) {
                        return chapter;
                      }
                      partChanged = true;
                      return chapter.copyWith(scenes: scenes);
                    })
                    .toList(growable: false);

                if (!partChanged) {
                  return part;
                }
                bookChanged = true;
                return part.copyWith(chapters: chapters);
              })
              .toList(growable: false);

          if (!bookChanged) {
            return book;
          }
          changed = true;
          return book.copyWith(parts: parts, updatedAt: now);
        })
        .toList(growable: false);

    if (!changed) {
      return;
    }
    _workspace = _workspace.copyWith(books: books, updatedAt: now);
    _queueAutosave();
    notifyListeners();
  }

  void setActiveBook(String bookId) {
    final book = _workspace.books
        .where((item) => item.id == bookId)
        .firstOrNull;
    if (book == null) {
      return;
    }

    String? firstSceneId;
    for (final part in book.parts) {
      for (final chapter in part.chapters) {
        if (chapter.scenes.isNotEmpty) {
          firstSceneId = chapter.scenes.first.id;
          break;
        }
      }
      if (firstSceneId != null) {
        break;
      }
    }

    _workspace = _workspace.copyWith(
      activeBookId: bookId,
      selectedSceneId: firstSceneId,
      updatedAt: DateTime.now(),
    );
    if (firstSceneId != null) {
      final scene = selectedScene;
      if (scene != null) {
        _historyByScene.putIfAbsent(
          scene.id,
          () => TextChangeHistory(initialValue: scene.content),
        );
      }
    }
    notifyListeners();
  }

  void addPart() {
    final book = activeBook;
    if (book == null) {
      return;
    }

    final part = BookPart(
      id: _uuid.v4(),
      title: 'Part ${book.parts.length + 1}',
      order: book.parts.length + 1,
      chapters: const <Chapter>[],
    );
    final updatedBook = book.copyWith(
      parts: <BookPart>[...book.parts, part],
      updatedAt: DateTime.now(),
    );
    _replaceBook(updatedBook);
  }

  void addChapter(String partId) {
    final book = activeBook;
    if (book == null) {
      return;
    }

    final parts = <BookPart>[];
    for (final part in book.parts) {
      if (part.id != partId) {
        parts.add(part);
        continue;
      }

      final chapter = Chapter(
        id: _uuid.v4(),
        title: 'Chapter ${part.chapters.length + 1}',
        order: part.chapters.length + 1,
        scenes: const <Scene>[],
      );
      parts.add(part.copyWith(chapters: <Chapter>[...part.chapters, chapter]));
    }

    _replaceBook(book.copyWith(parts: parts, updatedAt: DateTime.now()));
  }

  void addScene(String chapterId) {
    final book = activeBook;
    if (book == null) {
      return;
    }

    final now = DateTime.now();
    String? newSceneId;

    final parts = <BookPart>[];
    for (final part in book.parts) {
      final chapters = <Chapter>[];
      for (final chapter in part.chapters) {
        if (chapter.id != chapterId) {
          chapters.add(chapter);
          continue;
        }

        final scene = Scene(
          id: _uuid.v4(),
          title: 'Scene ${chapter.scenes.length + 1}',
          order: chapter.scenes.length + 1,
          content: '',
          createdAt: now,
          updatedAt: now,
        );
        newSceneId = scene.id;
        chapters.add(
          chapter.copyWith(scenes: <Scene>[...chapter.scenes, scene]),
        );
      }
      parts.add(part.copyWith(chapters: chapters));
    }

    _replaceBook(book.copyWith(parts: parts, updatedAt: now));
    if (newSceneId != null) {
      _workspace = _workspace.copyWith(
        selectedSceneId: newSceneId,
        updatedAt: now,
      );
      _historyByScene[newSceneId] = TextChangeHistory(initialValue: '');
    }
    _queueAutosave();
    notifyListeners();
  }

  void selectScene(String sceneId) {
    _workspace = _workspace.copyWith(
      selectedSceneId: sceneId,
      updatedAt: DateTime.now(),
    );
    final scene = selectedScene;
    if (scene != null) {
      _historyByScene.putIfAbsent(
        scene.id,
        () => TextChangeHistory(initialValue: scene.content),
      );
    }
    notifyListeners();
  }

  void updateSceneContent(String nextContent) {
    final scene = selectedScene;
    if (scene == null || scene.content == nextContent) {
      return;
    }

    _historyByScene
        .putIfAbsent(
          scene.id,
          () => TextChangeHistory(initialValue: scene.content),
        )
        .commit(nextContent);

    _updateScene(
      sceneId: scene.id,
      content: nextContent,
      updatedAt: DateTime.now(),
    );
    _queueAutosave();
    notifyListeners();
  }

  void undo() {
    final scene = selectedScene;
    if (scene == null) {
      return;
    }

    final history = _historyByScene.putIfAbsent(
      scene.id,
      () => TextChangeHistory(initialValue: scene.content),
    );
    if (!history.canUndo) {
      return;
    }
    final text = history.undo();
    _updateScene(sceneId: scene.id, content: text, updatedAt: DateTime.now());
    _queueAutosave();
    notifyListeners();
  }

  void redo() {
    final scene = selectedScene;
    if (scene == null) {
      return;
    }

    final history = _historyByScene.putIfAbsent(
      scene.id,
      () => TextChangeHistory(initialValue: scene.content),
    );
    if (!history.canRedo) {
      return;
    }
    final text = history.redo();
    _updateScene(sceneId: scene.id, content: text, updatedAt: DateTime.now());
    _queueAutosave();
    notifyListeners();
  }

  Future<void> copySelectedSceneToClipboard() async {
    final scene = selectedScene;
    if (scene == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: scene.content));
  }

  Future<void> pasteClipboardIntoScene() async {
    final scene = selectedScene;
    if (scene == null) {
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text;
    if (value == null || value.isEmpty) {
      return;
    }
    updateSceneContent('${scene.content}\n$value');
  }

  Future<void> runAssistant({String? selection}) async {
    final book = activeBook;
    final scene = selectedScene;
    if (book == null || scene == null) {
      return;
    }

    _assistantBusy = true;
    _assistantError = null;
    notifyListeners();

    try {
      final request = AssistantRequest(
        task: _selectedTask,
        scope: _selectedScope,
        content: _contentForScope(_selectedScope),
        storyBible: book.storyBibleNotes
            .map((item) => '${item.title}: ${item.content}')
            .join('\n'),
        bookTitle: book.title,
        selection: selection,
      );

      final response = await _assistantService.run(
        preferences: _assistantPreferences,
        request: request,
      );
      _assistantOutput = response.text;
    } on Exception catch (error) {
      _assistantError = error.toString();
    } finally {
      _assistantBusy = false;
      notifyListeners();
    }
  }

  void applyAssistantOutputToScene() {
    if (_assistantOutput.trim().isEmpty) {
      return;
    }
    updateSceneContent(_assistantOutput);
  }

  Future<String> importFromPath({
    required String filePath,
    required ImportFormat format,
  }) async {
    return _importExportService.importFile(filePath: filePath, format: format);
  }

  Future<void> exportToPath({
    required String filePath,
    required String content,
    required ExportFormat format,
  }) async {
    await _importExportService.exportFile(
      filePath: filePath,
      content: content,
      format: format,
    );
  }

  String _contentForScope(AssistantScope scope) {
    final selected = selectedScene;
    final book = activeBook;
    if (selected == null || book == null) {
      return '';
    }

    switch (scope) {
      case AssistantScope.selection:
      case AssistantScope.scene:
        return selected.content;
      case AssistantScope.chapter:
        for (final part in book.parts) {
          for (final chapter in part.chapters) {
            if (chapter.scenes.any((scene) => scene.id == selected.id)) {
              return chapter.scenes.map((scene) => scene.content).join('\n\n');
            }
          }
        }
        return selected.content;
      case AssistantScope.book:
      case AssistantScope.conversation:
        return book.parts
            .expand((part) => part.chapters)
            .expand((chapter) => chapter.scenes)
            .map((scene) => scene.content)
            .join('\n\n');
    }
  }

  void _replaceBook(Book updatedBook) {
    final books = _workspace.books
        .map((book) => book.id == updatedBook.id ? updatedBook : book)
        .toList(growable: false);

    _workspace = _workspace.copyWith(books: books, updatedAt: DateTime.now());
    _queueAutosave();
    notifyListeners();
  }

  void _updateScene({
    required String sceneId,
    required String content,
    required DateTime updatedAt,
  }) {
    final active = activeBook;
    if (active == null) {
      return;
    }

    final parts = <BookPart>[];
    for (final part in active.parts) {
      final chapters = <Chapter>[];
      for (final chapter in part.chapters) {
        final scenes = chapter.scenes
            .map(
              (scene) => scene.id == sceneId
                  ? scene.copyWith(content: content, updatedAt: updatedAt)
                  : scene,
            )
            .toList(growable: false);
        chapters.add(chapter.copyWith(scenes: scenes));
      }
      parts.add(part.copyWith(chapters: chapters));
    }

    final updatedBook = active.copyWith(parts: parts, updatedAt: updatedAt);
    final books = _workspace.books
        .map((book) => book.id == active.id ? updatedBook : book)
        .toList(growable: false);
    _workspace = _workspace.copyWith(books: books, updatedAt: updatedAt);
  }

  void _queueAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 900), () async {
      final snapshot = _workspace.copyWith(updatedAt: DateTime.now());
      _workspace = snapshot;
      await _workspaceStorage.saveWorkspace(snapshot);
      await _workspaceStorage.saveRecoverySnapshot(snapshot);
      notifyListeners();
    });
  }

  WorkspaceData _ensureValidSelection(WorkspaceData workspace) {
    if (workspace.books.isEmpty) {
      return _seedWorkspace();
    }

    final activeBookId = workspace.activeBookId;
    final activeBook = workspace.books
        .where((book) => book.id == activeBookId)
        .firstOrNull;
    final resolvedBook = activeBook ?? workspace.books.first;

    final sceneId = workspace.selectedSceneId;
    final validScene = _findSceneById(resolvedBook, sceneId);
    final fallbackScene = _firstSceneInBook(resolvedBook);

    return workspace.copyWith(
      activeBookId: resolvedBook.id,
      selectedSceneId: validScene?.id ?? fallbackScene?.id,
      updatedAt: DateTime.now(),
    );
  }

  Scene? _findSceneById(Book book, String? sceneId) {
    if (sceneId == null) {
      return null;
    }
    for (final part in book.parts) {
      for (final chapter in part.chapters) {
        for (final scene in chapter.scenes) {
          if (scene.id == sceneId) {
            return scene;
          }
        }
      }
    }
    return null;
  }

  Scene? _firstSceneInBook(Book book) {
    for (final part in book.parts) {
      for (final chapter in part.chapters) {
        if (chapter.scenes.isNotEmpty) {
          return chapter.scenes.first;
        }
      }
    }
    return null;
  }

  WorkspaceData _seedWorkspace() {
    final now = DateTime.now();
    final firstScene = Scene(
      id: _uuid.v4(),
      title: 'Scene 1',
      order: 1,
      content: '# Scene 1\n\nStart writing your story here.',
      createdAt: now,
      updatedAt: now,
    );

    final firstBook = Book(
      id: _uuid.v4(),
      title: 'New Fiction Project',
      description: 'Draft workspace for your next manuscript.',
      parts: <BookPart>[
        BookPart(
          id: _uuid.v4(),
          title: 'Part 1',
          order: 1,
          chapters: <Chapter>[
            Chapter(
              id: _uuid.v4(),
              title: 'Chapter 1',
              order: 1,
              scenes: <Scene>[firstScene],
            ),
          ],
        ),
      ],
      storyBibleNotes: const <StoryBibleNote>[
        StoryBibleNote(
          id: 'note-genre',
          title: 'Genre',
          content: 'Character-driven fiction with emotional stakes.',
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    return WorkspaceData(
      books: <Book>[firstBook],
      activeBookId: firstBook.id,
      selectedSceneId: firstScene.id,
      updatedAt: now,
    );
  }
}
