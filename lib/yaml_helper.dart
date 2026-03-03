import 'dart:io';
import 'dart:isolate';

import 'package:feature_gen_cli/command_helper.dart';
import 'package:yaml/yaml.dart';

/// Reads metadata (version, project name, dependencies) from `pubspec.yaml` files.
///
/// This helper isolates YAML parsing so other classes can remain focused
/// on generation and CLI behavior.
class YamlHelper {
  /// Returns the version of the `feature_gen_cli` package from its own pubspec.
  Future<String?> getVersion() async {
    final packageUri = Uri.parse('package:feature_gen_cli/');
    final libUri = await Isolate.resolvePackageUri(packageUri);

    if (libUri == null) {
      CommandHelper().error('Could not resolve package uri for package:feature_gen_cli');
      return null;
    }

    final pubspecUri = libUri.resolve('../pubspec.yaml');
    final content = await File.fromUri(pubspecUri).readAsString();
    final doc = loadYaml(content) as YamlMap;
    final version = doc['version'] as String;

    return version;
  }

  /// Returns the `name` field from the target project's pubspec.yaml.
  ///
  /// Falls back to the directory name when parsing fails.
  Future<String> getProjectName({required String workingDirectory}) async {
    try {
      final content = await File('$workingDirectory/pubspec.yaml').readAsString();
      final doc = loadYaml(content) as YamlMap;
      final projectName = doc['name'] as String;

      return projectName;
    } catch (e) {
      CommandHelper().error('Could not get project name: $e');
      return workingDirectory.split(Platform.pathSeparator).last;
    }
  }

  /// Returns the `dependencies` and `dev_dependencies` maps from the target project's pubspec.
  ///
  /// Returns `(null, null)` if the pubspec cannot be read.
  Future<(YamlMap?, YamlMap?)> getDependencies({required String workingDirectory}) async {
    try {
      final content = await File('$workingDirectory/pubspec.yaml').readAsString();
      final doc = loadYaml(content) as YamlMap;
      final dependencies = doc['dependencies'] as YamlMap;
      final devDependencies = doc['dev_dependencies'] as YamlMap;

      return (dependencies, devDependencies);
    } catch (e) {
      CommandHelper().error('Could not get dependencies: $e');
      return (null, null);
    }
  }
}
