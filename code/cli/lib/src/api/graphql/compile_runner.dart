library;

import 'dart:io';

import 'package:modular_api/modular_api.dart';
import 'package:modular_api_sqlserver/modular_api_sqlserver.dart';

import 'compile_config.dart';

typedef GraphqlCompilePhysicalCatalogLoader =
    Future<PhysicalCatalog> Function(GraphqlCompileResolvedConfig config);

abstract interface class GraphqlCompileRunner {
  Future<GraphqlCompileRunResult> run(GraphqlCompileResolvedConfig config);
}

final class GraphqlCompileRunResult {
  final String message;
  final GraphqlCompileResolvedConfig? resolvedConfig;

  const GraphqlCompileRunResult({
    required this.message,
    this.resolvedConfig,
  });
}

final class GraphqlCompileExecutionError implements Exception {
  final String message;
  final bool hasBlockingDiagnostics;

  const GraphqlCompileExecutionError._({
    required this.message,
    required this.hasBlockingDiagnostics,
  });

  const GraphqlCompileExecutionError.blockingDiagnostics(String message)
    : this._(message: message, hasBlockingDiagnostics: true);

  const GraphqlCompileExecutionError.unexpected(String message)
    : this._(message: message, hasBlockingDiagnostics: false);

  @override
  String toString() => message;
}

final class ModularApiGraphqlCompileRunner implements GraphqlCompileRunner {
  final String providerVersion;
  final Map<String, String> environment;
  final GraphqlCompilePhysicalCatalogLoader? physicalCatalogLoader;
  final GraphqlMetadataParser metadataParser;
  final Future<String> Function(String path) metadataFileReader;

  ModularApiGraphqlCompileRunner({
    String? providerVersion,
    this.environment = const {},
    this.physicalCatalogLoader,
    GraphqlMetadataParser? metadataParser,
    Future<String> Function(String path)? metadataFileReader,
  }) : providerVersion = providerVersion ?? modularApiPackageVersion,
       metadataParser = metadataParser ?? const GraphqlMetadataParser(),
       metadataFileReader = metadataFileReader ?? _readMetadataFile;

  @override
  Future<GraphqlCompileRunResult> run(GraphqlCompileResolvedConfig config) async {
    try {
      final physicalCatalog = await _loadPhysicalCatalog(config);
      final rawMetadata = await metadataFileReader(config.metadataFile);
      final parseResult = metadataParser.parse(
        rawJsonc: rawMetadata,
        physicalCatalog: physicalCatalog,
      );
      final metadata =
          parseResult.metadata ?? const GraphqlMetadataFile(version: 1, objects: {});

      final builtCatalog = GraphqlCatalogBuilder(
        providerVersion: providerVersion,
        sourceRoot: config.sourceRoot,
        buildMode: GraphqlCatalogBuildMode.compile,
        engine: config.engine,
      ).build(
        physicalCatalog: physicalCatalog,
        metadata: metadata,
      );

      final catalog = _mergeMetadataDiagnostics(
        builtCatalog,
        parseResult.diagnostics,
      );

      try {
        await GraphqlArtifactCompiler(
          catalogFactory: () => catalog,
        ).writeToDirectory(config.outputDirectory);
      } on GraphqlArtifactCompileError catch (error) {
        throw GraphqlCompileExecutionError.blockingDiagnostics(
          'GraphQL compile emitted blocking diagnostics. Artifacts were written to ${config.outputDirectory}. ${error.message}',
        );
      }

      return GraphqlCompileRunResult(
        message: 'GraphQL artifacts written to ${config.outputDirectory}',
        resolvedConfig: config,
      );
    } on GraphqlCompileExecutionError {
      rethrow;
    } catch (error) {
      throw GraphqlCompileExecutionError.unexpected(
        'Unexpected GraphQL compile failure: $error',
      );
    }
  }

  Future<PhysicalCatalog> _loadPhysicalCatalog(
    GraphqlCompileResolvedConfig config,
  ) async {
    final customLoader = physicalCatalogLoader;
    if (customLoader != null) {
      return customLoader(config);
    }

    final connection = SqlServerConnectionSettings.fromEnvironment(
      environment: environment.isEmpty ? null : environment,
    );
    return SqlServerMetadataReader(connection: connection).introspect();
  }
}

Future<String> _readMetadataFile(String path) {
  return File(path).readAsString();
}

GraphqlCatalog _mergeMetadataDiagnostics(
  GraphqlCatalog catalog,
  List<GraphqlMetadataDiagnostic> metadataDiagnostics,
) {
  final merged = <GraphqlCatalogDiagnostic>[
    ...catalog.diagnostics,
    ...metadataDiagnostics.map(_toCatalogDiagnostic),
  ];

  final uniqueDiagnostics = <String, GraphqlCatalogDiagnostic>{};
  for (final diagnostic in merged) {
    final key = [
      diagnostic.severity.name,
      diagnostic.code,
      diagnostic.objectId ?? '',
      diagnostic.field ?? '',
      diagnostic.message,
    ].join('|');
    uniqueDiagnostics[key] = diagnostic;
  }

  final sortedDiagnostics = uniqueDiagnostics.values.toList(growable: false)
    ..sort((left, right) {
      final severity = left.severity.index.compareTo(right.severity.index);
      if (severity != 0) {
        return severity;
      }
      final code = left.code.compareTo(right.code);
      if (code != 0) {
        return code;
      }
      final objectId = (left.objectId ?? '').compareTo(right.objectId ?? '');
      if (objectId != 0) {
        return objectId;
      }
      final field = (left.field ?? '').compareTo(right.field ?? '');
      if (field != 0) {
        return field;
      }
      return left.message.compareTo(right.message);
    });

  return GraphqlCatalog(
    catalogVersion: catalog.catalogVersion,
    provider: catalog.provider,
    build: catalog.build,
    objects: catalog.objects,
    diagnostics: List<GraphqlCatalogDiagnostic>.unmodifiable(sortedDiagnostics),
  );
}

GraphqlCatalogDiagnostic _toCatalogDiagnostic(GraphqlMetadataDiagnostic diagnostic) {
  return GraphqlCatalogDiagnostic(
    severity: diagnostic.severity == GraphqlMetadataSeverity.error
        ? GraphqlCatalogDiagnosticSeverity.error
        : GraphqlCatalogDiagnosticSeverity.warning,
    code: diagnostic.code,
    message: diagnostic.message,
    objectId: diagnostic.objectId,
    field: diagnostic.field,
  );
}