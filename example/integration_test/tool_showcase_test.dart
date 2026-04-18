import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:in_app_mcp_example/main.dart';

// Captures one screenshot per tool by driving the real Gemma adapter on a
// booted iPhone simulator. Prompts are explicit about the tool name and
// required arguments to maximise Gemma's chance of producing a valid
// ToolCall on the first pass.
//
// The test prints [SCREENSHOT:<name>] markers on stdout; a parallel shell
// watcher drives xcrun simctl io booted screenshot off those markers.
//
// For the four side-effecting tools (alarm, calendar, maps, email) we capture
// the pending inline card, since tapping Run would escape the app into the
// OS. For echo (pure) we also capture the succeeded state.
//
// Run with:
//   flutter test -d <sim-id> integration_test/tool_showcase_test.dart \
//     --dart-define=LLM_ADAPTER=gemma \
//     --dart-define=GEMMA_MODEL_PATH=$PWD/model_cache/gemma-4-E2B-it.litertlm

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final spec in _showcaseSpecs) {
    testWidgets(
      'showcase: ${spec.screenshotName} (${spec.expectedTool})',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MyApp());

        // Wait for ModelManagerController to initialize and Gemma adapter to
        // become active. First load of the LiteRT-LM engine can take ~15 s.
        var adapterReady = false;
        for (var i = 0; i < 45; i++) {
          await tester.pump(const Duration(seconds: 1));
          if (find.textContaining('Adapter: gemma4').evaluate().isNotEmpty) {
            adapterReady = true;
            break;
          }
        }
        expect(
          adapterReady,
          isTrue,
          reason: 'Gemma adapter did not become active.',
        );

        await tester.enterText(
          find.byKey(const ValueKey('agent-prompt-input')),
          spec.prompt,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('run-tool-call-button')));

        // Gemma inference on simulator is slow; allow up to three minutes
        // for a tool-call proposal to land.
        Finder inlineCard = find.byWidgetPredicate(_isInlineCard);
        for (var i = 0; i < 180; i++) {
          await tester.pump(const Duration(seconds: 1));
          inlineCard = find.byWidgetPredicate(_isInlineCard);
          if (inlineCard.evaluate().isNotEmpty) break;
        }
        expect(
          inlineCard,
          findsOneWidget,
          reason: 'Gemma did not produce an inline tool-call card in time.',
        );

        // Verify Gemma picked the expected tool.
        expect(
          find.text(spec.expectedTool),
          findsOneWidget,
          reason: 'Gemma proposed a different tool than expected.',
        );

        // Dismiss keyboard so the card + Run button aren't covered.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        if (spec.runTool) {
          await tester.ensureVisible(
            find.byWidgetPredicate(_isInlineRunButton),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byWidgetPredicate(_isInlineRunButton));

          for (var i = 0; i < 15; i++) {
            await tester.pump(const Duration(seconds: 1));
            if (find.text('Succeeded').evaluate().isNotEmpty ||
                find.text('Failed').evaluate().isNotEmpty) {
              break;
            }
          }
          expect(
            find.text('Succeeded'),
            findsOneWidget,
            reason: 'Tool call did not reach Succeeded.',
          );
        }

        await tester.pump(const Duration(seconds: 2));
        // ignore: avoid_print
        print('[SCREENSHOT:${spec.screenshotName}]');
        await tester.pump(const Duration(seconds: 3));
      },
      timeout: const Timeout(Duration(minutes: 6)),
    );
  }
}

class _ShowcaseSpec {
  const _ShowcaseSpec({
    required this.expectedTool,
    required this.prompt,
    required this.screenshotName,
    this.runTool = false,
  });

  final String expectedTool;
  final String prompt;
  final String screenshotName;
  final bool runTool;
}

// Prompts are written as a user would phrase them — no tool names, no
// argument schemas. The point of the showcase is that Gemma *infers* which
// tool to call from natural language, not that it obeys when we hand it the
// answer. If Gemma picks a different tool than `expectedTool`, that's a
// legitimate outcome of real inference and the test surfaces it as a failure.
const _showcaseSpecs = <_ShowcaseSpec>[
  _ShowcaseSpec(
    expectedTool: 'schedule_weekday_alarm',
    prompt: 'Wake me up at 6 AM every weekday.',
    screenshotName: 'tool_schedule_weekday_alarm',
  ),
  _ShowcaseSpec(
    expectedTool: 'create_calendar_event',
    prompt:
        'Put a Team Sync meeting on my calendar tomorrow from 10 AM to '
        '11 AM at the Main Office.',
    screenshotName: 'tool_create_calendar_event',
  ),
  _ShowcaseSpec(
    expectedTool: 'open_map_directions',
    prompt: 'How do I drive to Tokyo?',
    screenshotName: 'tool_open_map_directions',
  ),
  _ShowcaseSpec(
    expectedTool: 'compose_email_draft',
    prompt:
        'Draft an email to team@example.com saying hello from the '
        'in_app_mcp demo.',
    screenshotName: 'tool_compose_email_draft',
  ),
  _ShowcaseSpec(
    expectedTool: 'echo',
    prompt: 'Echo back the phrase "hello from showcase".',
    screenshotName: 'tool_echo_pending',
  ),
  _ShowcaseSpec(
    expectedTool: 'echo',
    prompt: 'Echo back the phrase "hello from showcase".',
    screenshotName: 'tool_echo_succeeded',
    runTool: true,
  ),
];

bool _isInlineCard(Widget widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('inline-tool-call-card-');
}

bool _isInlineRunButton(Widget widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('inline-run-tool-call-button-');
}
