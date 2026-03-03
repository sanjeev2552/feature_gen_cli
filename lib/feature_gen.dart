import 'package:args/args.dart';
import 'package:feature_gen_cli/command_helper.dart';
import 'package:feature_gen_cli/command_runner.dart';
import 'package:feature_gen_cli/generator.dart';
import 'package:feature_gen_cli/parser.dart';

/// Orchestrates the full feature generation pipeline:
/// parse → deps → generate → build_runner → format.
///
/// The pipeline intentionally favors developer ergonomics:
/// it installs missing dependencies, generates code, runs build_runner,
/// and formats output so the project is ready to compile immediately.
class FeatureGen {
  /// Runs the complete pipeline using the parsed CLI [results].
  Future<void> generate(ArgResults results) async {
    final featureName = results.rest.first;
    CommandHelper().success('Generating feature: $featureName', shouldExit: false);

    try {
      // Parse the user's schema and translate it into a template context.
      final schema = Parser().parse(results.rest[1]);
      final context = await Parser().buildContext(featureName, schema);

      // Ensure required dependencies exist before generating files.
      await CommandRunner().checkAndAddDeps(
        config: context.config,
        workingDirectory: context.projectRoot,
      );

      // Generate feature files from mustache templates.
      await Generator().generateFeature(context);

      // Run code generation if needed (freezed/json_serializable).
      final exitCode = await CommandRunner().runBuildRunner(workingDirectory: context.projectRoot);
      if (exitCode != 0) {
        CommandHelper().warning(
          'build_runner failed. Run \'dart run build_runner build -d\' in your project manually.',
        );
      }

      // Format project files to keep output consistent.
      await CommandRunner().runFormat(workingDirectory: context.projectRoot);

      CommandHelper().success('Feature $featureName generated successfully');
    } catch (e, stack) {
      CommandHelper().error('Unexpected error: $e\n\n$stack');
    }
  }
}
