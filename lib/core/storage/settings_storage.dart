import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/assistant_models.dart';

class SettingsStorage {
  SettingsStorage({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _preferencesKey = 'assistant_preferences_v1';
  static const String _apiKeyPrefix = 'api_key_';

  SharedPreferences? _preferences;

  Future<AssistantPreferences> loadAssistantPreferences() async {
    final preferences = await _prefs();
    final raw = preferences.getString(_preferencesKey);
    if (raw == null || raw.trim().isEmpty) {
      return _defaultPreferences();
    }

    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      return _defaultPreferences();
    }

    return AssistantPreferences.fromJson(json);
  }

  Future<void> saveAssistantPreferences(
    AssistantPreferences preferences,
  ) async {
    final prefs = await _prefs();
    await prefs.setString(_preferencesKey, jsonEncode(preferences.toJson()));
  }

  Future<void> saveApiKey({
    required String alias,
    required String value,
  }) async {
    final prefs = await _prefs();
    await prefs.setString('$_apiKeyPrefix$alias', value);
  }

  Future<String?> loadApiKey(String alias) async {
    final prefs = await _prefs();
    return prefs.getString('$_apiKeyPrefix$alias');
  }

  Future<SharedPreferences> _prefs() async {
    _preferences ??= await SharedPreferences.getInstance();
    return _preferences!;
  }

  AssistantPreferences _defaultPreferences() {
    final providers = <AiProviderType, ProviderSettings>{
      for (final provider in AiProviderType.values)
        provider: ProviderSettings(
          provider: provider,
          defaultModel: switch (provider) {
            AiProviderType.ollama => 'llama3.1:8b',
            AiProviderType.openAi => 'gpt-4o-mini',
            AiProviderType.gemini => 'gemini-2.0-flash',
            AiProviderType.perplexity => 'sonar',
            AiProviderType.openRouter => 'openai/gpt-4o-mini',
          },
          endpoint: provider == AiProviderType.ollama
              ? 'http://127.0.0.1:11434'
              : null,
          apiKeyAlias: provider == AiProviderType.ollama ? null : provider.name,
          enabled: provider == AiProviderType.ollama,
        ),
    };

    return AssistantPreferences(
      providers: providers,
      taskModelMapping: const <AssistantTask, String>{},
      defaultScope: AssistantScope.scene,
      temperature: 0.7,
      maxTokens: 1000,
      pageFormat: PageFormat.a4,
      writingStyleGuidance: 'Keep prose vivid, coherent, and character-driven.',
    );
  }
}
