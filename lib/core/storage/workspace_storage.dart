import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/book_models.dart';

class WorkspaceStorage {
  WorkspaceStorage({this.baseDirectoryPath});

  final String? baseDirectoryPath;

  Future<String> rootDirectoryPath() async {
    return (await _rootDirectory()).path;
  }

  Future<WorkspaceData?> loadWorkspace() async {
    final file = await _workspaceFile();
    if (!file.existsSync()) {
      return null;
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return null;
    }

    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return WorkspaceData.fromJson(json);
  }

  Future<void> saveWorkspace(WorkspaceData workspace) async {
    final file = await _workspaceFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(workspace.toPrettyJson());
  }

  Future<WorkspaceData?> loadRecoverySnapshot() async {
    final file = await _recoveryFile();
    if (!file.existsSync()) {
      return null;
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return null;
    }
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return WorkspaceData.fromJson(json);
  }

  Future<void> saveRecoverySnapshot(WorkspaceData workspace) async {
    final file = await _recoveryFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(workspace.toPrettyJson());
  }

  Future<File> _workspaceFile() async {
    return File(p.join((await _rootDirectory()).path, 'workspace.json'));
  }

  Future<File> _recoveryFile() async {
    return File(
      p.join((await _rootDirectory()).path, 'recovery_snapshot.json'),
    );
  }

  Future<File> copyImageToWorkspace(String sourcePath) async {
    final root = await _rootDirectory();
    final imagesDir = Directory(p.join(root.path, 'images'));
    await imagesDir.create(recursive: true);

    final fileName = p.basename(sourcePath);
    final destinationPath = p.join(
      imagesDir.path,
      '${DateTime.now().millisecondsSinceEpoch}_$fileName',
    );
    final sourceFile = File(sourcePath);
    return sourceFile.copy(destinationPath);
  }

  Future<Directory> _rootDirectory() async {
    if (baseDirectoryPath != null) {
      return Directory(baseDirectoryPath!);
    }
    final supportDirectory = await getApplicationSupportDirectory();
    return Directory(p.join(supportDirectory.path, 'my_ai_book_writer'));
  }
}
