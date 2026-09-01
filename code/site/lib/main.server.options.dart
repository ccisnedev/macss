// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/server.dart';
import 'package:design_system/src/command.dart' as _command;
import 'package:design_system/src/diagram.dart' as _diagram;
import 'package:design_system/src/layout.dart' as _layout;
import 'package:design_system/src/masthead.dart' as _masthead;
import 'package:design_system/src/rows.dart' as _rows;
import 'package:design_system/src/terminal.dart' as _terminal;
import 'package:macss_site/pages/modular_api.dart' as _modular_api;
import 'package:macss_site/sections/ecosystem.dart' as _ecosystem;
import 'package:macss_site/sections/install.dart' as _install;
import 'package:macss_site/sections/principles.dart' as _principles;
import 'package:macss_site/widgets/colophon.dart' as _colophon;

/// Default [ServerOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.server.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultServerOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ServerOptions get defaultServerOptions => ServerOptions(
  styles: () => [
    ..._command.Command.styles,
    ..._diagram.Diagram.styles,
    ..._layout.Band.styles,
    ..._layout.Listing.styles,
    ..._layout.Page.styles,
    ..._masthead.Masthead.styles,
    ..._rows.Rows.styles,
    ..._terminal.Terminal.styles,
    ..._modular_api.ModularApi.styles,
    ..._ecosystem.Ecosystem.styles,
    ..._install.Install.styles,
    ..._principles.Principles.styles,
    ..._colophon.Colophon.styles,
  ],
);
