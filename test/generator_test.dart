import 'dart:io';

import 'package:feature_gen_cli/generator.dart';
import 'package:feature_gen_cli/parser.dart';
import 'package:feature_gen_cli/types.dart';
import 'package:test/test.dart';

import 'support/test_fakes.dart';
import 'support/test_fixtures.dart';

void main() {
  group('Generator.renderTemplate', () {
    test('does not overwrite existing files by default', () {
      final tempDir = Directory.systemTemp.createTempSync('feature_gen_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final templateFile = File('${tempDir.path}/template.mustache')
        ..writeAsStringSync('Hello {{name}}');
      final outFile = File('${tempDir.path}/output.dart')
        ..writeAsStringSync('Existing content');

      Generator().renderTemplate(
        templateFile.path,
        outFile.path,
        {'name': 'New'},
        overwrite: false,
      );

      expect(outFile.readAsStringSync(), 'Existing content');
    });

    test('overwrites existing files when overwrite is true', () {
      final tempDir = Directory.systemTemp.createTempSync('feature_gen_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final templateFile = File('${tempDir.path}/template.mustache')
        ..writeAsStringSync('Hello {{name}}');
      final outFile = File('${tempDir.path}/output.dart')
        ..writeAsStringSync('Existing content');

      Generator().renderTemplate(
        templateFile.path,
        outFile.path,
        {'name': 'New'},
        overwrite: true,
      );

      expect(outFile.readAsStringSync(), 'Hello New');
    });
  });

  group('Generator.generateFeature', () {
    Future<Context> _buildContext({
      required Map<String, dynamic> schemaJson,
      required Directory projectDir,
      required String featureName,
    }) async {
      writePubspec(projectDir, name: 'sample_app');
      final previous = Directory.current;
      Directory.current = projectDir.path;
      addTearDown(() => Directory.current = previous);

      final parser = Parser(commandHelper: TestCommandHelper());
      final schema = Schema.fromJson(schemaJson);
      return parser.buildContext(featureName, schema);
    }

    test('generates BLoC files and usecases, not riverpod notifier', () async {
      final tempDir = Directory.systemTemp.createTempSync('feature_gen_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final context = await _buildContext(
        schemaJson: blocSchema(),
        projectDir: tempDir,
        featureName: 'user',
      );

      expect(context.nameLowerCase, 'user');
      expect(context.config.bloc, isTrue);

      await Generator().generateFeature(context);

      final base = '${tempDir.path}/lib/features/${context.nameLowerCase}';
      expect(File('$base/presentation/bloc/user_bloc.dart').existsSync(), isTrue);
      expect(File('$base/presentation/bloc/user_event.dart').existsSync(), isTrue);
      expect(File('$base/presentation/bloc/user_state.dart').existsSync(), isTrue);
      expect(File('$base/presentation/riverpod/user_notifier.dart').existsSync(), isFalse);
      expect(File('$base/presentation/screen/user_screen.dart').existsSync(), isTrue);

      final usecasePath = '$base/domain/usecases/update_user_usecase.dart';
      expect(File(usecasePath).existsSync(), isTrue);

      final usecaseContents = File(usecasePath).readAsStringSync();
      expect(usecaseContents, contains('extends UseCase'));
      expect(usecaseContents, contains('extends BodyParams'));
      expect(usecaseContents, contains('extends PathParams'));
      expect(usecaseContents, contains('extends QueryParams'));
      expect(usecaseContents, contains('Map<String, dynamic> toJson()'));
    });

    test('generates Riverpod files and skips BLoC files', () async {
      final tempDir = Directory.systemTemp.createTempSync('feature_gen_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final context = await _buildContext(
        schemaJson: riverpodSchema(),
        projectDir: tempDir,
        featureName: 'user',
      );

      await Generator().generateFeature(context);

      final base = '${tempDir.path}/lib/features/user';
      expect(File('$base/presentation/riverpod/user_notifier.dart').existsSync(), isTrue);
      expect(File('$base/presentation/bloc/user_bloc.dart').existsSync(), isFalse);
      expect(File('$base/presentation/screen/user_screen.dart').existsSync(), isTrue);
    });

    test('uses NoParams when method has no params/body/query', () async {
      final tempDir = Directory.systemTemp.createTempSync('feature_gen_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final context = await _buildContext(
        schemaJson: blocSchema(),
        projectDir: tempDir,
        featureName: 'user',
      );

      await Generator().generateFeature(context);

      final base = '${tempDir.path}/lib/features/${context.nameLowerCase}';
      final usecasePath = '$base/domain/usecases/get_user_usecase.dart';
      final contents = File(usecasePath).readAsStringSync();
      expect(contents, contains('NoParams'));
    });
  });
}
