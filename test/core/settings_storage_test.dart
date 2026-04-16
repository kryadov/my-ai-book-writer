import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_book_writer/core/models/assistant_models.dart';
import 'package:my_ai_book_writer/core/storage/settings_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loads default preferences when storage is empty', () async {
    final storage = SettingsStorage();

    final preferences = await storage.loadAssistantPreferences();

    expect(preferences.providers[AiProviderType.ollama]?.enabled, isTrue);
    expect(preferences.defaultScope, AssistantScope.scene);
    expect(preferences.maxTokens, greaterThan(0));
    expect(preferences.pageFormat, PageFormat.a4);
  });

  test('saves and restores preferences plus API key', () async {
    final storage = SettingsStorage();
    final defaults = await storage.loadAssistantPreferences();
    final updated = defaults.copyWith(
      defaultScope: AssistantScope.book,
      temperature: 0.5,
      maxTokens: 1500,
      pageFormat: PageFormat.usLetter,
      writingStyleGuidance: 'Write with concise pacing.',
    );

    await storage.saveAssistantPreferences(updated);
    await storage.saveApiKey(alias: 'openAi', value: 'secret-key');

    final restored = await storage.loadAssistantPreferences();
    final apiKey = await storage.loadApiKey('openAi');

    expect(restored.defaultScope, AssistantScope.book);
    expect(restored.temperature, 0.5);
    expect(restored.maxTokens, 1500);
    expect(restored.pageFormat, PageFormat.usLetter);
    expect(restored.writingStyleGuidance, 'Write with concise pacing.');
    expect(apiKey, 'secret-key');
  });
}
