import 'package:feature_gen_cli/types.dart';
import 'package:test/test.dart';

void main() {
  group('Schema.responseParser', () {
    test('unwraps list response', () {
      final (response, isList) = Schema.responseParser([
        {'id': 'int'}
      ]);
      expect(isList, isTrue);
      expect(response['id'], 'int');
    });

    test('returns object response as-is', () {
      final (response, isList) = Schema.responseParser({'id': 'int'});
      expect(isList, isFalse);
      expect(response['id'], 'int');
    });
  });

  group('Schema multi-response detection', () {
    test('detects multi-response when all values are objects', () {
      final schema = Schema.fromJson({
        'config': {'bloc': true, 'riverpod': false},
        'api': {'methods': {}},
        'response': {
          'user': {'id': 'int', 'name': 'string'},
          'token': {'accessToken': 'string'},
        },
      });
      expect(schema.isMultiResponse, isTrue);
      expect(schema.responses!.keys, containsAll(['user', 'token']));
      expect(schema.response, isNull);
    });

    test('treats mixed-value response map as single-response', () {
      final schema = Schema.fromJson({
        'config': {'bloc': true, 'riverpod': false},
        'api': {'methods': {}},
        'response': {'id': 123, 'name': 'string'},
      });
      expect(schema.isMultiResponse, isFalse);
      expect(schema.response, isNotNull);
    });

    test('treats list-wrapped response as single-response with isList=true', () {
      final schema = Schema.fromJson({
        'config': {'bloc': true, 'riverpod': false},
        'api': {'methods': {}},
        'response': [
          {'id': 'int'}
        ],
      });
      expect(schema.isMultiResponse, isFalse);
      expect(schema.isList, isTrue);
    });

    test('ApiMethod parses response key as string', () {
      final method = ApiMethod.fromJson({'response': 'user'});
      expect(method.response, 'user');
      expect(method.responseIsList, isFalse);
    });

    test('ApiMethod parses array-wrapped response key', () {
      final method = ApiMethod.fromJson({
        'response': ['user']
      });
      expect(method.response, 'user');
      expect(method.responseIsList, isTrue);
    });
  });


  group('Config validation', () {
    test('throws when both bloc and riverpod are true', () {
      expect(() => Config(bloc: true, riverpod: true), throwsArgumentError);
    });

    test('throws when both bloc and riverpod are false', () {
      expect(() => Config(bloc: false, riverpod: false), throwsArgumentError);
    });
  });

  group('Context mapping', () {
    test('ContextField toMap', () {
      final field = ContextField(name: 'id', type: 'int', isList: false, isCustom: false);
      expect(field.toMap(), containsPair('name', 'id'));
      expect(field.toMap(), containsPair('type', 'int'));
    });

    test('ContextMethod toMap shape', () {
      final method = ContextMethod(
        methodName: 'getUser',
        methodNamePascalCase: 'GetUser',
        hasParams: false,
        hasBody: false,
        hasQuery: false,
        hasUseCase: false,
      );
      final map = method.toMap();
      expect(map['methodName'], 'getUser');
      expect(map['methodNamePascalCase'], 'GetUser');
      expect(map['hasUseCase'], isFalse);
    });

    test('Context toMap includes config and fields', () {
      final context = Context(
        name: 'User',
        nameLowerCase: 'user',
        nameCamelCase: 'user',
        isList: false,
        fields: [NestedContextField(name: 'User', properties: [], isRoot: true)],
        methods: [],
        generateUseCase: false,
        projectRoot: '/tmp',
        projectName: 'sample',
        config: Config(bloc: true, riverpod: false),
      );
      final map = context.toMap();
      expect(map['name'], 'User');
      expect(map['config'], containsPair('bloc', true));
      expect(map['fields'], isA<List>());
    });
  });
}
