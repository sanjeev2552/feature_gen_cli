# Changelog

## 1.4.2

### Features

- **JSON snake_case Convention Support** — Generated class properties automatically convert JSON `snake_case` representations into Dart-idiomatic `camelCase` across models, entities, and usecase parameters.
- **Accurate Model Serialization** — Models automatically annotate properties modified into `camelCase` with `@JsonKey(name: 'original_key')` to guarantee API compatibility.
- **Accurate Payload Serialization** — UseCase parameter classes (`PathParams`, `BodyParams`, `QueryParams`) correctly invoke original API `snake_case` keys from their `toJson()` overrides when emitting payloads.

## 1.4.1

### Fix

- **Riverpod Typed States** — Riverpod notifiers now use explicitly generated Freezed `State` classes instead of generic `AsyncValue<Object?>`. This brings the same per-method typed success factories and explicit loading/error states to Riverpod that are available for BLoC.

### Refactor

- **Template Consolidation** — BLoC and Riverpod state generation now share a unified `presentation/state.mustache` template, eliminating duplicate template logic.

## 1.4.0

### Features

- **Multi-Response Support** — The `response` section now accepts multiple named entity types in addition to the existing single-response format. Any response map whose top-level values are all objects is automatically detected as multi-response mode:

  ```json
  "response": {
    "user":  { "id": 123, "name": "string", "email": "string" },
    "token": { "accessToken": "string", "refreshToken": "string" }
  }
  ```

- **Per-Method Response Binding** — Each API method can now declare which response entity it returns via the `"response"` key. Array-wrapped values (`["user"]`) mark the return type as `List<UserEntity>`:

  ```json
  "getUser":      { "response": "user" },
  "postSomeData": { "body": { ... }, "response": "token" },
  "listUsers":    { "response": ["user"] },
  "deleteUser":   { "params": { "id": "int" } }
  ```

- **Void-Return Methods** — Methods without a `response` key in multi-response mode generate `Future<void>` signatures across all layers (repository, datasource, usecase, bloc, riverpod).

- **Per-Entity File Generation** — In multi-response mode the generator creates one entity file and one model file per named response (e.g. `user_entity.dart` + `token_entity.dart`) instead of a single combined file.

- **Per-Method Typed Bloc States** — The BLoC `State` class gains one typed success factory per method instead of a single generic success state, e.g.:
  ```dart
  const factory UserState.getUserSuccess(UserEntity data) = ...;
  const factory UserState.postSomeDataSuccess(TokenEntity data) = ...;
  const factory UserState.deleteUserSuccess() = ...;
  ```

### Backward Compatibility

- Single-response schemas (including array-wrapped `[{...}]`) are **fully unchanged** — all existing generated code is identical to previous versions.

### Tests

- **Multi-Response Detection Tests** — New tests covering `Schema.fromJson` detection logic, `ApiMethod` response field parsing (string and array-wrapped), and backward-compat of single-response schemas.
- **Multi-Response Parser Tests** — New tests verifying `buildContext` correctly builds `EntityContext` list, resolves `responseEntityName` per method, and marks void methods as `hasResponse=false`.

## 1.3.5

### Tests

- **Comprehensive Unit Tests** — Added grouped unit tests covering parser, generator, CLI overwrite flag, command runner behavior, and string/type helpers.

### Docs

- **Dartdoc Updates** — Documented new injectable seams and CLI arg builder for testing.
- **README Note** — Clarified the test suite runs as pure unit tests without external commands.

## 1.3.4

### Features

- **Safe Generation** — The generator now only creates missing files by default, preserving user edits.
- **Overwrite Flag** — Added `--overwrite` (`-o`) to force regeneration of existing files.
- **Param Base Classes** — Generated path/body/query params now extend shared base classes and implement `toJson()`.

## 1.3.3

### Docs

- **README Update** — Condensed documentation for quicker reading.

## 1.3.2

### Docs

- **README Overhaul** — Expanded project documentation with requirements, quick start, schema reference, naming conventions, CLI side effects, and troubleshooting guidance.
- **Dartdoc Enhancements** — Refined file-level doc comments across CLI, generator, parser, helpers, types, and example entrypoint for clearer behavior and assumptions.

