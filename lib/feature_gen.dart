import 'package:args/args.dart';
import 'package:feature_gen_cli/command_helper.dart';
import 'package:feature_gen_cli/command_runner.dart';
import 'package:feature_gen_cli/generator.dart';
import 'package:feature_gen_cli/parser.dart';

/// Orchestrates the full feature generation pipeline:
/// parse → deps → generate → build_runner → format.
///
/// The pipeline favors developer ergonomics: it installs missing dependencies,
/// generates code, runs build_runner, and formats output so the project is
/// ready to compile immediately. It uses the current working directory as the
/// target project root and reports errors through [CommandHelper].
class FeatureGen {
  /// Creates a generator pipeline with optional injected collaborators.
  ///
  /// Provide fakes in tests to avoid running real processes or touching disk.
  FeatureGen({
    Parser? parser,
    Generator? generator,
    CommandRunner? commandRunner,
    CommandHelper? commandHelper,
  })  : _parser = parser ?? Parser(),
        _generator = generator ?? Generator(),
        _commandRunner = commandRunner ?? CommandRunner(),
        _commandHelper = commandHelper ?? CommandHelper();

  final Parser _parser;
  final Generator _generator;
  final CommandRunner _commandRunner;
  final CommandHelper _commandHelper;

  /// Runs the complete pipeline using the parsed CLI [results].
  Future<void> generate(ArgResults results) async {
    final featureName = results.rest.first;
    _commandHelper.success('Generating feature: $featureName', shouldExit: false);
    final overwrite = results['overwrite'] == true;

    try {
      // Parse the user's schema and translate it into a template context.
      final schema = _parser.parse(results.rest[1]);
      final context = await _parser.buildContext(featureName, schema);

      // Ensure required dependencies exist before generating files.
      await _commandRunner.checkAndAddDeps(
        config: context.config,
        workingDirectory: context.projectRoot,
      );

      // Generate feature files from mustache templates.
      await _generator.generateFeature(context, overwrite: overwrite);

      // Run code generation if needed (freezed/json_serializable).
      final exitCode = await _commandRunner.runBuildRunner(workingDirectory: context.projectRoot);
      if (exitCode != 0) {
        _commandHelper.warning(
          'build_runner failed. Run \'dart run build_runner build -d\' in your project manually.',
        );
      }

      // Format project files to keep output consistent.
      await _commandRunner.runFormat(
        featureName: featureName,
        workingDirectory: context.projectRoot,
      );

      _commandHelper.success('Feature $featureName generated successfully');
    } catch (e, stack) {
      _commandHelper.error('Unexpected error: $e\n\n$stack');
    }
  }
}
