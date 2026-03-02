# Feature Gen

A Dart CLI tool that generates clean-architecture feature modules for Flutter projects from a JSON schema.

## Installation

```bash
dart pub global activate --source git https://github.com/sanjeev2552/feature_gen.git
```

## Usage

```bash
feature_gen <feature_name> <schema.json>
```

### Options

| Flag              | Description               |
| ----------------- | ------------------------- |
| `-h`, `--help`    | Show usage information    |
| `-v`, `--version` | Print the current version |

### Example

```bash
feature_gen user schema.json
```

## Schema Format

The JSON schema defines your feature's API methods and response structure.

```json
{
  "api": {
    "methods": {
      "getUser": {},
      "postSomeData": {
        "body": {
          "name": "string",
          "email": "string",
          "password": "string"
        }
      },
      "updateUser": {
        "body": {
          "name": "string",
          "email": "string"
        }
      },
      "deleteUser": {
        "params": {
          "id": "int"
        }
      }
    }
  },
  "response": {
    "id": 123,
    "name": "string",
    "email": "string",
    "address": {
      "street": "string",
      "city": "string"
    },
    "tags": ["string"]
  }
}
```

### Nested Objects

Feature Gen automatically detects nested JSON objects and lists of objects in your schema. It generates separate Freezed models for these nested structures and handles the mapping between Data Models and Domain Entities recursively.

```json
{
  "response": {
    "user": {
      "id": "int",
      "profile": {
        "bio": "string",
        "avatar_url": "string"
      }
    }
  }
}
```

### Schema Sections

#### `api.methods`

Each key is a method name (camelCase). A method can optionally define:

- **`params`** — URL path parameters
- **`body`** — Request body fields
- **`query`** — Query string parameters

Methods with at least one of these sections will also get a **use-case** class generated.

Methods with no sections (e.g. `"getUser": {}`) generate only the repository/datasource/bloc wiring.

#### `response`

Defines the fields for the entity and model classes. Keys are field names, values are types.

### Supported Types

| Schema Value | Dart Type              |
| ------------ | ---------------------- |
| `"string"`   | `String`               |
| `"int"`      | `int`                  |
| `"double"`   | `double`               |
| `"bool"`     | `bool`                 |
| `"list"`     | `List<dynamic>`        |
| `"map"`      | `Map<String, dynamic>` |
| `{ ... }`    | `CustomModel`          |
| `[{ ... }]`  | `List<CustomModel>`    |

You can also use actual JSON values (e.g. `123` → `int`, `"hello"` → `String`). Nested objects are automatically lifted into their own classes named after the key (PascalCase).

## Generated Structure

Running `feature_gen user schema.json` produces:

```
lib/features/user/
├── data/
│   ├── datasources/
│   │   └── user_remote_datasource.dart
│   ├── models/
│   │   └── user_model.dart
│   └── repositories/
│       └── user_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── user_entity.dart
│   ├── repositories/
│   │   └── user_repository.dart
│   └── usecases/
│       ├── get_user_usecase.dart
│       ├── post_some_data_usecase.dart
│       ├── update_user_usecase.dart
│       └── delete_user_usecase.dart
└── presentation/
    └── bloc/
        ├── user_bloc.dart
        ├── user_event.dart
        └── user_state.dart
```

If any method has params/body/query, a shared base use-case is also created at:

```
lib/features/shared/usecase/base_usecase.dart
```

## What It Does Automatically

1. **Checks & installs dependencies** — Adds missing packages (`flutter_bloc`, `freezed`, `get_it`, `injectable`, etc.) to the target project's `pubspec.yaml`.
2. **Generates feature files** — Renders all Dart files from Mustache templates following clean architecture.
3. **Runs `build_runner`** — Triggers code generation for Freezed models and JSON serialization.
4. **Formats code** — Runs `dart format .` on the entire project.

## Required Dependencies

These are automatically added if missing:

**Runtime:**
`get_it`, `injectable`, `flutter_bloc`, `bloc`, `equatable`, `freezed_annotation`, `json_annotation`

**Dev:**
`build_runner`, `injectable_generator`, `freezed`, `json_serializable`

## Project Structure

```
feature_gen/
├── bin/feature_gen.dart        # CLI entry point
├── lib/
│   ├── feature_gen.dart        # Pipeline orchestrator
│   ├── parser.dart             # JSON schema parser & context builder
│   ├── generator.dart          # Directory creation & template rendering
│   ├── command_runner.dart     # Shell command execution (deps, build, format)
│   ├── command_helper.dart     # Styled console output (errors, success, warnings)
│   ├── types.dart              # Data models (Schema, Context, etc.)
│   ├── string_extension.dart   # Case-conversion utilities
│   ├── yaml_helper.dart        # pubspec.yaml reader
│   └── template/               # Mustache template files
└── pubspec.yaml
```

## License

MIT
