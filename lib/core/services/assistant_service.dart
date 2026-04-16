import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/assistant_models.dart';
import '../storage/settings_storage.dart';

class AssistantService {
  AssistantService({
    required SettingsStorage settingsStorage,
    http.Client? client,
  }) : _settingsStorage = settingsStorage,
       _client = client ?? http.Client();

  final SettingsStorage _settingsStorage;
  final http.Client _client;

  Future<AssistantResponse> run({
    required AssistantPreferences preferences,
    required AssistantRequest request,
  }) async {
    final start = DateTime.now();
    final providerSettings = _selectProvider(preferences);

    final model =
        preferences.taskModelMapping[request.task]?.trim().isNotEmpty == true
        ? preferences.taskModelMapping[request.task]!.trim()
        : providerSettings.defaultModel;

    final endpoint = _resolveEndpoint(providerSettings);
    final apiKey = providerSettings.apiKeyAlias == null
        ? null
        : await _settingsStorage.loadApiKey(providerSettings.apiKeyAlias!);

    final prompt = _buildPrompt(preferences: preferences, request: request);

    final text = switch (providerSettings.provider) {
      AiProviderType.ollama => await _requestOllama(
        endpoint: endpoint,
        model: model,
        prompt: prompt,
        temperature: preferences.temperature,
      ),
      AiProviderType.openAi => await _requestOpenAiLike(
        endpoint: endpoint,
        model: model,
        prompt: prompt,
        temperature: preferences.temperature,
        maxTokens: preferences.maxTokens,
        apiKey: apiKey,
      ),
      AiProviderType.gemini => await _requestGemini(
        endpoint: endpoint,
        model: model,
        prompt: prompt,
        temperature: preferences.temperature,
        maxTokens: preferences.maxTokens,
        apiKey: apiKey,
      ),
      AiProviderType.perplexity => await _requestOpenAiLike(
        endpoint: endpoint,
        model: model,
        prompt: prompt,
        temperature: preferences.temperature,
        maxTokens: preferences.maxTokens,
        apiKey: apiKey,
      ),
      AiProviderType.openRouter => await _requestOpenAiLike(
        endpoint: endpoint,
        model: model,
        prompt: prompt,
        temperature: preferences.temperature,
        maxTokens: preferences.maxTokens,
        apiKey: apiKey,
        referer: 'https://github.com/open-source/my-ai-book-writer',
      ),
    };

    return AssistantResponse(
      text: text.trim(),
      provider: providerSettings.provider,
      model: model,
      elapsed: DateTime.now().difference(start),
    );
  }

  ProviderSettings _selectProvider(AssistantPreferences preferences) {
    final enabled = preferences.providers.values.where((item) => item.enabled);
    if (enabled.isEmpty) {
      return preferences.providers[AiProviderType.ollama] ??
          const ProviderSettings(
            provider: AiProviderType.ollama,
            defaultModel: 'llama3.1:8b',
            endpoint: 'http://127.0.0.1:11434',
            enabled: true,
          );
    }
    return enabled.first;
  }

  String _resolveEndpoint(ProviderSettings settings) {
    final configured = settings.endpoint?.trim() ?? '';
    if (configured.isNotEmpty) {
      return configured;
    }

    return switch (settings.provider) {
      AiProviderType.ollama => 'http://127.0.0.1:11434',
      AiProviderType.openAi => 'https://api.openai.com/v1',
      AiProviderType.gemini =>
        'https://generativelanguage.googleapis.com/v1beta',
      AiProviderType.perplexity => 'https://api.perplexity.ai',
      AiProviderType.openRouter => 'https://openrouter.ai/api/v1',
    };
  }

  String _buildPrompt({
    required AssistantPreferences preferences,
    required AssistantRequest request,
  }) {
    final scopeLabel = request.scope.label;
    final styleGuidance = preferences.writingStyleGuidance.trim();
    final noteContext = request.storyBible.trim();
    final selectedText = request.selection?.trim();

    return [
      'You are an AI writing assistant for fiction authors.',
      'Task: ${request.task.label}.',
      'Context scope: $scopeLabel.',
      if (styleGuidance.isNotEmpty) 'Preferred writing style: $styleGuidance',
      'Book title: ${request.bookTitle}',
      if (noteContext.isNotEmpty) 'Story bible notes:\n$noteContext',
      if (selectedText != null && selectedText.isNotEmpty)
        'Selected fragment:\n$selectedText',
      'Primary content:\n${request.content.trim()}',
      'Return practical writing output only, no disclaimers.',
    ].join('\n\n');
  }

  Future<String> _requestOllama({
    required String endpoint,
    required String model,
    required String prompt,
    required double temperature,
  }) async {
    final response = await _client.post(
      Uri.parse('$endpoint/api/generate'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': model,
        'prompt': prompt,
        'stream': false,
        'options': {'temperature': temperature},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AssistantServiceException(
        'Ollama request failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw const AssistantServiceException('Invalid Ollama response format.');
    }
    return json['response'] as String? ?? '';
  }

  Future<String> _requestOpenAiLike({
    required String endpoint,
    required String model,
    required String prompt,
    required double temperature,
    required int maxTokens,
    required String? apiKey,
    String? referer,
  }) async {
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AssistantServiceException(
        'Missing API key for selected provider. Configure it in Settings.',
      );
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    if (referer != null) {
      headers['HTTP-Referer'] = referer;
    }

    final response = await _client.post(
      Uri.parse('$endpoint/chat/completions'),
      headers: headers,
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': temperature,
        'max_tokens': maxTokens,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AssistantServiceException(
        'Provider request failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw const AssistantServiceException(
        'Invalid provider response format.',
      );
    }

    final choices = json['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          return message['content'] as String? ?? '';
        }
      }
    }
    return '';
  }

  Future<String> _requestGemini({
    required String endpoint,
    required String model,
    required String prompt,
    required double temperature,
    required int maxTokens,
    required String? apiKey,
  }) async {
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AssistantServiceException(
        'Missing Gemini API key. Configure it in Settings.',
      );
    }

    final response = await _client.post(
      Uri.parse('$endpoint/models/$model:generateContent?key=$apiKey'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': temperature,
          'maxOutputTokens': maxTokens,
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AssistantServiceException(
        'Gemini request failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw const AssistantServiceException('Invalid Gemini response format.');
    }
    final candidates = json['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final first = candidates.first;
      if (first is Map<String, dynamic>) {
        final content = first['content'];
        if (content is Map<String, dynamic>) {
          final parts = content['parts'];
          if (parts is List && parts.isNotEmpty) {
            final segment = parts.first;
            if (segment is Map<String, dynamic>) {
              return segment['text'] as String? ?? '';
            }
          }
        }
      }
    }
    return '';
  }
}

class AssistantServiceException implements Exception {
  const AssistantServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
