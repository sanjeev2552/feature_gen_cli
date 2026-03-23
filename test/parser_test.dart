import 'dart:io';

import 'package:feature_gen_cli/parser.dart';
import 'package:feature_gen_cli/types.dart';
import 'package:test/test.dart';

import 'support/test_fakes.dart';
import 'support/test_fixtures.dart';

void main() {
  group('Parser.parse', () {
    test('reads JSON schema and maps to Schema', () {
      final tempDir = Directory.systemTemp.createTempSync('feature_gen_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final file = writeSchemaFile(tempDir, blocSchema());
      final parser = Parser(commandHelper: TestCommandHelper());

      final schema = parser.parse(file.path);
      expect(schema.api, isNotNull);
      expect(schema.config, isNotNull);
      expect(schema.response, isNotNull);
    });
  });

  group('Parser.validateSchema', () {
    test('returns false and reports missing api', () {
      final helper = TestCommandHelper();
      final parser = Parser(commandHelper: helper);

      final schema = Schema(response: {}, config: Config(bloc: true, riverpod: false));
      final ok = parser.validateSchema(schema);

      expect(ok, isFalse);
      expect(helper.errors, isNotEmpty);
    });

    test('returns false and reports missing config', () {
      final helper = TestCommandHelper();
      final parser = Parser(commandHelper: helper);

      final schema = Schema(api: Api(methods: Methods(method: {})), response: {});
      final ok = parser.validateSchema(schema);

      expect(ok, isFalse);
      expect(helper.errors, isNotEmpty);
    });
  });

  group('Parser.buildContext', () {
    test('builds context with correct naming and usecase flags', () async {
      final tempDir = Directory.systemTemp.createTempSync('feature_gen_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      writePubspec(tempDir, name: 'sample_app');

      final previous = Directory.current;
      Directory.current = tempDir.path;
      addTearDown(() => Directory.current = previous);

      final parser = Parser(commandHelper: TestCommandHelper());
      final schema = Schema.fromJson(blocSchema());
      final context = await parser.buildContext('user_profile', schema);

      expect(context.name, 'UserProfile');
      expect(context.nameLowerCase, 'user_profile');
      expect(context.nameCamelCase, 'userProfile');
      expect(context.projectName, 'sample_app');
      expect(context.generateUseCase, isTrue);
      expect(context.methods.where((m) => m.methodName == 'updateUser').single.hasUseCase, isTrue);
    });

    test('marks list response at root', () async {
      final tempDir = Directory.systemTemp.createTempSync('feature_gen_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      writePubspec(tempDir, name: 'sample_app');

      final previous = Directory.current;
      Directory.current = tempDir.path;
      addTearDown(() => Directory.current = previous);

      final parser = Parser(commandHelper: TestCommandHelper());
      final schema = Schema.fromJson(listResponseSchema());
      final context = await parser.buildContext('users', schema);

      expect(context.isList, isTrue);
    });

    test('captures nested fields for params/body/query', () async {
      final tempDir = Directory.systemTemp.createTempSync('feature_gen_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      writePubspec(tempDir, name: 'sample_app');

      final previous = Directory.current;
      Directory.current = tempDir.path;
      addTearDown(() => Directory.current = previous);

      final parser = Parser(commandHelper: TestCommandHelper());
      final schema = Schema.fromJson(blocSchema());
      final context = await parser.buildContext('user', schema);
      final update = context.methods.firstWhere((m) => m.methodName == 'updateUser');

      expect(update.hasParams, isTrue);
      expect(update.hasBody, isTrue);
      expect(update.hasQuery, isTrue);
      expect(update.params, isNotEmpty);
      expect(update.body, isNotEmpty);
      expect(update.query, isNotEmpty);
    });
  });
}
