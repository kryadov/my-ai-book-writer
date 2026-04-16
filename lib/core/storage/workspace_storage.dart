import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/book_models.dart';

class WorkspaceStorage {
  WorkspaceStorage({this.baseDirectoryPath});

  final String? baseDirectoryPath;

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
    return File(
      '${(await _rootDirectory()).path}${Platform.pathSeparator}workspace.json',
    );
  }

  Future<File> _recoveryFile() async {
    return File(
      '${(await _rootDirectory()).path}${Platform.pathSeparator}recovery_snapshot.json',
    );
  }

  Future<Directory> _rootDirectory() async {
    if (baseDirectoryPath != null) {
      return Directory(baseDirectoryPath!);
    }
    final supportDirectory = await getApplicationSupportDirectory();
    return Directory(
      '${supportDirectory.path}${Platform.pathSeparator}my_ai_book_writer',
    );
  }
}
