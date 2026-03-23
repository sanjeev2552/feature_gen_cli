import 'package:feature_gen_cli/cli_args.dart';
import 'package:feature_gen_cli/command_helper.dart';
import 'package:feature_gen_cli/feature_gen.dart';

/// CLI entry point for the `feature_gen_cli` executable.
///
/// This entry point is intentionally small: it parses flags, validates the
/// required positional arguments, and then delegates to [FeatureGen.generate].
/// Run this from a Flutter project root so relative schema paths and
/// `pubspec.yaml` resolution work as expected.
Future<void> main(List<String> arguments) async {
  final parser = buildArgParser();

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
    CommandHelper().error('Usage: feature_gen_cli <feature_name> <schema.json>');
    return;
  }

  await FeatureGen().generate(results);
}
