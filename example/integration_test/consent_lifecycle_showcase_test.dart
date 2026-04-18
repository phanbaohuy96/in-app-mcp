import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp_example/main.dart';
import 'package:integration_test/integration_test.dart';

// Drives the full Consent Lifecycle UX (preview → grant menu → execute →
// undo → audit timeline) with the real Gemma adapter on a booted iPhone
// simulator. Prints `[SCREENSHOT:<name>]` markers on stdout at each key
// state; a parallel shell watcher drives `xcrun simctl io booted screenshot`
// off those markers to capture the PNGs used in the README.
//
// The echo tool is the lifecycle subject because it's pure (safe to Run
// inside the test) and ships a generated previewer + undoer via
// `@McpToolPreview` / `@McpToolUndo`.
//
// Run with:
//   flutter test -d <sim-id> integration_test/consent_lifecycle_showcase_test.dart \
//     --dart-define=LLM_ADAPTER=gemma \
//     --dart-define=GEMMA_MODEL_PATH=$PWD/model_cache/gemma-4-E2B-it.litertlm

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('consent lifecycle showcase (echo)', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Wait for Gemma adapter to become active (first LiteRT-LM load is slow).
    var adapterReady = false;
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (find.textContaining('Adapter: gemma4').evaluate().isNotEmpty) {
        adapterReady = true;
        break;
      }
    }
    expect(adapterReady, isTrue, reason: 'Gemma adapter did not become active.');

    // Natural-language prompt — no tool name, no argument schema. Gemma has
    // to infer that `echo` is the right tool.
    await tester.enterText(
      find.byKey(const ValueKey('agent-prompt-input')),
      'Echo back the phrase "hello from showcase".',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('run-tool-call-button')));

    // Up to three minutes for the first Gemma turn.
    Finder inlineCard = find.byWidgetPredicate(_isInlineCard);
    for (var i = 0; i < 180; i++) {
      await tester.pump(const Duration(seconds: 1));
      inlineCard = find.byWidgetPredicate(_isInlineCard);
      if (inlineCard.evaluate().isNotEmpty) break;
    }
    expect(inlineCard, findsOneWidget, reason: 'No inline tool card.');
    expect(find.text('echo'), findsOneWidget, reason: 'Unexpected tool.');

    // Confirm the preview section rendered (generated previewer fired).
    expect(
      find.textContaining('Would echo'),
      findsOneWidget,
      reason: 'Preview section did not render.',
    );

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    // --- Screenshot 1: card with preview visible, awaiting action.
    await tester.pump(const Duration(seconds: 2));
    _mark('consent_preview');
    await tester.pump(const Duration(seconds: 3));

    // --- Screenshot 2: grant submenu expanded.
    final grantMenu = find.byWidgetPredicate(_isGrantMenuButton);
    expect(grantMenu, findsOneWidget, reason: 'Grant menu button missing.');
    await tester.tap(grantMenu.first);
    // PopupMenuButton uses its own route; settle the menu animation.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Run + allow 5 min').evaluate().isNotEmpty) break;
    }
    expect(
      find.text('Run + allow 5 min'),
      findsOneWidget,
      reason: 'Grant submenu did not expand.',
    );
    await tester.pump(const Duration(seconds: 1));
    _mark('consent_grant_menu');
    await tester.pump(const Duration(seconds: 3));

    // Dismiss the popup by tapping "Run once" — also advances the flow.
    await tester.tap(find.text('Run once'));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (find.text('Succeeded').evaluate().isNotEmpty) break;
    }
    expect(
      find.text('Succeeded'),
      findsOneWidget,
      reason: 'Handler did not reach Succeeded.',
    );

    // --- Screenshot 3: succeeded state with Undo button visible.
    await tester.ensureVisible(find.byWidgetPredicate(_isUndoButton));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    _mark('consent_succeeded_with_undo');
    await tester.pump(const Duration(seconds: 3));

    // --- Screenshot 4: after Undo runs.
    await tester.tap(find.byWidgetPredicate(_isUndoButton));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (find.text('Undone').evaluate().isNotEmpty) break;
    }
    expect(
      find.text('Undone'),
      findsOneWidget,
      reason: 'Undo did not complete.',
    );
    await tester.pump(const Duration(seconds: 2));
    _mark('consent_undone');
    await tester.pump(const Duration(seconds: 3));

    // --- Screenshot 5: audit timeline screen.
    await tester.tap(
      find.byKey(const ValueKey('open-audit-timeline-button')),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    _mark('consent_audit_timeline');
    await tester.pump(const Duration(seconds: 3));
  }, timeout: const Timeout(Duration(minutes: 6)));
}

void _mark(String name) {
  // ignore: avoid_print
  print('[SCREENSHOT:$name]');
}

bool _isInlineCard(Widget widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('inline-tool-call-card-');
}

bool _isGrantMenuButton(Widget widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('inline-grant-menu-');
}

bool _isUndoButton(Widget widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('inline-undo-button-');
}
