import 'package:feature_gen_cli/types.dart';
import 'package:test/test.dart';

void main() {
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
          {'id': 'int'},
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
        'response': ['user'],
      });
      expect(method.response, 'user');
      expect(method.responseIsList, isTrue);
    });
  });

  group('Config.fromJson', () {
    test('parses bloc layer', () {
      final config = Config.fromJson({'bloc': true, 'riverpod': false, 'getx': false});
      expect(config.layer, PresentationLayer.bloc);
    });

    test('parses riverpod layer', () {
      final config = Config.fromJson({'bloc': false, 'riverpod': true, 'getx': false});
      expect(config.layer, PresentationLayer.riverpod);
    });

    test('parses getx layer', () {
      final config = Config.fromJson({'bloc': false, 'riverpod': false, 'getx': true});
      expect(config.layer, PresentationLayer.getx);
    });

    test('returns null layer when no flag is true', () {
      final config = Config.fromJson({'bloc': false, 'riverpod': false, 'getx': false});
      expect(config.layer, isNull);
    });

    test('toMap reflects the active layer as bool flags', () {
      expect(Config(layer: PresentationLayer.bloc).toMap(), {
        'bloc': true,
        'riverpod': false,
        'getx': false,
      });
      expect(Config(layer: PresentationLayer.riverpod).toMap(), {
        'bloc': false,
        'riverpod': true,
        'getx': false,
      });
      expect(Config(layer: PresentationLayer.getx).toMap(), {
        'bloc': false,
        'riverpod': false,
        'getx': true,
      });
    });
  });

  group('ContextMethod.hasUseCase (computed getter)', () {
    test('is true when method has params', () {
      final method = ContextMethod(
        methodName: 'getUser',
        methodNamePascalCase: 'GetUser',
        hasParams: true,
        hasBody: false,
        hasQuery: false,
      );
      expect(method.hasUseCase, isTrue);
    });

    test('is false when method has no inputs', () {
      final method = ContextMethod(
        methodName: 'getUser',
        methodNamePascalCase: 'GetUser',
        hasParams: false,
        hasBody: false,
        hasQuery: false,
      );
      expect(method.hasUseCase, isFalse);
    });

    test('is included in toMap()', () {
      final method = ContextMethod(
        methodName: 'getUser',
        methodNamePascalCase: 'GetUser',
        hasParams: true,
        hasBody: false,
        hasQuery: false,
      );
      expect(method.toMap()['hasUseCase'], isTrue);
    });
  });

  group('Context mapping', () {
    test('ContextField toMap', () {
      final field = ContextField(
        name: 'id',
        type: 'int',
        isList: false,
        isCustom: false,
        jsonKey: 'id',
        hasJsonKey: false,
      );
      expect(field.toMap(), containsPair('name', 'id'));
      expect(field.toMap(), containsPair('type', 'int'));
      expect(field.toMap(), containsPair('jsonKey', 'id'));
      expect(field.toMap(), containsPair('hasJsonKey', false));
    });

    test('ContextMethod toMap shape', () {
      final method = ContextMethod(
        methodName: 'getUser',
        methodNamePascalCase: 'GetUser',
        hasParams: false,
        hasBody: false,
        hasQuery: false,
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
        config: Config(layer: PresentationLayer.bloc),
      );
      final map = context.toMap();
      expect(map['name'], 'User');
      expect(map['config'], containsPair('bloc', true));
      expect(map['fields'], isA<List>());
    });
  });
}
