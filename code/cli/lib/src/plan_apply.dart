/// The `--plan` / `--apply` convention, in one place.
///
/// ADR 0007: every command that changes state must be told which of the two it
/// is doing. Neither is a default, and a bare invocation is an error.
///
/// This lives in `src/` rather than in a base class because the commands do not
/// share a hierarchy — they share a contract. Each declares [params], asks
/// [ChangeFlags.validate] for its usage error, and branches on [ChangeMode].
/// One list of flags, one validation, one place to change them.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

/// Which of the two things the caller asked for.
enum ChangeMode {
  /// Compute the change and write the plan file. Touch nothing else.
  plan,

  /// Compute the change, show it, take approval, apply.
  apply,
}

/// The three flags of the convention, parsed and validated together.
///
/// They are validated as a set because every rule spans more than one of them:
/// exactly one of `--plan` / `--apply`, and `--autoapprove` only alongside
/// `--apply`. A per-flag check could not see any of that.
class ChangeFlags {
  final bool plan;
  final bool apply;
  final bool autoapprove;

  const ChangeFlags({
    this.plan = false,
    this.apply = false,
    this.autoapprove = false,
  });

  factory ChangeFlags.fromCliRequest(CliRequest req) => ChangeFlags(
        plan: req.flagBool('plan'),
        apply: req.flagBool('apply'),
        autoapprove: req.flagBool('autoapprove'),
      );

  /// Declared on every mutating command, appended to its own parameters.
  ///
  /// `--plan` is declared. It used to be "the default, and so not declared",
  /// which is exactly what ADR 0007 removes: a default decides for the caller,
  /// and an undeclared flag cannot be typed even when every document says to.
  static final List<CliParam> params = [
    CliParam.boolean(
      'plan',
      description: 'Write the plan file; change nothing',
    ),
    CliParam.boolean(
      'apply',
      description: 'Show the plan, take approval, then apply it',
    ),
    CliParam.boolean(
      'autoapprove',
      description:
          'With --apply, apply without asking — for agents and CI, where '
          'nobody is at the keyboard to approve',
    ),
  ];

  /// The usage error, or null when the combination is legal.
  ///
  /// Returned from a command's `validate()`, so nothing is computed and no
  /// process is reached before the caller has said which of the two they meant.
  String? validate() {
    if (plan && apply) {
      return 'Choose one: --plan writes the plan file, --apply applies it. '
          'Passing both says nothing about which you meant.';
    }
    if (!plan && !apply) {
      return 'Choose --plan or --apply.\n'
          '  --plan   compute the change and write the plan file; '
          'nothing else is touched\n'
          '  --apply  show the change, ask for approval, then apply it\n'
          '\n'
          'Neither is the default: a command that changes things does not '
          'decide for you which one you wanted.';
    }
    if (autoapprove && !apply) {
      return '--autoapprove transfers an approval that only --apply asks for. '
          'On its own it authorizes nothing.';
    }
    return null;
  }

  /// Valid only once [validate] has returned null.
  ChangeMode get mode => plan ? ChangeMode.plan : ChangeMode.apply;
}

/// Asks a human whether the shown plan may be applied.
///
/// Injected so tests can answer without a terminal, and so the decision of
/// *how* to ask stays out of every command.
typedef Approver = Future<bool> Function(String renderedPlan);

/// The default [Approver]: prints the plan and reads one line from stdin.
///
/// When stdin is not a terminal there is nobody to answer, and blocking on a
/// read that will never return is the one failure mode ADR 0007's rule 4
/// exists to prevent. So it refuses instead of hanging, and names the flag
/// that resolves it. An agent that forgot `--autoapprove` gets a message; it
/// does not get a process that never exits.
class ConsoleApprover {
  final IOSink out;
  final bool Function() hasTerminal;
  final String Function() readLine;

  ConsoleApprover({
    IOSink? out,
    bool Function()? hasTerminal,
    String Function()? readLine,
  })  : out = out ?? stderr,
        hasTerminal = hasTerminal ?? (() => stdin.hasTerminal),
        readLine = readLine ?? (() => stdin.readLineSync() ?? '');

  Future<bool> call(String renderedPlan) async {
    out.writeln(renderedPlan);
    out.writeln();

    if (!hasTerminal()) {
      throw const NoApproverAvailable();
    }

    out.write('Apply this plan? [y/N] ');
    final answer = readLine().trim().toLowerCase();
    return answer == 'y' || answer == 'yes';
  }
}

/// Thrown when `--apply` needs an approval and no terminal can give one.
class NoApproverAvailable implements Exception {
  const NoApproverAvailable();

