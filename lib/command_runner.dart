import 'dart:io';

import 'package:feature_gen_cli/command_helper.dart';
import 'package:feature_gen_cli/types.dart';
import 'package:feature_gen_cli/yaml_helper.dart';

/// Executes shell commands for dependency management, build_runner, and formatting.
///
/// All external process calls are funneled through this class so that
/// logging and error handling are consistent across the CLI.
class CommandRunner {
  /// Runs [executable] with [args] and forwards output. Returns the exit code.
  Future<int> _runCommand(String executable, List<String> args, {String? workingDirectory}) async {
    final result = await Process.run(executable, args, workingDirectory: workingDirectory);

    if ((result.stdout as String).isNotEmpty) {
      stdout.writeln(result.stdout);
    }
    if ((result.stderr as String).isNotEmpty) {
      stdout.writeln(result.stderr);
    }

    return result.exitCode;
  }

  /// Checks the target project for required dependencies and installs any missing ones.
  ///
  /// Dependencies are added via `dart pub add` to keep the project in a valid
  /// state (it updates `pubspec.yaml` and runs `pub get`). This includes
  /// packages needed for either bloc or riverpod generation.
  Future<void> checkAndAddDeps({required Config config, required String workingDirectory}) async {
    final requiredDependencies = [
      'get_it',
      'injectable',
      if (config.bloc == true) ...['flutter_bloc', 'bloc'],
      'equatable',
      'freezed_annotation',
      'json_annotation',
      if (config.riverpod == true) 'flutter_riverpod',
    ];
    const requiredDevDependencies = [
      'build_runner',
      'injectable_generator',
      'freezed',
      'json_serializable',
    ];

    try {
      final (dependencies, devDependencies) = await YamlHelper().getDependencies(
        workingDirectory: workingDirectory,
      );

      final installableDeps = <String>[];
      final installableDevDeps = <String>[];

      for (var dep in requiredDependencies) {
        if (dependencies == null || !dependencies.containsKey(dep)) {
          stdout.writeln('Adding $dep to dependencies');
          installableDeps.add(dep);
        }
      }

      for (var dep in requiredDevDependencies) {
        if (devDependencies == null || !devDependencies.containsKey(dep)) {
          stdout.writeln('Adding $dep to dev_dependencies');
          installableDevDeps.add('dev:$dep');
        }
      }

      if (installableDeps.isNotEmpty || installableDevDeps.isNotEmpty) {
        final exitCode = await _runCommand('dart', [
          'pub',
          'add',
          ...installableDeps,
          ...installableDevDeps,
        ], workingDirectory: workingDirectory);

        if (exitCode != 0) {
          CommandHelper().warning('Failed to add dependencies');
        } else {
          CommandHelper().success('Dependencies added successfully', shouldExit: false);
        }
      }
    } catch (e) {
      CommandHelper().warning('Could not check dependencies: $e');
    }
  }

  /// Runs `dart run build_runner build -d` in the target project.
  ///
  /// We return the exit code so the caller can decide whether to warn or abort.
  Future<int> runBuildRunner({required String workingDirectory}) async {
    stdout.writeln('');

    final buildExitCode = await _runCommand('dart', [
      'run',
      'build_runner',
      'build',
      '-d',
    ], workingDirectory: workingDirectory);

    if (buildExitCode != 0) {
      CommandHelper().warning('build_runner failed with exit code $buildExitCode');
      return buildExitCode;
    }

    return buildExitCode;
  }

  /// Runs `dart format .` in the target project.
  ///
  /// This keeps generated code aligned with standard Dart formatting.
  Future<void> runFormat({required String workingDirectory}) async {
    await _runCommand('dart', ['format', '.'], workingDirectory: workingDirectory);
  }
}
