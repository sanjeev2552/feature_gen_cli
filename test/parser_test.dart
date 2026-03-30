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

  group('Parser.buildContext (multi-response)', () {
    late Directory tempDir;
    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('feature_gen_multi_test_');
      writePubspec(tempDir, name: 'sample_app');
      Directory.current = tempDir.path;
    });
    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('sets isMultiResponse=true and builds entity list', () async {
      final parser = Parser(commandHelper: TestCommandHelper());
      final schema = Schema.fromJson(multiResponseSchema());
      final context = await parser.buildContext('auth', schema);

      expect(context.isMultiResponse, isTrue);
      expect(context.entities.map((e) => e.name), containsAll(['User', 'Token']));
    });

    test('resolves responseEntityName per method', () async {
      final parser = Parser(commandHelper: TestCommandHelper());
      final schema = Schema.fromJson(multiResponseSchema());
      final context = await parser.buildContext('auth', schema);

      final getUser = context.methods.firstWhere((m) => m.methodName == 'getUser');
      expect(getUser.responseEntityName, 'User');
      expect(getUser.hasResponse, isTrue);
      expect(getUser.responseIsList, isFalse);

      final postSomeData = context.methods.firstWhere((m) => m.methodName == 'postSomeData');
      expect(postSomeData.responseEntityName, 'Token');
      expect(postSomeData.hasResponse, isTrue);

      final updateUser = context.methods.firstWhere((m) => m.methodName == 'updateUser');
      expect(updateUser.responseEntityName, 'User');
    });

    test('marks void methods (no response key) as hasResponse=false', () async {
      final parser = Parser(commandHelper: TestCommandHelper());
      final schema = Schema.fromJson(multiResponseSchema());
      final context = await parser.buildContext('auth', schema);

      final deleteUser = context.methods.firstWhere((m) => m.methodName == 'deleteUser');
      expect(deleteUser.hasResponse, isFalse);
      expect(deleteUser.responseEntityName, isNull);
    });

    test('builds entity fields correctly', () async {
      final parser = Parser(commandHelper: TestCommandHelper());
      final schema = Schema.fromJson(multiResponseSchema());
      final context = await parser.buildContext('auth', schema);

      final userEntity = context.entities.firstWhere((e) => e.name == 'User');
      final rootField = userEntity.fields.firstWhere((f) => f.isRoot);
      expect(rootField.name, 'User');
      expect(rootField.properties.map((p) => p.name), containsAll(['id', 'name', 'email']));
    });

    test('single-response schema remains unaffected (backward compat)', () async {
      final parser = Parser(commandHelper: TestCommandHelper());
      final schema = Schema.fromJson(blocSchema());
      final context = await parser.buildContext('user', schema);

      expect(context.isMultiResponse, isFalse);
      expect(context.entities, isEmpty);
      // All methods have hasResponse=false in single-response mode.
      expect(context.methods.every((m) => !m.hasResponse), isTrue);
    });
  });
}

