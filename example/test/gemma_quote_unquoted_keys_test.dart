import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp_example/llm/gemma_adapter.dart';

void main() {
  group('quoteUnquotedObjectKeys', () {
    test('quotes bareword keys inside nested arguments object', () {
      const input =
          '{"toolName":"schedule_weekday_alarm","arguments":{hour:6,minute:0,weekdays:[1,2,3,4,5]}}';
      final output = quoteUnquotedObjectKeys(input);
      // Round-trip through jsonDecode to assert it is now valid JSON.
      final decoded = jsonDecode(output) as Map<String, dynamic>;
      expect(decoded['toolName'], 'schedule_weekday_alarm');
      final args = decoded['arguments'] as Map<String, dynamic>;
      expect(args['hour'], 6);
      expect(args['minute'], 0);
      expect(args['weekdays'], [1, 2, 3, 4, 5]);
    });

    test('leaves already-quoted keys untouched', () {
      const input = '{"toolName":"x","arguments":{"hour":6,"minute":0}}';
      expect(quoteUnquotedObjectKeys(input), input);
    });

    test('does not quote bareword values after a colon', () {
      // true/false/null are valid JSON literals that sit in VALUE positions
      // (after `:`), so the regex must not match them.
      const input = '{"flag":true,"count":null,"ratio":false}';
      expect(quoteUnquotedObjectKeys(input), input);
      final decoded = jsonDecode(quoteUnquotedObjectKeys(input));
      expect(decoded, {'flag': true, 'count': null, 'ratio': false});
    });

    test('handles mixed quoted + unquoted keys in the same object', () {
      const input = '{"a":1,b:2,"c":3,d:"x"}';
      final decoded = jsonDecode(quoteUnquotedObjectKeys(input));
      expect(decoded, {'a': 1, 'b': 2, 'c': 3, 'd': 'x'});
    });
  });
}