## 1.3.1

### Docs

- **Pub Badge URL Fix** — Updated the pub.dev badge image URL in `README.md` to point to `feature_gen_cli.svg` instead of the old package name.

## 1.3.0

### Improvements

- **Constructor Initializer Lists** — BLoC and Riverpod templates now use explicit initializer lists (`_useCase = useCase`) instead of `this._useCase` for constructor parameters, improving readability of generated code.
- **Screen Template** — Added `presentation/screen/` generation for feature scaffolding.
- **Injector Template** — Added `lib/core/di/injector.dart` generation for dependency injection setup.

## 1.2.3+1

### Docs

- **Pub Badges** — Added `pub package`, `license`, and `pub points` badges to `README.md`.
- **Pubspec Topics** — Added topic tags (`flutter`, `cli`, `code-generation`, `clean-architecture`, `architecture`) for pub.dev discoverability.

## 1.2.3

### Features

- **List Response Support** — Response arrays (`[{...}]`) are automatically detected and propagated as `List<Entity>` across all generated layers (entity, model, repository, datasource, usecase, bloc state, and riverpod notifier).

### Improvements

- **Scoped Formatting** — `dart format` now targets only the generated feature directory instead of the entire project.

## 1.2.2

### Docs

- **Example Files** — Added `example/example.dart` and `example/user_schema.json` to demonstrate CLI usage and provide a sample schema for feature generation.

## 1.2.1

### Refactor

- **Package Rename** — Renamed the package and executable from `feature_gen` to `feature_gen_cli` across all source files, imports, CLI usage messages, and `pubspec.yaml`.

### Docs

- **Pubspec Metadata** — Added `repository`, `homepage`, and `issue_tracker` links to `pubspec.yaml`.

## 1.2.0

### Features

- **Riverpod Support** — Support for generating Riverpod `Notifier` classes as an alternative to BLoC.
- **Configurable Presentation Layer** — New `config` section in the JSON schema allows choosing between `bloc` and `riverpod`.
- **Selective Dependency Management** — Only installs the dependencies required for the selected state management (e.g., skips `flutter_bloc` if using `riverpod`).
- **Strict Schema Validation** — Enforces at least one state management option in the `config` section.

## 1.1.0

### Features

- **Nested Object Support** — Support for nested JSON objects and lists of objects in both API request models (`params`, `body`, `query`) and response entities/models.
- **Recursive Model Generation** — Automatically generates nested Freezed models and entities for complex schema structures.
- **Enhanced Type Mapping** — Improved template logic for handling lists, maps, and custom types during `toEntity` mapping.
- **Root Entity Markers** — Added comments to generated entities to clearly identify root objects.

## 1.0.0

### Features

- **Feature scaffolding** — Generate clean-architecture feature modules from a JSON schema.
- **Schema-driven generation** — Define API methods (`params`, `body`, `query`) and response fields in a single JSON file.
- **Auto dependency management** — Automatically checks and installs required packages (`flutter_bloc`, `freezed`, `get_it`, `injectable`, etc.).
- **Build runner integration** — Runs `build_runner` after generation for Freezed models and JSON serialization.
- **Code formatting** — Applies `dart format` to the entire project after generation.
- **Use-case generation** — Generates use-case classes for methods that define params, body, or query fields, along with a shared `BaseUseCase` abstract class.
- **BLoC generation** — Generates BLoC, Event, and State files for each feature.
- **Dynamic package name** — Reads the project name from `pubspec.yaml` for correct import paths in generated files.
- **CLI flags** — `--help` and `--version` support.

### Generated Files

- `data/models/<feature>_model.dart`
- `data/repositories/<feature>_repository_impl.dart`
- `data/datasources/<feature>_remote_datasource.dart`
- `domain/entities/<feature>_entity.dart`
- `domain/repositories/<feature>_repository.dart`
- `domain/usecases/<method>_usecase.dart`
- `presentation/bloc/<feature>_bloc.dart`
- `presentation/bloc/<feature>_event.dart`
- `presentation/bloc/<feature>_state.dart`
