import 'package:feature_gen_cli/cli_args.dart';
import 'package:feature_gen_cli/feature_gen.dart';
import 'package:feature_gen_cli/types.dart';
import 'package:test/test.dart';

import 'support/test_fakes.dart';

void main() {
  group('CLI overwrite flag', () {
    test('ArgParser includes overwrite flag with default false', () {
      final parser = buildArgParser();
      final results = parser.parse(['feature', 'schema.json']);
      expect(results['overwrite'], isFalse);
    });

    test('FeatureGen passes overwrite=true to Generator', () async {
      final parser = buildArgParser();
      final results = parser.parse(['--overwrite', 'feature', 'schema.json']);

      final context = Context(
        name: 'Feature',
        nameLowerCase: 'feature',
        nameCamelCase: 'feature',
        isList: false,
        fields: [NestedContextField(name: 'Feature', properties: [], isRoot: true)],
        methods: [],
        generateUseCase: false,
        projectRoot: '/tmp',
        projectName: 'sample_app',
        config: Config(bloc: true, riverpod: false),
      );

      final fakeGenerator = FakeGenerator();
      final fakeRunner = FakeCommandRunner();
      final featureGen = FeatureGen(
        parser: FakeParser(Schema(), context),
        generator: fakeGenerator,
        commandRunner: fakeRunner,
        commandHelper: TestCommandHelper(),
      );

      await featureGen.generate(results);
      expect(fakeGenerator.lastOverwrite, isTrue);
    });
  });
}
