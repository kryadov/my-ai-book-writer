import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/models/assistant_models.dart';
import '../../core/models/book_models.dart';
import '../../core/services/app_controller.dart';
import '../import_export/import_export_service.dart';
import '../settings/settings_dialog.dart';

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  late final TextEditingController _editorController;
  late final FocusNode _editorFocusNode;
  String? _boundSceneId;
  bool _syncingEditor = false;
  bool _workspaceCollapsed = false;
  bool _assistantCollapsed = false;

  @override
  void initState() {
    super.initState();
    _editorController = TextEditingController();
    _editorFocusNode = FocusNode();
    _editorController.addListener(_onEditorChanged);
  }

  @override
  void dispose() {
    _editorController
      ..removeListener(_onEditorChanged)
      ..dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  void _onEditorChanged() {
    if (_syncingEditor) {
      return;
    }
    widget.controller.updateSceneContent(_editorController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        _syncEditorIfNeeded();

        if (widget.controller.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                const _SaveIntent(),
            const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
                const _UndoIntent(),
            const SingleActivator(LogicalKeyboardKey.keyY, control: true):
                const _RedoIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _SaveIntent: CallbackAction<_SaveIntent>(
                onInvoke: (intent) => widget.controller.saveNow(),
              ),
              _UndoIntent: CallbackAction<_UndoIntent>(
                onInvoke: (intent) => widget.controller.undo(),
              ),
              _RedoIntent: CallbackAction<_RedoIntent>(
                onInvoke: (intent) => widget.controller.redo(),
              ),
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  widget.controller.activeBook?.title ?? 'My AI Book Writer',
                ),
                actions: [
                  IconButton(
                    tooltip: 'Add book',
                    onPressed: () => widget.controller.createBook(),
                    icon: const Icon(Icons.library_add),
                  ),
                  IconButton(
                    tooltip: 'Export active book as DOCX',
                    onPressed: _showExportBookDialog,
                    icon: const Icon(Icons.file_download),
                  ),
                  IconButton(
                    tooltip: 'Workspace files location',
                    onPressed: _showWorkspaceLocationDialog,
                    icon: const Icon(Icons.folder_open),
                  ),
                  IconButton(
                    tooltip: _workspaceCollapsed
                        ? 'Show workspace panel'
                        : 'Hide workspace panel',
                    onPressed: () {
                      setState(() {
                        _workspaceCollapsed = !_workspaceCollapsed;
                      });
                    },
                    icon: Icon(
                      _workspaceCollapsed
                          ? Icons.keyboard_double_arrow_right
                          : Icons.keyboard_double_arrow_left,
                    ),
                  ),
                  IconButton(
                    tooltip: _assistantCollapsed
                        ? 'Show assistant panel'
                        : 'Hide assistant panel',
                    onPressed: () {
                      setState(() {
                        _assistantCollapsed = !_assistantCollapsed;
                      });
                    },
                    icon: Icon(
                      _assistantCollapsed
                          ? Icons.keyboard_double_arrow_left
                          : Icons.keyboard_double_arrow_right,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Save now (Ctrl+S)',
                    onPressed: widget.controller.saveNow,
                    icon: widget.controller.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                  ),
                  IconButton(
                    tooltip: 'Focus mode',
                    onPressed: () => widget.controller.setFocusMode(
                      !widget.controller.focusMode,
                    ),
                    icon: Icon(
                      widget.controller.focusMode
                          ? Icons.fullscreen_exit
                          : Icons.fullscreen,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Assistant settings',
                    onPressed: () => showAssistantSettingsDialog(
                      context: context,
                      controller: widget.controller,
                    ),
                    icon: const Icon(Icons.settings),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              body: _buildBody(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (widget.controller.focusMode) {
      return _buildEditorPanel();
    }

    if (width >= 1200) {
      final children = <Widget>[];
      if (_workspaceCollapsed) {
        children.add(
          _buildCollapsedPanelButton(
            tooltip: 'Show workspace panel',
            icon: Icons.account_tree,
            onPressed: () {
              setState(() {
                _workspaceCollapsed = false;
              });
            },
          ),
        );
      } else {
        children.add(SizedBox(width: 300, child: _buildTreePanel()));
      }

      children.add(const VerticalDivider(width: 1));
      children.add(Expanded(child: _buildEditorPanel()));
      children.add(const VerticalDivider(width: 1));

      if (_assistantCollapsed) {
        children.add(
          _buildCollapsedPanelButton(
            tooltip: 'Show assistant panel',
            icon: Icons.smart_toy_outlined,
            onPressed: () {
              setState(() {
                _assistantCollapsed = false;
              });
            },
          ),
        );
      } else {
        children.add(SizedBox(width: 380, child: _buildAssistantPanel()));
      }

      return Row(children: children);
    }

    if (width >= 800) {
      if (_workspaceCollapsed) {
        return Row(
          children: [
            _buildCollapsedPanelButton(
              tooltip: 'Show workspace panel',
              icon: Icons.account_tree,
              onPressed: () {
                setState(() {
                  _workspaceCollapsed = false;
                });
              },
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _buildEditorPanel()),
          ],
        );
      }
      return Row(
        children: [
          SizedBox(width: 280, child: _buildTreePanel()),
          const VerticalDivider(width: 1),
          Expanded(child: _buildEditorPanel()),
        ],
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Structure'),
              Tab(text: 'Editor'),
              Tab(text: 'Assistant'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTreePanel(),
                _buildEditorPanel(),
                _buildAssistantPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedPanelButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 44,
      child: Center(
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon),
        ),
      ),
    );
  }

  Widget _buildTreePanel() {
    final books = widget.controller.books;
    if (books.isEmpty) {
      return const Center(
        child: Text('No books yet. Create one to get started.'),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Workspace',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Add book',
                onPressed: () => widget.controller.createBook(),
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                tooltip: 'Copy scene to clipboard',
                onPressed: widget.controller.copySelectedSceneToClipboard,
                icon: const Icon(Icons.copy),
              ),
              IconButton(
                tooltip: 'Paste clipboard into scene',
                onPressed: widget.controller.pasteClipboardIntoScene,
                icon: const Icon(Icons.paste),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            children: books
                .map(
                  (book) => _BookTreeCard(
                    book: book,
                    selectedSceneId:
                        widget.controller.workspace.selectedSceneId,
                    activeBookId: widget.controller.workspace.activeBookId,
                    onSelectBook: widget.controller.setActiveBook,
                    onAddPart: widget.controller.addPart,
                    onAddChapter: widget.controller.addChapter,
                    onAddScene: widget.controller.addScene,
                    onSelectScene: widget.controller.selectScene,
                    onRenameBook: () => _renameBook(book),
                    onRemoveBook: () => _removeBook(book),
                    onRenamePart: (part) => _renamePart(part),
                    onRenameChapter: (chapter) => _renameChapter(chapter),
                    onRenameScene: (scene) => _renameScene(scene),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _buildEditorPanel() {
    final hasScene = widget.controller.selectedScene != null;

    if (!hasScene) {
      return const Center(
        child: Text('Choose or create a scene to start writing.'),
      );
    }

    final textField = TextField(
      controller: _editorController,
      focusNode: _editorFocusNode,
      expands: true,
      maxLines: null,
      minLines: null,
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.top,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Write your scene in Markdown...',
      ),
    );

    final preview = Markdown(
      data: _editorController.text,
      selectable: true,
      padding: const EdgeInsets.all(12),
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                widget.controller.selectedScene?.title ?? 'Scene',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Undo (Ctrl+Z)',
                onPressed: widget.controller.undo,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: 'Redo (Ctrl+Y)',
                onPressed: widget.controller.redo,
                icon: const Icon(Icons.redo),
              ),
              IconButton(
                tooltip: 'Toggle split preview',
                onPressed: () => widget.controller.setSplitView(
                  !widget.controller.splitView,
                ),
                icon: Icon(
                  widget.controller.splitView
                      ? Icons.view_agenda
                      : Icons.splitscreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildEditorToolbar(),
          const SizedBox(height: 8),
          Expanded(
            child: widget.controller.splitView
                ? Row(
                    children: [
                      Expanded(child: textField),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: preview,
                        ),
                      ),
                    ],
                  )
                : textField,
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantPanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Assistant',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<AssistantTask>(
            initialValue: widget.controller.selectedTask,
            decoration: const InputDecoration(labelText: 'Task'),
            items: AssistantTask.values
                .map(
                  (task) =>
                      DropdownMenuItem(value: task, child: Text(task.label)),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                widget.controller.setAssistantTask(value);
              }
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<AssistantScope>(
            initialValue: widget.controller.selectedScope,
            decoration: const InputDecoration(labelText: 'Scope'),
            items: AssistantScope.values
                .map(
                  (scope) =>
                      DropdownMenuItem(value: scope, child: Text(scope.label)),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                widget.controller.setAssistantScope(value);
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.controller.assistantBusy
                      ? null
                      : () => widget.controller.runAssistant(
                          selection: _selectedEditorText(),
                        ),
                  icon: widget.controller.assistantBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: const Text('Run assistant'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.controller.assistantOutput.trim().isEmpty
                      ? null
                      : widget.controller.applyAssistantOutputToScene,
                  icon: const Icon(Icons.publish),
                  label: const Text('Replace scene with result'),
                ),
              ),
            ],
          ),
          if (widget.controller.assistantError != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.controller.assistantError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  widget.controller.assistantOutput.trim().isEmpty
                      ? 'Assistant output will appear here.'
                      : widget.controller.assistantOutput,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorToolbar() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: 6,
          children: [
            IconButton(
              tooltip: 'Bold',
              onPressed: () => _wrapSelection(prefix: '**'),
              icon: const Icon(Icons.format_bold),
            ),
            IconButton(
              tooltip: 'Italic',
              onPressed: () => _wrapSelection(prefix: '*'),
              icon: const Icon(Icons.format_italic),
            ),
            IconButton(
              tooltip: 'Strikethrough',
              onPressed: () => _wrapSelection(prefix: '~~'),
              icon: const Icon(Icons.format_strikethrough),
            ),
            IconButton(
              tooltip: 'Inline code',
              onPressed: () => _wrapSelection(prefix: '`'),
              icon: const Icon(Icons.code),
            ),
            const VerticalDivider(width: 16),
            IconButton(
              tooltip: 'Heading',
              onPressed: () => _toggleLinePrefix('# '),
              icon: const Icon(Icons.title),
            ),
            IconButton(
              tooltip: 'Bullet list',
              onPressed: () => _toggleLinePrefix('- '),
              icon: const Icon(Icons.format_list_bulleted),
            ),
            IconButton(
              tooltip: 'Quote',
              onPressed: () => _toggleLinePrefix('> '),
              icon: const Icon(Icons.format_quote),
            ),
            const VerticalDivider(width: 16),
            IconButton(
              tooltip: 'Add Image',
              onPressed: _pickAndAddImage,
              icon: const Icon(Icons.image),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _pickAndAddImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final imagePath = await widget.controller.addImageToSelectedScene(
        result.files.single.path!,
      );
      if (imagePath != null) {
        final uri = Uri.file(imagePath);
        final tag = '![image]($uri)';

        final text = _editorController.text;
        final selection = _editorController.selection;
        final nextText = text.replaceRange(
          selection.start,
          selection.end,
          tag,
        );

        _editorController.value = TextEditingValue(
          text: nextText,
          selection: TextSelection.collapsed(
            offset: selection.start + tag.length,
          ),
        );
      }
    }
  }

  Future<void> _renameBook(Book book) async {
    final nextTitle = await _showRenameDialog(
      title: 'Rename book',
      initialValue: book.title,
      fieldLabel: 'Book title',
    );
    if (nextTitle == null) {
      return;
    }
    widget.controller.renameBook(bookId: book.id, title: nextTitle);
  }

  Future<void> _removeBook(Book book) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove book'),
          content: Text('Remove "${book.title}" from the workspace?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (shouldRemove == true) {
      widget.controller.removeBook(book.id);
    }
  }

  Future<void> _showExportBookDialog() async {
    final book = widget.controller.activeBook;
    if (book == null) {
      _showInfo('Select a book before exporting.');
      return;
    }

    final workspacePath = widget.controller.workspaceRootDirectoryPath;
    final suggestedPath = workspacePath == null
        ? '${book.title}.docx'
        : '$workspacePath${Platform.pathSeparator}${_sanitizeFileSegment(book.title)}.docx';
    final pathController = TextEditingController(text: suggestedPath);

    final path = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Export active book as DOCX'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter full output path for the DOCX file.'),
                const SizedBox(height: 10),
                TextField(
                  controller: pathController,
                  decoration: const InputDecoration(
                    labelText: 'DOCX path',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tip: keep it inside workspace folder if you want it near project data.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(pathController.text.trim());
              },
              child: const Text('Export DOCX'),
            ),
          ],
        );
      },
    );
    pathController.dispose();

    if (path == null || path.isEmpty) {
      return;
    }

    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await widget.controller.exportToPath(
        filePath: file.path,
        content: widget.controller.activeBookExportContent,
        format: ExportFormat.docx,
      );
      _showInfo('DOCX exported to: ${file.path}');
    } on Exception catch (error) {
      _showInfo('Export failed: $error');
    }
  }

  Future<void> _showWorkspaceLocationDialog() async {
    final workspacePath = widget.controller.workspaceRootDirectoryPath;
    if (workspacePath == null || workspacePath.isEmpty) {
      _showInfo('Workspace path is not available yet. Try again in a moment.');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Workspace files location'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('All workspace files are stored in:'),
                const SizedBox(height: 10),
                SelectableText(workspacePath),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final clipboard = Clipboard.setData(ClipboardData(text: workspacePath));
                await clipboard;
                if (!mounted) {
                  return;
                }
                navigator.pop();
                _showInfo('Workspace path copied to clipboard.');
              },
              child: const Text('Copy path'),
            ),
            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final opened = await _openDirectory(workspacePath);
                if (!mounted) {
                  return;
                }
                navigator.pop();
                if (opened) {
                  _showInfo('Opened workspace folder.');
                } else {
                  _showInfo(
                    'Could not open folder automatically. Path copied to clipboard.',
                  );
                  await Clipboard.setData(ClipboardData(text: workspacePath));
                }
              },
              child: const Text('Open folder'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _openDirectory(String directoryPath) async {
    try {
      if (kIsWeb) {
        return false;
      }

      if (Platform.isWindows) {
        await Process.run('explorer.exe', [directoryPath]);
        return true;
      }
      if (Platform.isMacOS) {
        await Process.run('open', [directoryPath]);
        return true;
      }
      if (Platform.isLinux) {
        await Process.run('xdg-open', [directoryPath]);
        return true;
      }
      return false;
    } on Exception {
      return false;
    }
  }

  String _sanitizeFileSegment(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (normalized.isEmpty) {
      return 'book';
    }
    return normalized;
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _renamePart(BookPart part) async {
    final nextTitle = await _showRenameDialog(
      title: 'Rename part',
      initialValue: part.title,
      fieldLabel: 'Part title',
    );
    if (nextTitle == null) {
      return;
    }
    widget.controller.renamePart(partId: part.id, title: nextTitle);
  }

  Future<void> _renameChapter(Chapter chapter) async {
    final nextTitle = await _showRenameDialog(
      title: 'Rename chapter',
      initialValue: chapter.title,
      fieldLabel: 'Chapter title',
    );
    if (nextTitle == null) {
      return;
    }
    widget.controller.renameChapter(chapterId: chapter.id, title: nextTitle);
  }

  Future<void> _renameScene(Scene scene) async {
    final nextTitle = await _showRenameDialog(
      title: 'Rename scene',
      initialValue: scene.title,
      fieldLabel: 'Scene title',
    );
    if (nextTitle == null) {
      return;
    }
    widget.controller.renameScene(sceneId: scene.id, title: nextTitle);
  }

  Future<String?> _showRenameDialog({
    required String title,
    required String initialValue,
    required String fieldLabel,
  }) async {
    final textController = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: InputDecoration(labelText: fieldLabel),
            onSubmitted: (value) {
              final trimmed = value.trim();
              Navigator.of(context).pop(trimmed.isEmpty ? null : trimmed);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = textController.text.trim();
                Navigator.of(context).pop(trimmed.isEmpty ? null : trimmed);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    textController.dispose();
    return value;
  }

  void _wrapSelection({required String prefix, String? suffix}) {
    final currentSelection = _editorController.selection;
    if (!currentSelection.isValid) {
      return;
    }

    final selection = currentSelection.start <= currentSelection.end
        ? currentSelection
        : TextSelection(
            baseOffset: currentSelection.end,
            extentOffset: currentSelection.start,
          );
    final markerSuffix = suffix ?? prefix;
    final text = _editorController.text;
    final before = selection.textBefore(text);
    final inside = selection.textInside(text);
    final after = selection.textAfter(text);

    final replacement =
        '$prefix${inside.isEmpty ? 'text' : inside}$markerSuffix';
    final nextText = '$before$replacement$after';
    final anchor = before.length + prefix.length;
    final focus = anchor + (inside.isEmpty ? 4 : inside.length);
    _applyEditorText(
      nextText,
      TextSelection(baseOffset: anchor, extentOffset: focus),
    );
  }

  void _toggleLinePrefix(String prefix) {
    final currentSelection = _editorController.selection;
    if (!currentSelection.isValid) {
      return;
    }

    final selection = currentSelection.start <= currentSelection.end
        ? currentSelection
        : TextSelection(
            baseOffset: currentSelection.end,
            extentOffset: currentSelection.start,
          );
    final text = _editorController.text;
    final startLineIndex = selection.start <= 0
        ? 0
        : text.lastIndexOf('\n', selection.start - 1) + 1;
    final endLineIndex = text.indexOf('\n', selection.end);
    final blockEnd = endLineIndex == -1 ? text.length : endLineIndex;

    final block = text.substring(startLineIndex, blockEnd);
    final lines = block.split('\n');
    final allPrefixed = lines.every((line) => line.startsWith(prefix));
    final transformedLines = lines
        .map(
          (line) =>
              allPrefixed ? line.replaceFirst(prefix, '') : '$prefix$line',
        )
        .toList(growable: false);
    final transformedBlock = transformedLines.join('\n');
    final nextText =
        '${text.substring(0, startLineIndex)}$transformedBlock${text.substring(blockEnd)}';
    final delta = transformedBlock.length - block.length;
    final nextSelection = TextSelection(
      baseOffset: selection.baseOffset,
      extentOffset: selection.extentOffset + delta,
    );
    _applyEditorText(nextText, nextSelection);
  }

  void _applyEditorText(String nextText, TextSelection nextSelection) {
    _syncingEditor = true;
    _editorController
      ..text = nextText
      ..selection = nextSelection;
    _syncingEditor = false;
    widget.controller.updateSceneContent(nextText);
    _editorFocusNode.requestFocus();
  }

  String? _selectedEditorText() {
    final selection = _editorController.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return null;
    }
    return selection.textInside(_editorController.text);
  }

  void _syncEditorIfNeeded() {
    final selectedScene = widget.controller.selectedScene;
    final selectedSceneId = selectedScene?.id;
    final selectedSceneContent = selectedScene?.content ?? '';

    final shouldResetText =
        selectedSceneId != _boundSceneId ||
        (!_editorFocusNode.hasFocus &&
            _editorController.text != selectedSceneContent);

    if (!shouldResetText) {
      return;
    }

    _syncingEditor = true;
    _editorController
      ..text = selectedSceneContent
      ..selection = TextSelection.collapsed(
        offset: selectedSceneContent.length,
      );
    _syncingEditor = false;
    _boundSceneId = selectedSceneId;
  }
}

class _BookTreeCard extends StatelessWidget {
  const _BookTreeCard({
    required this.book,
    required this.selectedSceneId,
    required this.activeBookId,
    required this.onSelectBook,
    required this.onAddPart,
    required this.onAddChapter,
    required this.onAddScene,
    required this.onSelectScene,
    required this.onRenameBook,
    required this.onRemoveBook,
    required this.onRenamePart,
    required this.onRenameChapter,
    required this.onRenameScene,
  });

  final Book book;
  final String? selectedSceneId;
  final String? activeBookId;
  final ValueChanged<String> onSelectBook;
  final VoidCallback onAddPart;
  final ValueChanged<String> onAddChapter;
  final ValueChanged<String> onAddScene;
  final ValueChanged<String> onSelectScene;
  final VoidCallback onRenameBook;
  final VoidCallback onRemoveBook;
  final ValueChanged<BookPart> onRenamePart;
  final ValueChanged<Chapter> onRenameChapter;
  final ValueChanged<Scene> onRenameScene;

  @override
  Widget build(BuildContext context) {
    final isActive = activeBookId == book.id;
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: ExpansionTile(
        initiallyExpanded: isActive,
        title: Text(
          book.title,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: Text('${book.parts.length} part(s)'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Activate book',
              onPressed: () => onSelectBook(book.id),
              icon: const Icon(Icons.bookmark_outline),
            ),
            IconButton(
              tooltip: 'Add part',
              onPressed: isActive ? onAddPart : null,
              icon: const Icon(Icons.add),
            ),
            PopupMenuButton<_BookAction>(
              tooltip: 'Book actions',
              onSelected: (action) {
                switch (action) {
                  case _BookAction.rename:
                    onRenameBook();
                  case _BookAction.remove:
                    onRemoveBook();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<_BookAction>(
                  value: _BookAction.rename,
                  child: Text('Rename'),
                ),
                PopupMenuItem<_BookAction>(
                  value: _BookAction.remove,
                  child: Text('Remove'),
                ),
              ],
            ),
          ],
        ),
        children: [
          for (final part in book.parts)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
              child: ExpansionTile(
                title: Text(part.title),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Rename part',
                      onPressed: () => onRenamePart(part),
                      icon: const Icon(Icons.edit),
                    ),
                    IconButton(
                      tooltip: 'Add chapter',
                      onPressed: isActive ? () => onAddChapter(part.id) : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                children: [
                  for (final chapter in part.chapters)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 8,
                        right: 8,
                        bottom: 4,
                      ),
                      child: ExpansionTile(
                        title: Text(chapter.title),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Rename chapter',
                              onPressed: () => onRenameChapter(chapter),
                              icon: const Icon(Icons.edit),
                            ),
                            IconButton(
                              tooltip: 'Add scene',
                              onPressed: isActive
                                  ? () => onAddScene(chapter.id)
                                  : null,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        children: [
                          for (final scene in chapter.scenes)
                            ListTile(
                              dense: true,
                              title: Text(scene.title),
                              selected: selectedSceneId == scene.id,
                              onTap: () => onSelectScene(scene.id),
                              trailing: IconButton(
                                tooltip: 'Rename scene',
                                onPressed: () => onRenameScene(scene),
                                icon: const Icon(Icons.edit),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _BookAction { rename, remove }

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}
