import 'dart:convert';
import 'dart:io';

Map<String, dynamic> blocSchema() {
  return {
    'config': {'bloc': true, 'riverpod': false},
    'api': {
      'methods': <String, dynamic>{
        'getUser': <String, dynamic>{},
        'updateUser': <String, dynamic>{
          'params': {'id': 'int'},
          'body': {
            'name': 'string',
            'profile': {'age': 'int'},
          },
          'query': {'q': 'string'},
        },
        'searchUsers': <String, dynamic>{
          'query': {
            'tags': ['string']
          },
        },
      },
    },
    'response': {
      'id': 'int',
      'profile': {'name': 'string'},
      'roles': ['string'],
      'addresses': [
        {'street': 'string'}
      ],
    },
  };
}

Map<String, dynamic> riverpodSchema() {
  return {
    'config': {'bloc': false, 'riverpod': true},
    'api': {
      'methods': <String, dynamic>{
        'getUser': <String, dynamic>{},
      },
    },
    'response': {
      'id': 'int',
      'name': 'string',
    },
  };
}

Map<String, dynamic> listResponseSchema() {
  return {
    'config': {'bloc': true, 'riverpod': false},
    'api': {
      'methods': <String, dynamic>{
        'getUsers': <String, dynamic>{},
      },
    },
    'response': [
      {'id': 'int'}
    ],
  };
}

File writeSchemaFile(Directory dir, Map<String, dynamic> schema, {String name = 'schema.json'}) {
  final file = File('${dir.path}/$name');
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(schema));
  return file;
}

File writePubspec(Directory dir, {String name = 'sample_app'}) {
  final file = File('${dir.path}/pubspec.yaml');
  file.writeAsStringSync('name: $name\n');
  return file;
}
