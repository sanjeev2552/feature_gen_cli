import 'package:args/args.dart';

/// Builds the CLI argument parser used by the executable entrypoint.
ArgParser buildArgParser() {
  return ArgParser()
    ..addFlag('help', abbr: 'h')
    ..addFlag('overwrite', abbr: 'o', help: 'Overwrite existing generated files.')
    ..addFlag('version', abbr: 'v');
}
