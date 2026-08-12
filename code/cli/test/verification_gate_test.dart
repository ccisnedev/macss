/// The verification gate — coverage and shape, never truth.
library;

import 'package:test/test.dart';

import 'package:macss_cli/modules/verification/verification_gate.dart';

void main() {
  const gate = VerificationGate();

  List<String> codesFor(String md, {List<String> criteria = const ['US1-AC1']}) =>
      gate
          .evaluate(md, criteria: criteria)
          .violations
          .map((v) => v.code)
          .toList();

  test('a walked record with a conclusion passes', () {
    expect(codesFor(_walked), isEmpty);
  });

  /// A criterion nobody judged is not the same as one that held, and a record
  /// missing it reads as if it were.
  test('a criterion the contract declares and the record drops', () {
    expect(codesFor(_walked, criteria: ['US1-AC1', 'US2-AC4']),
        contains('VERIFICATION_AC_MISSING'));
  });

  test('an entry still carrying the placeholder is not judged', () {
    expect(codesFor(_opened), contains('VERIFICATION_AC_UNJUDGED'));
  });

  /// The human writes the conclusion. Nothing here can compel that, but the
  /// gate can refuse to call a record finished without one.
  test('a record nobody concluded', () {
    expect(codesFor(_noConclusion), contains('VERIFICATION_NO_CONCLUSION'));
  });

  /// A rejection is a verdict. A gate that only accepted agreement would push
  /// the walk towards recording agreement.
  test('a rejection judges the criterion', () {
    expect(codesFor(_rejected), isEmpty);
  });
}

const _walked = '''
# Verification

## Criteria

### US1-AC1

- **Claim:** the state is shown
- **Evidence:** order_test.dart passes
- **Warrant:** the test asserts the rendered state
- **Not covered by this:** anything about latency
- **Judged:** accepted, in their words

## Conclusion

Accepted with the reservation above. — the human
''';

const _opened = '''
# Verification

## Criteria

### US1-AC1

- **Claim:** <!-- what this criterion says holds -->
- **Judged:** <!-- not yet judged -->

## Conclusion

Accepted. — the human
''';

const _noConclusion = '''
# Verification

## Criteria

### US1-AC1

- **Judged:** accepted

## Conclusion

<!-- The human writes this. -->
''';

const _rejected = '''
# Verification

## Criteria

### US1-AC1

- **Claim:** the state is shown
- **Evidence:** it renders the code, not the name
- **Judged:** rejected — this is not what was agreed

## Conclusion

Not accepted. Back to implementation. — the human
''';
