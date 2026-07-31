library;

import 'dart:io';

import 'compile_config.dart';

void validateGraphqlCompileConfig(GraphqlCompileResolvedConfig config) {
  if (config.engine != 'sqlserver') {
    throw GraphqlCompileUsageError(
      'Unsupported --engine "${config.engine}". Supported values: sqlserver.',
    );
  }

  final sourceRoot = Directory(config.sourceRoot);
  if (!sourceRoot.existsSync()) {
    throw GraphqlCompileConfigError(
      'Invalid sourceRoot: directory not found at ${config.sourceRoot}',
    );
  }

  final metadataFile = File(config.metadataFile);
  if (!metadataFile.existsSync()) {
    throw GraphqlCompileConfigError(
      'Invalid metadata: file not found at ${config.metadataFile}',
    );
  }

  final outputFile = File(config.outputDirectory);
  if (outputFile.existsSync()) {
    throw GraphqlCompileConfigError(
      'Invalid output directory: file exists at ${config.outputDirectory}',
    );
  }

  Directory(config.outputDirectory).createSync(recursive: true);
}

class GraphqlCompileUsageError implements Exception {
  final String message;

  GraphqlCompileUsageError(this.message);

  @override
  String toString() => message;
}

class GraphqlCompileConfigError implements Exception {
  final String message;

  GraphqlCompileConfigError(this.message);

  @override
  String toString() => message;
}