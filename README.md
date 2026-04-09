# Feature Gen

[![pub package](https://img.shields.io/pub/v/feature_gen_cli.svg)](https://pub.dev/packages/feature_gen_cli) [![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT) [![pub points](https://img.shields.io/pub/points/feature_gen_cli)](https://pub.dev/packages/feature_gen_cli/score)

Feature Gen is a Dart CLI that scaffolds clean-architecture feature modules for Flutter projects from a JSON schema.

## Quick Start

**Requirements:** Dart SDK `>=3.10.4`, a Flutter project with a valid `pubspec.yaml`, and `dart` on your PATH. Run the CLI from the Flutter project root so `pubspec.yaml` resolution works.

```bash
# 1. Install
dart pub global activate feature_gen_cli

# 2. Run
feature_gen_cli <feature_name> <schema.json>
# Example: feature_gen_cli user example/user_schema.json

# Overwrite existing generated files (optional)
feature_gen_cli <feature_name> <schema.json> --overwrite
```

Feature names should be lowercase `snake_case` (the generated folder is `lib/features/<feature_name>/`).

### CLI Options

```bash
feature_gen_cli <feature_name> <schema.json> -o   # overwrite existing generated files
feature_gen_cli --version                          # print package version
feature_gen_cli --help                             # show help
```

## Schema Reference

The schema is a single JSON file requiring three sections: `config`, `api.methods`, and `response`.

### Single-Response (one entity for the whole feature)

```json
{
  "config": { "bloc": true, "riverpod": false },
  "api": {
    "methods": {
      "getUser":    {},
      "updateUser": { "body": { "name": "string", "email": "string" } },
      "deleteUser": { "params": { "id": "int" } }
    }
  },
  "response": { "id": "int", "name": "string" }
}
```

### Multi-Response (different entities per method)

When different API methods return different types, define each response type by name and add a `"response"` key to each method that declares which type it returns.

```json
{
  "config": { "bloc": true, "riverpod": false },
  "api": {
    "methods": {
      "getUser":      { "response": "user" },
      "postSomeData": { "body": { "name": "string", "email": "string" }, "response": "token" },
      "updateUser":   { "body": { "name": "string" }, "response": "user" },
      "deleteUser":   { "params": { "id": "int" } }
    }
  },
  "response": {
    "user":  { "id": 123, "name": "string", "email": "string" },
    "token": { "accessToken": "string", "refreshToken": "string", "tokenType": "string" }
  }
}
```

**Multi-response rules:**

- **Detection** — if all top-level values in `response` are objects, multi-response mode is activated automatically. No extra flag needed.
- **Per-method binding** — set `"response": "<key>"` on any method to link it to a named entity.
- **List returns** — wrap the key in an array to return a list: `"response": ["user"]` → `Future<List<UserEntity>>`.
- **Void methods** — omit `"response"` entirely and the method generates `Future<void>` across all layers.
- **Backward compatible** — schemas with primitive values at the top level of `response` continue to work as single-response.

### Common Options

- **`config`**: Both keys (`bloc` and `riverpod`) are required; exactly one must be `true`.
- **`api.methods`**: Define endpoints (camelCase). Optionally include `params`, `body`, or `query` to generate `UseCase` and param classes.
- **`response`**: Define entity fields. Supported primitives: `"string"`, `"int"`, `"double"`, `"bool"`, `"list"`, `"map"`. Supports nested objects and arrays.

**Naming Convention Note:** `snake_case` keys in your configuration JSON are automatically generated into `camelCase` variables for your data classes, ensuring code idiomacy. Serialization layers accurately map variables back to their exact original JSON keys using Freezed `@JsonKey` configurations and custom overrides automatically.

## Generated Structure

Running the CLI produces a complete clean-architecture module in `lib/features/<feature_name>/`:

```
lib/features/<feature>/
├── data/
│   ├── datasources/   <feature>_remote_datasource.dart
│   ├── models/        <entity>_model.dart          (one per entity in multi-response)
│   └── repositories/  <feature>_repository_impl.dart
└── domain/
    ├── entities/      <entity>_entity.dart          (one per entity in multi-response)
    ├── repositories/  <feature>_repository.dart
    └── usecases/      <method>_usecase.dart
└── presentation/
    ├── bloc/          <feature>_bloc.dart, _event.dart, _state.dart
    └── screen/        <feature>_screen.dart
```

In **multi-response mode**, the BLoC and Riverpod states get one typed success factory per method:

```dart
// generated user_state.dart
const factory UserState.getUserSuccess(UserEntity data) = _GetUserSuccessState;
const factory UserState.postSomeDataSuccess(TokenEntity data) = _PostSomeDataSuccessState;
const factory UserState.deleteUserSuccess() = _DeleteUserSuccessState;
```

The CLI automatically adds missing dependencies, runs `build_runner`, and formats the generated code.

## Overwrite Behavior

By default, the CLI only generates missing files and will not overwrite existing files. Use `--overwrite` (or `-o`) to force regeneration.

## Troubleshooting

- **Schema validation errors**: Ensure `config`, `api.methods`, and `response` exist, and that exactly one of `config.bloc` or `config.riverpod` is `true`.
- **`build_runner` failed**: Re-run it manually: `dart run build_runner build -d`.

## Support ❤️

If you find this package helpful, please consider giving it a like on [pub.dev](https://pub.dev/packages/feature_gen_cli) and adding a ⭐ star on [GitHub](https://github.com/sanjeev2552/feature_gen)! Your support is greatly appreciated.

## Contributing

- Install dependencies: `dart pub get`
- Run tests: `dart test`
- Format code: `dart format .`

Note: The test suite is pure unit tests and avoids running external commands.

## License

MIT
