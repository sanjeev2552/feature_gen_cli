import 'dart:io';

import 'package:feature_gen_cli/yaml_helper.dart';
import 'package:test/test.dart';

import 'support/test_fakes.dart';

void main() {
  late Directory directory;
  setUp(
    () => directory = Directory.systemTemp.createTempSync('feature_gen_yaml_'),
  );
  tearDown(() => directory.deleteSync(recursive: true));

  test('preserves dependencies when dev_dependencies is absent', () async {
    File('${directory.path}/pubspec.yaml').writeAsStringSync('''
name: sample_app
dependencies:
  get_it: ^9.0.0
''');
    final helper = TestCommandHelper();
    final (dependencies, devDependencies) = await YamlHelper(
      commandHelper: helper,
    ).getDependencies(workingDirectory: directory.path);
    expect(dependencies?['get_it'], '^9.0.0');
    expect(devDependencies, isNull);
    expect(helper.warnings, isEmpty);
  });

  test('allows both dependency sections to be absent', () async {
    File('${directory.path}/pubspec.yaml')
        .writeAsStringSync('name: sample_app\n');
    expect(
      await YamlHelper().getDependencies(workingDirectory: directory.path),
      (null, null),
    );
  });

  test('rejects malformed manifests instead of treating all dependencies as missing', () async {
    File('${directory.path}/pubspec.yaml')
        .writeAsStringSync('dependencies: [invalid]\n');
    await expectLater(
      YamlHelper().getDependencies(workingDirectory: directory.path),
      throwsStateError,
    );
  });
}
