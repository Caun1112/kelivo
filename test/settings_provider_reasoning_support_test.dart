import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/model_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';

Future<void> _waitForSettingsLoad() async {
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider reasoning support', () {
    test('default Claude and OpenRouter presets do not add latest models', () {
      final claude = ProviderConfig.defaultsFor('Claude');
      final openRouter = ProviderConfig.defaultsFor('OpenRouter');

      expect(claude.models, isEmpty);
      expect(claude.modelOverrides, isEmpty);
      expect(openRouter.models, isEmpty);
      expect(openRouter.modelOverrides, isEmpty);
    });

    test('default Zhipu preset stays user-configured only', () {
      final zhipu = ProviderConfig.defaultsFor('Zhipu AI');

      expect(zhipu.baseUrl, 'https://open.bigmodel.cn/api/paas/v4');
      expect(zhipu.models, isEmpty);
      expect(zhipu.modelOverrides, isEmpty);
    });

    test('default Moonshot preset stays user-configured only', () {
      final moonshot = ProviderConfig.defaultsFor('Moonshot');

      expect(moonshot.baseUrl, 'https://api.moonshot.cn/v1');
      expect(moonshot.models, isEmpty);
      expect(moonshot.modelOverrides, isEmpty);
    });

    test(
      'built-in provider order drops unconfigured disabled presets',
      () async {
        SharedPreferences.setMockInitialValues({
          'providers_order_v1': <String>['OpenAI', 'Zhipu AI', 'Grok'],
        });
        final settings = SettingsProvider();

        await _waitForSettingsLoad();

        expect(settings.providersOrder, isNot(contains('Kimi')));
        expect(settings.providersOrder, isNot(contains('Zhipu AI')));
        expect(settings.providersOrder, isNot(contains('Grok')));
        expect(settings.providersOrder.first, 'OpenAI');
      },
    );

    test(
      'disabled built-in preset without user settings stays hidden',
      () async {
        final claude = ProviderConfig.defaultsFor(
          'Claude',
        ).copyWith(enabled: false);
        SharedPreferences.setMockInitialValues({
          'providers_order_v1': <String>['Claude'],
          'provider_configs_v1': jsonEncode({'Claude': claude.toJson()}),
        });
        final settings = SettingsProvider();

        await _waitForSettingsLoad();

        expect(settings.providersOrder, isNot(contains('Claude')));
        expect(settings.shouldShowProviderInSettingsList('Claude'), isFalse);
      },
    );

    test(
      'disabled built-in provider with user settings stays visible',
      () async {
        final claude = ProviderConfig.defaultsFor(
          'Claude',
        ).copyWith(enabled: false, apiKey: 'test-key');
        SharedPreferences.setMockInitialValues({
          'providers_order_v1': <String>['Claude'],
          'provider_configs_v1': jsonEncode({'Claude': claude.toJson()}),
        });
        final settings = SettingsProvider();

        await _waitForSettingsLoad();

        expect(settings.providersOrder, contains('Claude'));
        expect(settings.shouldShowProviderInSettingsList('Claude'), isTrue);
      },
    );

    test('disabled custom provider stays visible', () async {
      final custom = ProviderConfig(
        id: 'CustomProvider',
        enabled: false,
        name: 'Custom Provider',
        apiKey: '',
        baseUrl: 'https://example.test/v1',
        providerType: ProviderKind.openai,
      );
      SharedPreferences.setMockInitialValues({
        'providers_order_v1': <String>['CustomProvider'],
        'provider_configs_v1': jsonEncode({'CustomProvider': custom.toJson()}),
      });
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.providersOrder, contains('CustomProvider'));
      expect(
        settings.shouldShowProviderInSettingsList('CustomProvider'),
        isTrue,
      );
    });

    test('removing built-in provider without config hides it', () async {
      SharedPreferences.setMockInitialValues({
        'providers_order_v1': <String>['OpenAI'],
      });
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.removeProviderConfig('OpenAI');

      final removed = settings.providerConfigs['OpenAI'];
      expect(removed, isNotNull);
      expect(removed!.enabled, isFalse);
      expect(settings.providersOrder, isNot(contains('OpenAI')));
      expect(settings.shouldShowProviderInSettingsList('OpenAI'), isFalse);
    });

    test(
      'removing configured built-in provider clears user settings',
      () async {
        final openAI = ProviderConfig.defaultsFor('OpenAI').copyWith(
          apiKey: 'test-key',
          models: const ['gpt-test'],
          modelOverrides: const {
            'gpt-test': {'type': 'chat'},
          },
        );
        SharedPreferences.setMockInitialValues({
          'providers_order_v1': <String>['OpenAI'],
          'provider_configs_v1': jsonEncode({'OpenAI': openAI.toJson()}),
        });
        final settings = SettingsProvider();

        await _waitForSettingsLoad();
        await settings.removeProviderConfig('OpenAI');

        final removed = settings.providerConfigs['OpenAI'];
        expect(removed, isNotNull);
        expect(removed!.enabled, isFalse);
        expect(removed.apiKey, isEmpty);
        expect(removed.models, isEmpty);
        expect(removed.modelOverrides, isEmpty);
        expect(settings.providersOrder, isNot(contains('OpenAI')));
        expect(settings.shouldShowProviderInSettingsList('OpenAI'), isFalse);
      },
    );

    test('removing custom provider still deletes config', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      final custom = ProviderConfig(
        id: 'CustomProvider',
        enabled: true,
        name: 'Custom Provider',
        apiKey: 'test-key',
        baseUrl: 'https://example.test/v1',
        providerType: ProviderKind.openai,
      );

      await _waitForSettingsLoad();
      await settings.setProviderConfig('CustomProvider', custom);
      await settings.removeProviderConfig('CustomProvider');

      expect(settings.providerConfigs.containsKey('CustomProvider'), isFalse);
      expect(settings.providersOrder, isNot(contains('CustomProvider')));
    });

    test('latest GLM and Kimi model ids infer expected capabilities', () {
      final glm = ModelRegistry.infer(
        ModelInfo(id: 'glm-5.2', displayName: 'glm-5.2'),
      );
      final kimi = ModelRegistry.infer(
        ModelInfo(id: 'kimi-k2.7-code', displayName: 'kimi-k2.7-code'),
      );

      expect(glm.input, const [Modality.text]);
      expect(glm.output, const [Modality.text]);
      expect(
        glm.abilities,
        containsAll([ModelAbility.tool, ModelAbility.reasoning]),
      );
      expect(kimi.input, contains(Modality.image));
      expect(kimi.output, const [Modality.text]);
      expect(
        kimi.abilities,
        containsAll([ModelAbility.tool, ModelAbility.reasoning]),
      );
    });

    test('OpenRouter can be routed through Anthropic format explicitly', () {
      final cfg = ProviderConfig(
        id: 'OpenRouterAnthropic',
        enabled: true,
        name: 'OpenRouter Anthropic',
        apiKey: 'test-key',
        baseUrl: 'https://openrouter.ai/api',
        providerType: ProviderKind.claude,
        models: const ['anthropic/claude-fable-5'],
      );

      expect(
        ProviderConfig.classify(cfg.id, explicitType: cfg.providerType),
        ProviderKind.claude,
      );
    });

    test(
      'Claude provider resolves apiModelId before DeepSeek xhigh check',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsProvider();

        await _waitForSettingsLoad();
        await settings.setProviderConfig(
          'ClaudeProxy',
          ProviderConfig(
            id: 'ClaudeProxy',
            enabled: true,
            name: 'Claude Proxy',
            apiKey: 'test-key',
            baseUrl: 'https://proxy.example/anthropic',
            providerType: ProviderKind.claude,
            models: const ['pro-alias'],
            modelOverrides: const {
              'pro-alias': {
                'apiModelId': 'deepseek-v4-pro',
                'type': 'chat',
                'input': ['text'],
                'output': ['text'],
                'abilities': ['reasoning'],
              },
            },
          ),
        );

        expect(
          settings.supportsXhighReasoning('ClaudeProxy', 'pro-alias'),
          isTrue,
        );
      },
    );

    group('title generation thinking', () {
      test(
        'defaults to enabled and preserves existing budget fallback',
        () async {
          SharedPreferences.setMockInitialValues({'thinking_budget_v1': 16000});
          final settings = SettingsProvider();

          await _waitForSettingsLoad();

          expect(settings.titleGenerationThinkingEnabled, isTrue);
          expect(settings.titleGenerationThinkingBudgetFor(null), 16000);
          expect(settings.titleGenerationThinkingBudgetFor(1024), 1024);
        },
      );

      test(
        'disabled title generation thinking resolves to off budget',
        () async {
          SharedPreferences.setMockInitialValues({});
          final settings = SettingsProvider();

          await _waitForSettingsLoad();
          await settings.setThinkingBudget(16000);
          await settings.setTitleGenerationThinkingEnabled(false);

          expect(settings.titleGenerationThinkingEnabled, isFalse);
          expect(settings.titleGenerationThinkingBudgetFor(null), 0);
          expect(settings.titleGenerationThinkingBudgetFor(1024), 0);

          final prefs = await SharedPreferences.getInstance();
          expect(
            prefs.getBool('title_generation_thinking_enabled_v1'),
            isFalse,
          );
        },
      );

      test('loads persisted disabled state', () async {
        SharedPreferences.setMockInitialValues({
          'title_generation_thinking_enabled_v1': false,
        });
        final settings = SettingsProvider();

        await _waitForSettingsLoad();

        expect(settings.titleGenerationThinkingEnabled, isFalse);
        expect(settings.titleGenerationThinkingBudgetFor(32000), 0);
      });

      test('reset restores enabled fallback behavior', () async {
        SharedPreferences.setMockInitialValues({
          'title_generation_thinking_enabled_v1': false,
          'thinking_budget_v1': 64000,
        });
        final settings = SettingsProvider();

        await _waitForSettingsLoad();
        await settings.resetTitleGenerationThinkingEnabled();

        expect(settings.titleGenerationThinkingEnabled, isTrue);
        expect(settings.titleGenerationThinkingBudgetFor(null), 64000);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('title_generation_thinking_enabled_v1'), isTrue);
      });
    });

    test(
      'Claude latest models expose xhigh and max reasoning without presets',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsProvider();

        await _waitForSettingsLoad();
        await settings.setProviderConfig(
          'Claude',
          ProviderConfig(
            id: 'Claude',
            enabled: true,
            name: 'Claude',
            apiKey: 'test-key',
            baseUrl: 'https://api.anthropic.com/v1',
            providerType: ProviderKind.claude,
            models: const ['claude-fable-5', 'claude-opus-4-8'],
          ),
        );

        for (final model in const ['claude-fable-5', 'claude-opus-4-8']) {
          expect(settings.supportsXhighReasoning('Claude', model), isTrue);
          expect(settings.supportsMaxReasoning('Claude', model), isTrue);
        }
        expect(settings.getProviderConfig('Claude').models, [
          'claude-fable-5',
          'claude-opus-4-8',
        ]);
      },
    );

    test('OpenRouter Anthropic format exposes Claude max reasoning', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setProviderConfig(
        'OpenRouterAnthropic',
        ProviderConfig(
          id: 'OpenRouterAnthropic',
          enabled: true,
          name: 'OpenRouter Anthropic',
          apiKey: 'test-key',
          baseUrl: 'https://openrouter.ai/api/v1',
          providerType: ProviderKind.claude,
          models: const ['anthropic/claude-fable-5'],
        ),
      );

      expect(
        settings.supportsXhighReasoning(
          'OpenRouterAnthropic',
          'anthropic/claude-fable-5',
        ),
        isTrue,
      );
      expect(
        settings.supportsMaxReasoning(
          'OpenRouterAnthropic',
          'anthropic/claude-fable-5',
        ),
        isTrue,
      );
    });
  });
}
