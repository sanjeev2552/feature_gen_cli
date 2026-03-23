import 'package:feature_gen_cli/string_extension.dart';
import 'package:test/test.dart';

void main() {
  group('StringExtension', () {
    test('toPascalCase converts snake_case', () {
      expect('user_profile'.toPascalCase(), 'UserProfile');
    });

    test('toCamelCase converts snake_case', () {
      expect('user_profile'.toCamelCase(), 'userProfile');
    });

    test('camelCaseToSnakeCase converts camelCase', () {
      expect('userProfile'.camelCaseToSnakeCase(), 'user_profile');
    });

    test('camelCaseToPascalCase converts camelCase', () {
      expect('userProfile'.camelCaseToPascalCase(), 'UserProfile');
    });
  });
}
