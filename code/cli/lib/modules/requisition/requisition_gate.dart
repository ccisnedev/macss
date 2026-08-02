/// The requisition gate — did the Product Owner actually fill the form?
///
/// The requisition is a form handed to the business: what problem this solves,
/// who it affects, what happens if it is not done, and how things work today
/// versus how they should work. This gate checks that those sections carry
/// something a person wrote, and nothing more.
///
/// It judges **presence, not quality**. No gate can tell a considered answer
/// from a pretty phrase. What catches vapour is the next stage: QA has to turn
/// the stated value into an observable signal, and value that cannot be
/// translated was never there.
///
/// Sections are found by their leading number, not their title, which is what
/// lets one gate serve every language — see `assets/vocabulary/`.
library;

/// One failed rule, with a stable [code] and a human-readable [message].
class RequisitionViolation {
  final String code;
  final String message;

  const RequisitionViolation(this.code, this.message);

  @override
  String toString() => '$code: $message';
}

class RequisitionGateResult {
  final List<RequisitionViolation> violations;

  const RequisitionGateResult(this.violations);

  bool get passed => violations.isEmpty;
}

class RequisitionGate {
  const RequisitionGate();

  RequisitionGateResult evaluate(String requisitionMd) {
    final sections = _splitSections(requisitionMd);

    return RequisitionGateResult([
      if (!_everyQuestionAnswered(sections['1']))
        const RequisitionViolation(
          'REQ_NO_VALUE',
          'Section "1." is unanswered — the request must say what problem it '
              'solves, who it affects, and what happens if it is not done.',
        ),
      if (!_isFilled(sections['2']))
        const RequisitionViolation(
          'REQ_NO_CURRENT_STATE',
          'Section "2." is empty — describe how it works today, or say that it '
              'does not exist yet.',
        ),
      if (!_isFilled(sections['3']))
        const RequisitionViolation(
          'REQ_NO_DESIRED_STATE',
          'Section "3." is empty — describe how it should work.',
        ),
    ]);
  }

  /// Whether **every** question in the value section has an answer under it.
  ///
  /// Checking the section as a whole would pass a form where the first question
  /// was answered and the rest abandoned — the most likely way a form gets
  /// half-filled.
  bool _everyQuestionAnswered(String? body) {
    if (body == null) return false;

    final lines = body.split('\n');
    final questionAt = [
      for (var i = 0; i < lines.length; i++)
        if (_isQuestionLabel(lines[i].trim())) i,
    ];
    if (questionAt.isEmpty) return _isFilled(body);

    for (var q = 0; q < questionAt.length; q++) {
      final end =
          q + 1 < questionAt.length ? questionAt[q + 1] : lines.length;
      final answer = lines.sublist(questionAt[q] + 1, end).join('\n');
      if (!_isFilled(answer)) return false;
    }
    return true;
  }

  /// Whether a section carries prose somebody wrote.
  ///
  /// Comments and example blockquotes are stripped first: the template ships an
  /// example under every question, so a form copied without being answered must
  /// not pass by virtue of the examples it came with.
  bool _isFilled(String? body) {
    if (body == null) return false;

    final prose = body
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .where((l) => !l.startsWith('>')) // example blockquotes
        .where((l) => !l.startsWith('#')) // sub-headings
        .where((l) => !l.startsWith('|')) // metadata tables
        .where((l) => !l.startsWith('- [ ]')) // unticked checkboxes
        .where((l) => !_isQuestionLabel(l))
        .join(' ')
        .trim();

    return prose.isNotEmpty;
  }

  /// `**¿Qué problema resuelve?**` — the printed question, not an answer.
  bool _isQuestionLabel(String line) =>
      line.startsWith('**') && line.endsWith('**');

  /// Section bodies keyed by their leading number.
  Map<String, String> _splitSections(String markdown) {
    final sections = <String, String>{};
    String? current;
    final buffer = StringBuffer();

    void flush() {
      if (current != null) sections[current] = buffer.toString();
      buffer.clear();
    }

    for (final line in markdown.split('\n')) {
      if (line.startsWith('## ')) {
        flush();
        final number = RegExp(r'^##\s+(\d+)\.').firstMatch(line);
        current = number?.group(1);
      } else if (current != null) {
        buffer.writeln(line);
      }
    }
    flush();

    return sections;
  }
}
