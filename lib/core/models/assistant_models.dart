enum AiProviderType { ollama, openAi, gemini, perplexity, openRouter }

enum AssistantTask {
  rephrase,
  styleImprove,
  expand,
  summarize,
  spelling,
  punctuation,
  logicConsistency,
  coherence,
  structureSuggestion,
  ideaGeneration,
  characterAnalysis,
  plotAnalysis,
}

enum AssistantScope { selection, scene, chapter, book, conversation }

enum PageFormat { a5, a4, usLetter, compact }

extension AssistantTaskLabel on AssistantTask {
  String get label {
    switch (this) {
      case AssistantTask.rephrase:
        return 'Rephrase text';
      case AssistantTask.styleImprove:
        return 'Improve style';
      case AssistantTask.expand:
        return 'Expand text';
      case AssistantTask.summarize:
        return 'Summarize text';
      case AssistantTask.spelling:
        return 'Correct spelling';
      case AssistantTask.punctuation:
        return 'Correct punctuation';
      case AssistantTask.logicConsistency:
        return 'Check logic consistency';
      case AssistantTask.coherence:
        return 'Analyze coherence';
      case AssistantTask.structureSuggestion:
        return 'Suggest structure improvements';
      case AssistantTask.ideaGeneration:
        return 'Generate ideas';
      case AssistantTask.characterAnalysis:
        return 'Analyze characters';
      case AssistantTask.plotAnalysis:
        return 'Analyze plot';
    }
  }
}

extension AssistantScopeLabel on AssistantScope {
  String get label {
    switch (this) {
      case AssistantScope.selection:
        return 'Selection';
      case AssistantScope.scene:
        return 'Scene';
      case AssistantScope.chapter:
        return 'Chapter';
      case AssistantScope.book:
        return 'Book';
      case AssistantScope.conversation:
        return 'Conversation';
    }
  }
}

extension PageFormatLabel on PageFormat {
  String get label {
    switch (this) {
      case PageFormat.a5:
        return 'A5';
      case PageFormat.a4:
        return 'A4';
      case PageFormat.usLetter:
        return 'US Letter';
      case PageFormat.compact:
        return 'Compact (mobile)';
    }
  }

  int get symbolsPerPage {
    switch (this) {
      case PageFormat.a5:
        return 1700;
      case PageFormat.a4:
        return 2600;
      case PageFormat.usLetter:
        return 2500;
      case PageFormat.compact:
        return 1200;
    }
  }
}

extension AiProviderTypeLabel on AiProviderType {
  String get label {
    switch (this) {
      case AiProviderType.ollama:
        return 'Ollama (local)';
      case AiProviderType.openAi:
        return 'OpenAI';
      case AiProviderType.gemini:
        return 'Google Gemini';
      case AiProviderType.perplexity:
        return 'Perplexity';
      case AiProviderType.openRouter:
        return 'OpenRouter';
    }
  }
}

class ProviderSettings {
  const ProviderSettings({
    required this.provider,
    required this.defaultModel,
    this.endpoint,
    this.apiKeyAlias,
    this.enabled = false,
  });

  final AiProviderType provider;
  final String defaultModel;
  final String? endpoint;
  final String? apiKeyAlias;
  final bool enabled;

  ProviderSettings copyWith({
    String? defaultModel,
    String? endpoint,
    String? apiKeyAlias,
    bool? enabled,
  }) {
    return ProviderSettings(
      provider: provider,
      defaultModel: defaultModel ?? this.defaultModel,
      endpoint: endpoint ?? this.endpoint,
      apiKeyAlias: apiKeyAlias ?? this.apiKeyAlias,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider.name,
      'defaultModel': defaultModel,
      'endpoint': endpoint,
      'apiKeyAlias': apiKeyAlias,
      'enabled': enabled,
    };
  }

  static ProviderSettings fromJson(Map<String, dynamic> json) {
    final providerName =
        json['provider'] as String? ?? AiProviderType.ollama.name;
    final provider = AiProviderType.values.firstWhere(
      (item) => item.name == providerName,
      orElse: () => AiProviderType.ollama,
    );

    return ProviderSettings(
      provider: provider,
      defaultModel: json['defaultModel'] as String? ?? '',
      endpoint: json['endpoint'] as String?,
      apiKeyAlias: json['apiKeyAlias'] as String?,
      enabled: json['enabled'] as bool? ?? false,
    );
  }
}

