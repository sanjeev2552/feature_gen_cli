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
        fields: [
          NestedContextField(name: 'Feature', properties: [], isRoot: true),
        ],
        methods: [],
        generateUseCase: false,
        projectRoot: '/tmp',
        projectName: 'sample_app',
        config: const Config(layer: PresentationLayer.bloc),
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

  group('FeatureGen.generate error handling', () {
    for (final failDependencies in [true, false]) {
      test(
        'reports failure and stops after ${failDependencies ? 'dependencies' : 'build_runner'} fails',
        () async {
          final helper = TestCommandHelper();
          final runner = FakeCommandRunner()
            ..failDependencies = failDependencies
            ..buildExitCode = 1;
          final generator = FakeGenerator();
          final featureGen = FeatureGen(
            parser: FakeParser(Schema(), _ThrowingParser._dummyContext()),
            generator: generator,
            commandRunner: runner,
            commandHelper: helper,
          );
          await featureGen.generate(
            buildArgParser().parse(['feature', 'schema.json']),
          );
          expect(helper.errors, hasLength(1));
          expect(
            helper.successes.any(
              (message) => message.contains('generated successfully'),
            ),
            isFalse,
          );
          expect(runner.formatCalled, isFalse);
          expect(runner.buildRunnerCalled, !failDependencies);
          expect(generator.lastContext, failDependencies ? isNull : isNotNull);
        },
      );
    }
    test('surfaces error message when parser throws', () async {
      final argParser = buildArgParser();
      final results = argParser.parse(['feature', 'schema.json']);

      final commandHelper = TestCommandHelper();

      /// A parser that throws unconditionally to simulate an invalid schema.
      final throwingParser = _ThrowingParser();

      final featureGen = FeatureGen(
        parser: throwingParser,
        generator: FakeGenerator(),
        commandRunner: FakeCommandRunner(),
        commandHelper: commandHelper,
      );

      await featureGen.generate(results);

      // The generic catch block in generate() should record the error message.
      expect(commandHelper.errors, isNotEmpty);
      expect(commandHelper.errors.first, contains('Unexpected error'));
    });
  });
}

/// A [Parser] that always throws to simulate a runtime failure.
class _ThrowingParser extends FakeParser {
  _ThrowingParser() : super(Schema(), _dummyContext());

  static Context _dummyContext() => Context(
    name: '',
    nameLowerCase: '',
    nameCamelCase: '',
    isList: false,
    fields: [],
    methods: [],
    generateUseCase: false,
    projectRoot: '/tmp',
    projectName: 'app',
    config: const Config(),
  );

  @override
  Schema parse(String path) => throw StateError('simulated parse failure');
}
