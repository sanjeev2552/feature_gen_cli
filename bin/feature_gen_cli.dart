import 'package:args/args.dart';
import 'package:feature_gen_cli/command_helper.dart';
import 'package:feature_gen_cli/feature_gen.dart';

/// CLI entry point for the `feature_gen_cli` executable.
///
/// This function is intentionally small: it parses CLI flags, validates the
/// required positional args, and then delegates to [FeatureGen.generate].
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h')
    ..addFlag('version', abbr: 'v');

  final results = parser.parse(arguments);

  if (results['help']) {
    CommandHelper().help();
    return;
  }

  if (results['version']) {
    await CommandHelper().version();
    return;
  }

  if (results.rest.length < 2) {
    CommandHelper().error(
      'Usage: feature_gen_cli <feature_name> <schema.json>',
    );
    return;
  }

  await FeatureGen().generate(results);
}
