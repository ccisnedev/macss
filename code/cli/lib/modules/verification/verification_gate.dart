/// The `verification` gate — whether the record is a record.
///
/// Like every gate here it checks **coverage and shape, never truth**. It
/// cannot tell whether a verdict is honest or whether the evidence supports it;
/// what catches that is the person who wrote it, and that is where the
/// signature was placed on purpose (ADR 0008 §6).
///
/// The same shape ran once already, at `delivery check`, over the implementer's
/// claim. Here it is the verifier's judgement. Two documents, two acts, two
/// different people answering — not a rule applied twice.
library;

class VerificationViolation {
  final String code;
  final String message;

  const VerificationViolation(this.code, this.message);

  @override
  String toString() => '$code: $message';
}

class VerificationGateResult {
  final List<VerificationViolation> violations;

  const VerificationGateResult(this.violations);

  bool get passed => violations.isEmpty;
}

class VerificationGate {
  const VerificationGate();

  /// The placeholder `verification new` writes into every entry it opens.
  static const unjudged = 'not yet judged';

  VerificationGateResult evaluate(
    String verificationMd, {
    required List<String> criteria,
  }) {
    final violations = <VerificationViolation>[];
    final entries = _entries(verificationMd);

    final missing = criteria.where((id) => !entries.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      violations.add(VerificationViolation(
        'VERIFICATION_AC_MISSING',
        'The contract declares criteria this record does not carry: '
            '${missing.join(', ')}. A criterion nobody judged is not the same '
            'as one that held, and the record must not read as if it were.',
      ));
    }

    final unjudgedIds = criteria
        .where((id) =>
            entries.containsKey(id) && entries[id]!.contains(unjudged))
        .toList();
    if (unjudgedIds.isNotEmpty) {
      violations.add(VerificationViolation(
        'VERIFICATION_AC_UNJUDGED',
        'Still unjudged: ${unjudgedIds.join(', ')}. Anything the human '
            'rejected, accepted with reservations, or chose not to judge is a '
            'verdict — a record that only holds agreement is a record of '
            'nothing.',
      ));
    }

    if (!_hasConclusion(verificationMd)) {
      violations.add(const VerificationViolation(
        'VERIFICATION_NO_CONCLUSION',
        'No conclusion. It is the human who writes it: the accountability this '
            'rests on cannot be produced by a machine, and a verification '
            'somebody finished on their behalf is the rubber stamp arriving by '
            'a different door.',
      ));
    }

    return VerificationGateResult(violations);
  }

  /// The body of each `### US<n>-AC<m>` entry, by criterion id.
  Map<String, String> _entries(String md) {
    final entries = <String, String>{};
    String? current;
    final buffer = StringBuffer();

    void flush() {
      final id = current;
      if (id != null) entries[id] = buffer.toString();
      buffer.clear();
    }

    for (final line in md.split('\n')) {
      if (line.startsWith('#')) {
        flush();
        final heading = line.replaceFirst(RegExp(r'^#+\s*'), '').trim();
        current = _criterionId.hasMatch(heading) ? heading : null;
        continue;
      }
      if (current != null) buffer.writeln(line);
    }
    flush();
    return entries;
  }

  static final _criterionId = RegExp(r'^US\d+-AC\d+$');

  /// Whether the last section carries something real.
  ///
  /// Its heading is language-dependent, so this looks at the document's tail
  /// rather than at a word: the conclusion is the last thing written, and the
  /// template leaves it empty but for its own comment.
  bool _hasConclusion(String md) {
    final sections = md.split(RegExp(r'^## ', multiLine: true));
    if (sections.length < 2) return false;
    final last = sections.last
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
        .split('\n')
        .skip(1) // its own heading
        .join('\n')
        .trim();
    return last.isNotEmpty;
  }
}
