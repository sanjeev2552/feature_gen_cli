import 'dart:io';

import 'package:feature_gen_cli/command_helper.dart';
import 'package:feature_gen_cli/command_runner.dart';
import 'package:feature_gen_cli/generator.dart';
import 'package:feature_gen_cli/parser.dart';
import 'package:feature_gen_cli/types.dart';
import 'package:feature_gen_cli/yaml_helper.dart';
import 'package:yaml/yaml.dart';

class TestCommandHelper extends CommandHelper {
  final List<String> errors = [];
  final List<String> warnings = [];
  final List<String> successes = [];

  @override
  void error(String message) {
    errors.add(message);
  }

  @override
  void warning(String message) {
    warnings.add(message);
  }

  @override
  void success(String message, {bool shouldExit = true}) {
    successes.add(message);
  }
}

class ThrowingCommandHelper extends CommandHelper {
  @override
  void error(String message) {
    throw StateError(message);
  }

  @override
  void warning(String message) {}

  @override
  void success(String message, {bool shouldExit = true}) {}
}

class FakeYamlHelper extends YamlHelper {
  FakeYamlHelper({this.dependencies, this.devDependencies});

  final Map<String, dynamic>? dependencies;
  final Map<String, dynamic>? devDependencies;

  @override
  Future<(YamlMap?, YamlMap?)> getDependencies({required String workingDirectory}) async {
    if (dependencies == null && devDependencies == null) {
      return (null, null);
    }

    final buffer = StringBuffer();
    if (dependencies != null) {
      if (dependencies!.isEmpty) {
        buffer.writeln('dependencies: {}');
      } else {
        buffer.writeln('dependencies:');
        dependencies!.forEach((key, value) {
          buffer.writeln('  $key: $value');
        });
      }
    }
    if (devDependencies != null) {
      if (devDependencies!.isEmpty) {
        buffer.writeln('dev_dependencies: {}');
      } else {
        buffer.writeln('dev_dependencies:');
        devDependencies!.forEach((key, value) {
          buffer.writeln('  $key: $value');
        });
      }
    }

    final doc = loadYaml(buffer.toString()) as YamlMap;
    final depMap = dependencies == null ? null : doc['dependencies'] as YamlMap;
    final devDepMap = devDependencies == null ? null : doc['dev_dependencies'] as YamlMap;
    return (depMap, devDepMap);
  }
}

class FakeProcessRunner {
  final List<(String, List<String>, String?)> calls = [];
  int exitCode = 0;

  Future<ProcessResult> call(
    String executable,
    List<String> args, {
    String? workingDirectory,
  }) async {
    calls.add((executable, args, workingDirectory));
    return ProcessResult(0, exitCode, '', '');
  }
}

class FakeParser extends Parser {
  FakeParser(this._schema, this._context) : super(commandHelper: TestCommandHelper());

  final Schema _schema;
  final Context _context;

  @override
  Schema parse(String path) => _schema;

  @override
  Future<Context> buildContext(String featureName, Schema schema) async => _context;
}

class FakeGenerator extends Generator {
  bool? lastOverwrite;
  Context? lastContext;

  @override
  Future<void> generateFeature(Context context, {bool overwrite = false}) async {
    lastContext = context;
    lastOverwrite = overwrite;
  }
}

class FakeCommandRunner extends CommandRunner {
  FakeCommandRunner() : super();

  bool checkDepsCalled = false;
  bool buildRunnerCalled = false;
  bool formatCalled = false;

  @override
  Future<void> checkAndAddDeps({required Config config, required String workingDirectory}) async {
    checkDepsCalled = true;
  }

  @override
  Future<int> runBuildRunner({required String workingDirectory}) async {
    buildRunnerCalled = true;
    return 0;
  }

  @override
  Future<void> runFormat({required String featureName, required String workingDirectory}) async {
    formatCalled = true;
  }
}
