# Changelog

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
