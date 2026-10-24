import 'dart:io';

import 'package:feature_gen_cli/command_runner.dart';
import 'package:feature_gen_cli/generator.dart';
import 'package:feature_gen_cli/parser.dart';
import 'package:feature_gen_cli/types.dart';

/// Compiles real generated Flutter features against current dependencies.
/// Run with `dart run tool/check_generated.dart` using the pinned Flutter SDK.
Future<void> main() async {
  final project = Directory.systemTemp.createTempSync('feature_gen_flutter_');
  stdout.writeln('Checking generated features in ${project.path}');
  var passed = false;
  try {
    File('${project.path}/pubspec.yaml').writeAsStringSync('''
name: generated_features_check
publish_to: none
environment:
  sdk: ^3.13.7
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
''');
    final runner = CommandRunner();
    final parser = Parser(projectRoot: project.path);
    final generator = Generator();
    for (final layer in PresentationLayer.values) {
      await runner.checkAndAddDeps(
        config: Config(layer: layer),
        workingDirectory: project.path,
      );
      final schemas = <String, Map<String, dynamic>>{
        'simple': {
          'api': {
            'methods': {'${layer.name}GetUser': <String, dynamic>{}},
          },
          'response': {
            'user_id': 'int',
            'profile': {'display_name': 'string'},
            'roles': ['string'],
            'addresses': [
              {'street': 'string'},
            ],
          },
        },
        'list': {
          'api': {
            'methods': {'${layer.name}ListUsers': <String, dynamic>{}},
          },
          'response': [
            {'id': 'int'},
          ],
        },
        'multi': {
          'api': {
            'methods': {
              '${layer.name}FetchUser': {'response': 'user'},
              '${layer.name}FetchUsers': {
                'query': {'page': 'int'},
                'response': ['user'],
              },
              '${layer.name}SignIn': {
                'body': {
                  'profile': {'display_name': 'string'},
                },
                'response': 'token',
              },
              '${layer.name}DeleteUser': {
                'params': {'user_id': 'int'},
              },
            },
          },
          'response': {
            'user': {'id': 'int', 'name': 'string'},
            'token': {'access_token': 'string'},
          },
        },
      };
      for (final entry in schemas.entries) {
        final schema = Schema.fromJson({
          ...entry.value,
          'config': {layer.name: true},
        });
        final context = await parser.buildContext(
          '${layer.name}_${entry.key}',
          schema,
        );
        await generator.generateFeature(context);
      }
    }
    if (await runner.runBuildRunner(workingDirectory: project.path) != 0) {
      throw StateError('Generated builders failed.');
    }
    await _run('dart', ['analyze', '--fatal-infos'], project.path);

    final tests = Directory('${project.path}/test')..createSync();
    File('${tests.path}/model_test.dart').writeAsStringSync('''
import 'package:flutter_test/flutter_test.dart';
import 'package:generated_features_check/features/bloc_simple/data/models/bloc_simple_model.dart';

void main() {
  test('nested models preserve JSON keys and convert to entities', () {
    final json = <String, dynamic>{
      'user_id': 42,
      'profile': {'display_name': 'Ada'},
      'roles': ['admin'],
      'addresses': [{'street': 'Main Street'}],
    };
    final model = BlocSimpleModel.fromJson(json);
    final entity = model.toEntity();
    expect(entity.userId, 42);
    expect(entity.profile?.displayName, 'Ada');
    expect(entity.roles, ['admin']);
    expect(entity.addresses?.single.street, 'Main Street');
    expect(BlocSimpleModel.fromJson({}).toEntity().profile, isNull);
    expect(model.toJson()['user_id'], 42);
  });
}
''');
    await _run('flutter', ['test'], project.path);
    passed = true;
    stdout.writeln(
      'All 9 generated Flutter features passed analysis and model tests.',
    );
  } finally {
    if (passed) {
      project.deleteSync(recursive: true);
    } else {
      stderr.writeln(
        'Generated project retained for inspection: ${project.path}',
      );
    }
  }
}

Future<void> _run(
  String executable,
  List<String> arguments,
  String directory,
) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: directory,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      'Generated project check failed.',
      result.exitCode,
    );
  }
}
