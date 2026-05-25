import 'package:feature_gen_cli/command_runner.dart';
import 'package:feature_gen_cli/types.dart';
import 'package:test/test.dart';

import 'support/test_fakes.dart';

void main() {
  group('CommandRunner dependency management', () {
    test('adds missing deps for bloc config', () async {
      final fakeProcess = FakeProcessRunner();
      final runner = CommandRunner(
        processRunner: fakeProcess.call,
        yamlHelper: FakeYamlHelper(dependencies: {}, devDependencies: {}),
        commandHelper: TestCommandHelper(),
      );

      await runner.checkAndAddDeps(
        config: const Config(layer: PresentationLayer.bloc),
        workingDirectory: '/tmp',
      );

      expect(fakeProcess.calls, isNotEmpty);
      final (_, args, _) = fakeProcess.calls.first;
      expect(args, containsAll(['pub', 'add', 'get_it', 'injectable', 'flutter_bloc', 'bloc']));
      expect(args, containsAll(['dev:build_runner', 'dev:freezed', 'dev:json_serializable']));
    });

    test('adds missing deps for riverpod config', () async {
      final fakeProcess = FakeProcessRunner();
      final runner = CommandRunner(
        processRunner: fakeProcess.call,
        yamlHelper: FakeYamlHelper(dependencies: {}, devDependencies: {}),
        commandHelper: TestCommandHelper(),
      );

      await runner.checkAndAddDeps(
        config: const Config(layer: PresentationLayer.riverpod),
        workingDirectory: '/tmp',
      );

      final (_, args, _) = fakeProcess.calls.first;
      expect(args, contains('flutter_riverpod'));
      expect(args, isNot(contains('flutter_bloc')));
      expect(args, isNot(contains('get')));
    });

    test('adds missing deps for getx config', () async {
      final fakeProcess = FakeProcessRunner();
      final runner = CommandRunner(
        processRunner: fakeProcess.call,
        yamlHelper: FakeYamlHelper(dependencies: {}, devDependencies: {}),
        commandHelper: TestCommandHelper(),
      );

      await runner.checkAndAddDeps(
        config: const Config(layer: PresentationLayer.getx),
        workingDirectory: '/tmp',
      );

      final (_, args, _) = fakeProcess.calls.first;
      expect(args, contains('get'));
      expect(args, isNot(contains('flutter_bloc')));
      expect(args, isNot(contains('flutter_riverpod')));
    });

    test('does not add deps when already present', () async {
      final fakeProcess = FakeProcessRunner();
      final runner = CommandRunner(
        processRunner: fakeProcess.call,
        yamlHelper: FakeYamlHelper(
          dependencies: {
            'get_it': '^1.0.0',
            'injectable': '^1.0.0',
            'flutter_bloc': '^1.0.0',
            'bloc': '^1.0.0',
            'equatable': '^1.0.0',
            'freezed_annotation': '^1.0.0',
            'json_annotation': '^1.0.0',
          },
          devDependencies: {
            'build_runner': '^1.0.0',
            'injectable_generator': '^1.0.0',
            'freezed': '^1.0.0',
            'json_serializable': '^1.0.0',
          },
        ),
        commandHelper: TestCommandHelper(),
      );

      await runner.checkAndAddDeps(
        config: const Config(layer: PresentationLayer.bloc),
        workingDirectory: '/tmp',
      );

      expect(fakeProcess.calls, isEmpty);
    });

    test('installs only the missing subset when some deps are present', () async {
      final fakeProcess = FakeProcessRunner();
      final runner = CommandRunner(
        processRunner: fakeProcess.call,
        yamlHelper: FakeYamlHelper(
          // get_it and injectable already present; flutter_bloc + bloc missing.
          dependencies: {
            'get_it': '^1.0.0',
            'injectable': '^1.0.0',
            'equatable': '^1.0.0',
            'freezed_annotation': '^1.0.0',
            'json_annotation': '^1.0.0',
          },
          devDependencies: {
            'build_runner': '^1.0.0',
            'injectable_generator': '^1.0.0',
            'freezed': '^1.0.0',
            'json_serializable': '^1.0.0',
          },
        ),
        commandHelper: TestCommandHelper(),
      );

      await runner.checkAndAddDeps(
        config: const Config(layer: PresentationLayer.bloc),
        workingDirectory: '/tmp',
      );

      expect(fakeProcess.calls, hasLength(1));
      final (_, args, _) = fakeProcess.calls.first;
      // Only the missing bloc deps should be in the add command.
      expect(args, contains('flutter_bloc'));
      expect(args, contains('bloc'));
      // Already present deps must not be re-added.
      expect(args, isNot(contains('get_it')));
      expect(args, isNot(contains('injectable')));
      // No dev deps should be re-added either.
      expect(args, isNot(contains('dev:build_runner')));
    });
  });

  group('CommandRunner build/format', () {
    test('runBuildRunner calls dart run build_runner build -d', () async {
      final fakeProcess = FakeProcessRunner();
      final runner = CommandRunner(
        processRunner: fakeProcess.call,
        yamlHelper: FakeYamlHelper(dependencies: {}, devDependencies: {}),
        commandHelper: TestCommandHelper(),
      );

      await runner.runBuildRunner(workingDirectory: '/tmp');
      final (exe, args, _) = fakeProcess.calls.first;

      expect(exe, 'dart');
      expect(args, ['run', 'build_runner', 'build', '-d']);
    });

    test('runFormat calls dart format on feature directory', () async {
      final fakeProcess = FakeProcessRunner();
      final runner = CommandRunner(
        processRunner: fakeProcess.call,
        yamlHelper: FakeYamlHelper(dependencies: {}, devDependencies: {}),
        commandHelper: TestCommandHelper(),
      );

      await runner.runFormat(featureName: 'user', workingDirectory: '/tmp');
      final (exe, args, _) = fakeProcess.calls.first;

      expect(exe, 'dart');
      expect(args, ['format', 'lib/features/user']);
    });
  });
}
