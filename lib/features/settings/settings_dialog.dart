import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/assistant_models.dart';
import '../../core/services/app_controller.dart';
import '../import_export/import_export_service.dart';

Future<void> showAssistantSettingsDialog({
  required BuildContext context,
  required AppController controller,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _AssistantSettingsDialog(controller: controller),
  );
}

class _AssistantSettingsDialog extends StatefulWidget {
  const _AssistantSettingsDialog({required this.controller});

  final AppController controller;

  @override
  State<_AssistantSettingsDialog> createState() =>
      _AssistantSettingsDialogState();
}

class _AssistantSettingsDialogState extends State<_AssistantSettingsDialog> {
  late AssistantPreferences _draft;
  final Map<AiProviderType, TextEditingController> _modelControllers = {};
  final Map<AiProviderType, TextEditingController> _endpointControllers = {};
  final Map<AiProviderType, TextEditingController> _aliasControllers = {};
  final Map<AiProviderType, TextEditingController> _apiKeyControllers = {};
  late final TextEditingController _styleController;

  @override
  void initState() {
    super.initState();
    _draft = _clonePreferences(widget.controller.assistantPreferences);
    _styleController = TextEditingController(text: _draft.writingStyleGuidance);

    for (final provider in AiProviderType.values) {
      final settings = _draft.providers[provider]!;
      _modelControllers[provider] = TextEditingController(
        text: settings.defaultModel,
      );
      _endpointControllers[provider] = TextEditingController(
        text: settings.endpoint ?? '',
      );
      _aliasControllers[provider] = TextEditingController(
        text: settings.apiKeyAlias ?? provider.name,
      );
      _apiKeyControllers[provider] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _modelControllers.values) {
      controller.dispose();
    }
    for (final controller in _endpointControllers.values) {
      controller.dispose();
    }
    for (final controller in _aliasControllers.values) {
      controller.dispose();
    }
    for (final controller in _apiKeyControllers.values) {
      controller.dispose();
    }
    _styleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 920,
        height: 680,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBookSettingsCard(),
                    const SizedBox(height: 16),
                    const Text(
                      'Assistant',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _styleController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Writing style guidance',
                        hintText:
                            'Describe your preferred narrative voice, tone, and constraints.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Temperature: ${_draft.temperature.toStringAsFixed(2)}',
                    ),
                    Slider(
                      value: _draft.temperature,
                      max: 1.5,
                      min: 0,
                      divisions: 15,
                      label: _draft.temperature.toStringAsFixed(2),
                      onChanged: (value) {
                        setState(() {
                          _draft = _draft.copyWith(temperature: value);
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('Max tokens: ${_draft.maxTokens}'),
                    Slider(
                      value: _draft.maxTokens.toDouble(),
                      min: 128,
                      max: 4096,
                      divisions: 31,
                      label: _draft.maxTokens.toString(),
                      onChanged: (value) {
                        setState(() {
                          _draft = _draft.copyWith(maxTokens: value.round());
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    for (final provider in AiProviderType.values)
                      _buildProviderCard(context, provider),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Save settings'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookSettingsCard() {
    final activeBook = widget.controller.activeBook;
    final statistics = widget.controller.calculateBookStatistics(
      book: activeBook,
      pageFormat: _draft.pageFormat,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current book',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PageFormat>(
              initialValue: _draft.pageFormat,
              decoration: const InputDecoration(
                labelText: 'Page format',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final format in PageFormat.values)
                  DropdownMenuItem<PageFormat>(
                    value: format,
                    child: Text(
                      '${format.label} • ~${format.symbolsPerPage} symbols/page',
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _draft = _draft.copyWith(pageFormat: value);
                });
              },
            ),
            const SizedBox(height: 12),
            if (activeBook == null || statistics == null)
              const Text('No active book selected.')
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatisticChip(
                    label: 'Pages',
                    value: statistics.pages.toString(),
                  ),
                  _StatisticChip(
                    label: 'Parts',
                    value: statistics.parts.toString(),
                  ),
                  _StatisticChip(
                    label: 'Chapters',
                    value: statistics.chapters.toString(),
                  ),
                  _StatisticChip(
                    label: 'Symbols',
                    value: statistics.symbols.toString(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Preview',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(widget.controller.activeBookPreview),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text(
              'Export and workspace',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: activeBook == null ? null : _exportActiveBookDocx,
              icon: const Icon(Icons.file_download),
              label: const Text('Export active book as DOCX...'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Workspace files are stored in:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            SelectableText(
              widget.controller.workspaceRootDirectoryPath ??
                  'Loading workspace path...',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: widget.controller.workspaceRootDirectoryPath == null
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: widget.controller.workspaceRootDirectoryPath!,
                          ),
                        );
                        if (!mounted) {
                          return;
                        }
                        _showInfo('Workspace path copied to clipboard.');
                      },
                child: const Text('Copy workspace path'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(BuildContext context, AiProviderType provider) {
    final settings = _draft.providers[provider]!;
    final endpointController = _endpointControllers[provider]!;
    final modelController = _modelControllers[provider]!;
    final aliasController = _aliasControllers[provider]!;
    final apiKeyController = _apiKeyControllers[provider]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    provider.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Switch(
                  value: settings.enabled,
                  onChanged: (value) {
                    setState(() {
                      _draft = _draft.copyWith(
                        providers: <AiProviderType, ProviderSettings>{
                          ..._draft.providers,
                          provider: settings.copyWith(enabled: value),
                        },
                      );
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: modelController,
              decoration: const InputDecoration(
                labelText: 'Default model',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: endpointController,
              decoration: const InputDecoration(
                labelText: 'Endpoint (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: aliasController,
              decoration: const InputDecoration(
                labelText: 'API key alias',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: apiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Store API key (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => _storeApiKey(provider),
                  child: const Text('Store key'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _storeApiKey(AiProviderType provider) async {
    final alias = _aliasControllers[provider]!.text.trim();
    final keyValue = _apiKeyControllers[provider]!.text.trim();
    if (alias.isEmpty || keyValue.isEmpty) {
      return;
    }

    await widget.controller.saveApiKey(alias: alias, value: keyValue);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved API key for ${provider.label} using alias "$alias".',
        ),
      ),
    );
    _apiKeyControllers[provider]!.clear();
  }

  Future<void> _exportActiveBookDocx() async {
    final book = widget.controller.activeBook;
    if (book == null) {
      _showInfo('No active book selected.');
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
            child: TextField(
              controller: pathController,
              decoration: const InputDecoration(
                labelText: 'DOCX output path',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(pathController.text),
              child: const Text('Export DOCX'),
            ),
          ],
        );
      },
    );
    pathController.dispose();

    if (path == null || path.trim().isEmpty) {
      return;
    }

    try {
      final output = File(path.trim());
      await output.parent.create(recursive: true);
      await widget.controller.exportToPath(
        filePath: output.path,
        content: widget.controller.activeBookExportContent,
        format: ExportFormat.docx,
      );
      if (!mounted) {
        return;
      }
      _showInfo('DOCX exported to: ${output.path}');
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      _showInfo('Export failed: $error');
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

  Future<void> _save() async {
    var providers = <AiProviderType, ProviderSettings>{..._draft.providers};

    for (final provider in AiProviderType.values) {
      final current = providers[provider]!;
      providers[provider] = current.copyWith(
        defaultModel: _modelControllers[provider]!.text.trim(),
        endpoint: _endpointControllers[provider]!.text.trim(),
        apiKeyAlias: _aliasControllers[provider]!.text.trim(),
      );
    }

    final enabledCount = providers.values
        .where((value) => value.enabled)
        .length;
    if (enabledCount == 0) {
      providers = {
        ...providers,
        AiProviderType.ollama: providers[AiProviderType.ollama]!.copyWith(
          enabled: true,
        ),
      };
    }

    final next = _draft.copyWith(
      providers: providers,
      writingStyleGuidance: _styleController.text.trim(),
    );

    await widget.controller.updateAssistantPreferences(next);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  AssistantPreferences _clonePreferences(AssistantPreferences source) {
    return AssistantPreferences(
      providers: {
        for (final entry in source.providers.entries)
          entry.key: entry.value.copyWith(),
      },
      taskModelMapping: {...source.taskModelMapping},
      defaultScope: source.defaultScope,
      temperature: source.temperature,
      maxTokens: source.maxTokens,
      pageFormat: source.pageFormat,
      writingStyleGuidance: source.writingStyleGuidance,
    );
  }
}

class _StatisticChip extends StatelessWidget {
  const _StatisticChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Text(value),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
