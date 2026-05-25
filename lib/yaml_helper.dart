import 'dart:io';
import 'dart:isolate';

import 'package:feature_gen_cli/command_helper.dart';
import 'package:yaml/yaml.dart';

/// Reads metadata (version, project name, dependencies) from `pubspec.yaml` files.
///
/// This helper isolates YAML parsing so other classes can remain focused
/// on generation and CLI behavior. It reads the installed package pubspec
/// for version info and the target project pubspec for names/dependencies.
class YamlHelper {
  /// Creates a helper with an optional [CommandHelper] for consistent output.
  ///
  /// Provide a fake in tests to capture or suppress output.
  YamlHelper({CommandHelper? commandHelper}) : _commandHelper = commandHelper ?? CommandHelper();

  final CommandHelper _commandHelper;

  /// Returns the version of the `feature_gen_cli` package from its own pubspec.
  Future<String?> getVersion() async {
    final packageUri = Uri.parse('package:feature_gen_cli/');
    final libUri = await Isolate.resolvePackageUri(packageUri);

    if (libUri == null) {
      _commandHelper.error('Could not resolve package uri for package:feature_gen_cli');
      // error() exits the process; this return is a safety net for test doubles.
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
  /// Falls back to the directory name with a warning when parsing fails, so
  /// generation can continue rather than aborting the entire pipeline.
  Future<String> getProjectName({required String workingDirectory}) async {
    try {
      final content = await File('$workingDirectory/pubspec.yaml').readAsString();
      final doc = loadYaml(content) as YamlMap;
      final projectName = doc['name'] as String;

      return projectName;
    } catch (e) {
      final fallback = workingDirectory.split(Platform.pathSeparator).last;
      _commandHelper.warning(
        'Could not read project name from pubspec.yaml: $e\n'
        'Falling back to directory name: "$fallback".',
      );
      return fallback;
    }
  }

  /// Returns the `dependencies` and `dev_dependencies` maps from the target project's pubspec.
  ///
  /// Returns `(null, null)` with a warning if the pubspec cannot be read.
  Future<(YamlMap?, YamlMap?)> getDependencies({required String workingDirectory}) async {
    try {
      final content = await File('$workingDirectory/pubspec.yaml').readAsString();
      final doc = loadYaml(content) as YamlMap;
      final dependencies = doc['dependencies'] as YamlMap;
      final devDependencies = doc['dev_dependencies'] as YamlMap;

      return (dependencies, devDependencies);
    } catch (e) {
      _commandHelper.warning('Could not read dependencies from pubspec.yaml: $e');
      return (null, null);
    }
  }
}
