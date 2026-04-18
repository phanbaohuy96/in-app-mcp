import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp_example/main.dart';

void main() {
  testWidgets('renders full-screen chat and opens settings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey('chat-message-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-settings-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Models'), findsOneWidget);
    expect(find.byKey(const ValueKey('tool-policy-table')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tool-policy-row-schedule_weekday_alarm')),
      findsOneWidget,
    );
  });

  testWidgets('shows inline tool card first and executes only after run tap', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey('tool-call-result')), findsOneWidget);
    expect(find.text('No result yet.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('run-tool-call-button')));
    await tester.pumpAndSettle();

    expect(find.text('I can schedule that alarm for you.'), findsOneWidget);
    expect(find.text('Confirmation required'), findsWidgets);
    expect(find.text('Awaiting action'), findsWidgets);
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

    expect(find.text('Awaiting action'), findsNothing);
    expect(find.text('No result yet.'), findsNothing);
  });
}
