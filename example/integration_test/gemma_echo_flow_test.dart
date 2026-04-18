import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:in_app_mcp_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'gemma on iOS sim: prompt → tool call → run → success',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      // Wait for ModelManagerController to initialize and the Gemma adapter
      // to be selected (compile-time GEMMA_MODEL_PATH triggers this).
      var adapterReady = false;
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (find.textContaining('Adapter: gemma4').evaluate().isNotEmpty) {
          adapterReady = true;
          break;
        }
      }
      expect(adapterReady, isTrue, reason: 'Gemma adapter did not become active.');

      // Give the screenshotter a window to grab the home state.
      // ignore: avoid_print
      print('[SCREENSHOT:01_home_gemma_loaded]');
      await tester.pump(const Duration(seconds: 4));

      await tester.enterText(
        find.byKey(const ValueKey('agent-prompt-input')),
        'Use the echo tool to echo the message "hello from gemma".',
      );
      await tester.pump(const Duration(milliseconds: 200));
      // ignore: avoid_print
      print('[SCREENSHOT:02_prompt_entered]');
      await tester.pump(const Duration(seconds: 3));

      await tester.tap(find.byKey(const ValueKey('run-tool-call-button')));

      // Wait for Gemma to produce a tool-call proposal. Gemma inference on
      // simulator is slow; allow up to three minutes.
      Finder inlineCard = find.byWidgetPredicate(_isInlineCard);
      for (var i = 0; i < 180; i++) {
        await tester.pump(const Duration(seconds: 1));
        inlineCard = find.byWidgetPredicate(_isInlineCard);
        if (inlineCard.evaluate().isNotEmpty) break;
      }
      expect(
        inlineCard,
        findsOneWidget,
        reason: 'Gemma did not produce a tool call within the timeout.',
      );

      // Dismiss the software keyboard so the inline Run button isn't covered.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // ignore: avoid_print
      print('[SCREENSHOT:03_inline_card_pending]');
      await tester.pump(const Duration(seconds: 4));

      final inlineRun = find.byWidgetPredicate(_isInlineRunButton);
      expect(inlineRun, findsOneWidget);
      await tester.ensureVisible(inlineRun);
      await tester.pumpAndSettle();
      await tester.tap(inlineRun);

      // Handler runs locally — should settle fast.
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (find.text('Succeeded').evaluate().isNotEmpty ||
            find.text('Failed').evaluate().isNotEmpty) {
          break;
        }
      }

      // ignore: avoid_print
      print('[SCREENSHOT:04_run_result]');
      await tester.pump(const Duration(seconds: 4));

      expect(
        find.text('Succeeded'),
        findsOneWidget,
        reason: 'Tool call did not reach Succeeded state.',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

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
