import 'package:flutter/material.dart';

import '../../core/models/assistant_models.dart';
import '../../core/services/app_controller.dart';

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
                      'Assistant Settings',
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
      writingStyleGuidance: source.writingStyleGuidance,
    );
  }
}
