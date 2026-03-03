import 'dart:io';

import 'package:feature_gen_cli/yaml_helper.dart';

/// Handles styled console output (errors, success, warnings) and CLI help/version.
///
/// This class centralizes formatting and exit behavior so the CLI stays
/// consistent and easy to maintain.
class CommandHelper {
  /// Prints a red error [message] and exits with code 1.
  void error(String message) {
    final error =
        '''
\x1B[31m$message\x1B[0m

\x1B[31mRun 'dart tool/feature_gen_cli.dart -h' for more information\x1B[0m''';

    stdout.writeln(error);
    exit(1);
  }

  /// Prints a green success [message].
  ///
  /// Exits with code 0 unless [shouldExit] is false (used for mid-pipeline logs).
  void success(String message, {bool shouldExit = true}) {
    final success = '\n\x1B[32m$message\x1B[0m\n';
    stdout.writeln(success);
    if (shouldExit) {
      exit(0);
    }
  }

  /// Prints a yellow warning [message] without exiting.
  void warning(String message) {
    final warning = '\n\x1B[33m$message\x1B[0m\n';
    stdout.writeln(warning);
  }

  /// Prints CLI usage information and exits.
  ///
  /// Keep this aligned with the actual CLI flags in `bin/feature_gen_cli.dart`.
  void help() {
    final helpInfo = '''
Manage your Flutter feature modules.

Common commands:

  dart tool/feature_gen_cli.dart <feature_name> <schema.json>
    Generate a new feature module using the provided feature name and schema definition.

Required parameters:

  <feature_name>:
    Name of the feature to generate.
    Must be lowercase and snake_case

  <schema.json>:
    Path to the JSON schema file.

Global options:
  -h, --help        Show this help message.
      --version:     Print the current version.
  
Example:
  dart tool/feature_gen_cli.dart example schema.json

Run 'dart tool/feature_gen_cli.dart -h' for more information''';

    stdout.writeln(helpInfo);
    exit(0);
  }

  /// Prints the package version from pubspec.yaml and exits.
  ///
  /// This reads the version from the installed package, not from a target project.
  Future<void> version() async {
    final version = await YamlHelper().getVersion();

    stdout.writeln(version);
    exit(0);
  }
}
