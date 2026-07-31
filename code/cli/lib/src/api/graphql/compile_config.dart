library;

class GraphqlCompileResolvedConfig {
  final String sourceRoot;
  final String metadataFile;
  final String outputDirectory;
  final String engine;
  final String workingDirectory;

  const GraphqlCompileResolvedConfig({
    required this.sourceRoot,
    required this.metadataFile,
    required this.outputDirectory,
    required this.engine,
    required this.workingDirectory,
  });

  Map<String, dynamic> toJson() => {
    'sourceRoot': sourceRoot,
    'metadataFile': metadataFile,
    'outputDirectory': outputDirectory,
    'engine': engine,
    'workingDirectory': workingDirectory,
  };

  @override
  bool operator ==(Object other) {
    return other is GraphqlCompileResolvedConfig &&
        other.sourceRoot == sourceRoot &&
        other.metadataFile == metadataFile &&
        other.outputDirectory == outputDirectory &&
        other.engine == engine &&
        other.workingDirectory == workingDirectory;
  }

  @override
  int get hashCode => Object.hash(
    sourceRoot,
    metadataFile,
    outputDirectory,
    engine,
    workingDirectory,
  );
}