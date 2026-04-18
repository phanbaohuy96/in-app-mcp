import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:in_app_mcp_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('codegen echo tool: prompt → inline card → run → success',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey('chat-message-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-prompt-input')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('agent-prompt-input')),
      'echo hello from integration test',
    );
    await tester.tap(find.byKey(const ValueKey('run-tool-call-button')));
    await tester.pumpAndSettle();

    expect(find.text('I can echo that for you.'), findsOneWidget);
    expect(find.text('Awaiting action'), findsOneWidget);
    expect(find.text('No result yet.'), findsOneWidget);

    final inlineRunButton = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith(
            'inline-run-tool-call-button-',
          ),
    );
    expect(inlineRunButton, findsOneWidget);

    await tester.tap(inlineRunButton);
    await tester.pumpAndSettle();

    expect(find.text('Succeeded'), findsOneWidget);
    expect(find.text('Echoed.'), findsOneWidget);
    expect(
      find.textContaining('"hello from integration test"'),
      findsWidgets,
    );
  });
}