class AssistantPreferences {
  const AssistantPreferences({
    required this.providers,
    required this.taskModelMapping,
    required this.defaultScope,
    required this.temperature,
    required this.maxTokens,
    this.pageFormat = PageFormat.a4,
    this.writingStyleGuidance = '',
  });

  final Map<AiProviderType, ProviderSettings> providers;
  final Map<AssistantTask, String> taskModelMapping;
  final AssistantScope defaultScope;
  final double temperature;
  final int maxTokens;
  final PageFormat pageFormat;
  final String writingStyleGuidance;

  AssistantPreferences copyWith({
    Map<AiProviderType, ProviderSettings>? providers,
    Map<AssistantTask, String>? taskModelMapping,
    AssistantScope? defaultScope,
    double? temperature,
    int? maxTokens,
    PageFormat? pageFormat,
    String? writingStyleGuidance,
  }) {
    return AssistantPreferences(
      providers: providers ?? this.providers,
      taskModelMapping: taskModelMapping ?? this.taskModelMapping,
      defaultScope: defaultScope ?? this.defaultScope,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      pageFormat: pageFormat ?? this.pageFormat,
      writingStyleGuidance: writingStyleGuidance ?? this.writingStyleGuidance,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'providers': {
        for (final entry in providers.entries)
          entry.key.name: entry.value.toJson(),
      },
      'taskModelMapping': {
        for (final entry in taskModelMapping.entries)
          entry.key.name: entry.value,
      },
      'defaultScope': defaultScope.name,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'pageFormat': pageFormat.name,
      'writingStyleGuidance': writingStyleGuidance,
    };
  }

  static AssistantPreferences fromJson(Map<String, dynamic> json) {
    final providersJson =
        json['providers'] as Map<String, dynamic>? ?? const {};
    final taskMappingJson =
        json['taskModelMapping'] as Map<String, dynamic>? ?? const {};

    final parsedProviders = <AiProviderType, ProviderSettings>{
      for (final provider in AiProviderType.values)
        provider: ProviderSettings(
          provider: provider,
          defaultModel: provider == AiProviderType.ollama
              ? 'llama3.1:8b'
              : 'gpt-4o-mini',
          endpoint: provider == AiProviderType.ollama
              ? 'http://127.0.0.1:11434'
              : null,
          enabled: provider == AiProviderType.ollama,
        ),
    };

    for (final entry in providersJson.entries) {
      final provider = AiProviderType.values.firstWhere(
        (item) => item.name == entry.key,
        orElse: () => AiProviderType.ollama,
      );
      final providerJson = entry.value;
      if (providerJson is Map<String, dynamic>) {
        parsedProviders[provider] = ProviderSettings.fromJson(providerJson);
      }
    }

    final parsedTaskMapping = <AssistantTask, String>{};
    for (final entry in taskMappingJson.entries) {
      final task = AssistantTask.values.firstWhere(
        (item) => item.name == entry.key,
        orElse: () => AssistantTask.rephrase,
      );
      parsedTaskMapping[task] = entry.value as String;
    }

    final scopeName =
        json['defaultScope'] as String? ?? AssistantScope.scene.name;
    final pageFormatName = json['pageFormat'] as String? ?? PageFormat.a4.name;

    return AssistantPreferences(
      providers: parsedProviders,
      taskModelMapping: parsedTaskMapping,
      defaultScope: AssistantScope.values.firstWhere(
        (item) => item.name == scopeName,
        orElse: () => AssistantScope.scene,
      ),
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: json['maxTokens'] as int? ?? 1000,
      pageFormat: PageFormat.values.firstWhere(
        (item) => item.name == pageFormatName,
        orElse: () => PageFormat.a4,
      ),
      writingStyleGuidance: json['writingStyleGuidance'] as String? ?? '',
    );
  }
}

class AssistantRequest {
  const AssistantRequest({
    required this.task,
    required this.scope,
    required this.content,
    required this.storyBible,
    required this.bookTitle,
    this.selection,
  });

  final AssistantTask task;
  final AssistantScope scope;
  final String content;
  final String storyBible;
  final String bookTitle;
  final String? selection;
}

class AssistantResponse {
  const AssistantResponse({
    required this.text,
    required this.provider,
    required this.model,
    required this.elapsed,
  });

  final String text;
  final AiProviderType provider;
  final String model;
  final Duration elapsed;
}
