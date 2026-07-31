library;

import 'package:path/path.dart' as p;

import '../../../modules/api/graphql/commands/compile.dart';
import 'compile_config.dart';

class GraphqlCompileConfigResolver {
  static const defaultSourceRoot = 'code/db';
  static const defaultOutputDirectory = '.modular_api/graphql';
  static const defaultEngine = 'sqlserver';
  static const metadataFileName = 'graphql.metadata.jsonc';

  final Map<String, String> environment;

  const GraphqlCompileConfigResolver({this.environment = const {}});

  GraphqlCompileResolvedConfig resolve(GraphqlCompileInput input) {
    final rawSourceRoot =
        input.sourceRoot ?? environment['MACSS_API_GRAPHQL_SOURCE_ROOT'];
    final rawEngine = input.engine ?? environment['MACSS_API_GRAPHQL_ENGINE'];
    final sourceRoot = _resolvePath(
      rawSourceRoot ?? defaultSourceRoot,
      workingDirectory: input.workingDirectory,
    );

    final rawMetadata =
        input.metadataFile ?? environment['MACSS_API_GRAPHQL_METADATA'];
    final metadataFile = rawMetadata == null
        ? p.join(sourceRoot, metadataFileName)
        : _resolvePath(rawMetadata, workingDirectory: input.workingDirectory);

    final rawOutput =
        input.outputDirectory ?? environment['MACSS_API_GRAPHQL_OUTPUT'];
    final outputDirectory = _resolvePath(
      rawOutput ?? defaultOutputDirectory,
      workingDirectory: input.workingDirectory,
    );

    return GraphqlCompileResolvedConfig(
      sourceRoot: sourceRoot,
      metadataFile: metadataFile,
      outputDirectory: outputDirectory,
      engine: rawEngine ?? defaultEngine,
      workingDirectory: input.workingDirectory,
    );
  }

  String _resolvePath(String path, {required String workingDirectory}) {
    if (p.isAbsolute(path)) {
      return p.normalize(path);
    }
    return p.normalize(p.join(workingDirectory, path));
  }
}