  String get message =>
      'No terminal to approve from. Pass --autoapprove to apply without '
      'asking — that is the invocation for agents and CI, and it records in '
      'the command line that the approval was given in advance.';

  @override
  String toString() => message;
}

/// What a command should do with a change it has computed.
///
/// Every mutating command asks the same three questions in the same order —
/// plan or apply, approved or not, approvable at all — so they are asked once
/// here rather than re-spelled in each command, where they could drift apart.
class ChangeDecision {
  /// True when the caller asked to apply and the approval was given.
  final bool proceed;

  /// Where the plan was written, when the caller asked for `--plan`.
  final String? planPath;

  /// What to tell the caller when [proceed] is false.
  final String? message;

  /// True when the command must exit non-zero: a refusal, or no way to ask.
  final bool blocked;

  const ChangeDecision({
    required this.proceed,
    this.planPath,
    this.message,
    this.blocked = false,
  });
}

/// Applies the convention to one computed change.
///
/// The command computes *what would change* and renders it once; this decides
/// what happens to that rendering. Keeping the two apart is what lets rule 6
/// hold — the plan shown by `--apply` and the plan written by `--plan` cannot
/// diverge, because there is only ever one of them.
class ChangeGate {
  final ChangeFlags flags;
  final Approver approver;
  final DateTime Function() now;

  ChangeGate({
    required this.flags,
    Approver? approver,
    DateTime Function()? now,
  })  : approver = approver ?? ConsoleApprover().call,
        now = now ?? DateTime.now;

  Future<ChangeDecision> decide({
    required String command,
    required String workingDirectory,
    required String body,
  }) async {
    if (flags.mode == ChangeMode.plan) {
      final path = PlanFile.write(
        workingDirectory: workingDirectory,
        command: command,
        body: body,
        now: now(),
      );
      return ChangeDecision(
        proceed: false,
        planPath: path,
        message: 'Plan — $body\n\n  written  $path',
      );
    }

    if (flags.autoapprove) return const ChangeDecision(proceed: true);

    try {
      final approved = await approver('Plan — $body');
      if (approved) return const ChangeDecision(proceed: true);
      return const ChangeDecision(
        proceed: false,
        message: 'Not applied. Nothing was changed.',
        blocked: true,
      );
    } on NoApproverAvailable catch (e) {
      return ChangeDecision(
        proceed: false,
        message: e.message,
        blocked: true,
      );
    }
  }
}

/// Writes the plan artifact under `.macss/plans/`.
///
/// The plan is the point of `--plan`: a preview that only ever existed as
/// terminal output could not be attached to an issue, diffed against a later
/// run, or read by someone who was not at the keyboard.
///
/// `.macss/` is the local workspace the CLI already owns and already
/// git-ignores. A plan records an intention, not history — committing plans
/// would leave a second, staler description of every change beside the change.
class PlanFile {
  /// Where plans live, relative to the directory the command works on.
  static const directory = '.macss/plans';

  /// Writes [body] as the plan for [command] and returns the path written.
  ///
  /// [now] is injected so the name is deterministic under test; the timestamp
  /// is what keeps successive plans for the same command from overwriting each
  /// other, which is what makes two runs comparable.
  static String write({
    required String workingDirectory,
    required String command,
    required String body,
    required DateTime now,
  }) {
    final dir = Directory(p.join(workingDirectory, p.joinAll(directory.split('/'))))
      ..createSync(recursive: true);

    final file = File(p.join(dir.path, '${_stamp(now)}-${_slug(command)}.md'));
    file.writeAsStringSync(render(command: command, body: body, now: now));
    return file.path;
  }

  /// The plan document, rendered.
  ///
  /// Written out in full rather than referring to the terminal that produced
  /// it: the reader of a plan is, by design, someone who did not run it.
  static String render({
    required String command,
    required String body,
    required DateTime now,
  }) =>
      [
        '# Plan — `macss $command`',
        '',
        '| | |',
        '| --- | --- |',
        '| Command | `macss $command --plan` |',
        '| Written | ${now.toIso8601String()} |',
        '',
        '## What would change',
        '',
        body.trim(),
        '',
        '---',
        '',
        'Nothing was changed. Re-run with `--apply` to apply this plan, or',
        '`--apply --autoapprove` where nobody is at the keyboard.',
        '',
      ].join('\n');

  static String _stamp(DateTime t) => [
        t.year.toString().padLeft(4, '0'),
        t.month.toString().padLeft(2, '0'),
        t.day.toString().padLeft(2, '0'),
        '-',
        t.hour.toString().padLeft(2, '0'),
        t.minute.toString().padLeft(2, '0'),
        t.second.toString().padLeft(2, '0'),
      ].join();

  static String _slug(String command) => command.trim().replaceAll(' ', '-');
}
