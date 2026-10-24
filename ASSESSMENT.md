# Package assessment

Reviewed on 24 October 2026 against Flutter 3.47.8 / Dart 3.13.7.

The package has useful separation between schema parsing, template rendering,
process execution, and CLI orchestration. Injectable process runners and explicit
project roots make the core straightforward to test. BLoC, Riverpod, and GetX
share the same domain and data templates, limiting duplicated generation logic.

## Improvements implemented

| Finding | Result |
| --- | --- |
| Flutter development version was unspecified. | `.fvmrc` pins 3.47.8 and CI reads that pin. The Dart minimum is now 3.13.7; the CLI still works as a Dart package. |
| Features with only parameterless methods omitted every use case despite presentation code importing them. | All API methods receive use cases, including `NoParams` methods in single- and multi-response schemas. |
| A Riverpod feature named `user_profile` referenced `user_profileProvider`, while the declared provider was `userProfileProvider`. | Screens use the same camelCase name as the declaration and watch state changes. |
| A missing `dev_dependencies` section discarded the existing runtime dependency map. | Optional sections are read independently; malformed or unreadable manifests stop installation. |
| Dependency installation, builders, or formatting could fail while the CLI reported success. | Failures stop the pipeline and produce an error exit; generated files remain available for diagnosis. |
| Feature names were interpolated into output paths without validation. | Names must follow lowercase snake_case before project lookup or generation. |
| Errors went to stdout and help referenced a nonexistent executable path. | Errors use stderr and refer to the installed CLI command. |
| The README claimed CI validation, but only release/publication workflows existed. | Pushes and PRs run formatting, analysis, unit tests, generated Flutter checks, and publication validation. Publication depends on validation. |
| Tests checked generated text without compiling the generated app. | `tool/check_generated.dart` builds nine real feature variants with pub.dev dependencies, analyzes them, and tests nested model-to-entity conversion. |
| Dependencies and builder invocation lagged behind the selected SDK. | Dependency constraints are refreshed, the unused direct `path` dependency is removed, and the obsolete builder flag is omitted. |

## Remaining improvement opportunities

These are follow-up changes with schema or generated API design implications;
the SDK upgrade does not address them.

1. **High: validate all generated identifiers and detect collisions.**
   `Parser.buildContextFields` creates nested class names from only the field
   key. A single response containing a scalar `id` alongside `billing.address`
   and `shipping.address` produces two `Address` classes in the same file. Fields such as `class` or
   `first-name` also produce invalid Dart identifiers, and `user_id` plus
   `userId` can normalize to the same property. Introduce path-based nested
   names, deterministic identifier normalization, and collision errors before
   dependency installation or file writes. Apply the same checks to API method
   and response entity names.

2. **High: validate schema shapes and response references strictly.**
   `Schema.fromJson`, `Methods.fromJson`, and `ApiMethod.fromJson` rely on casts
   for several user-controlled values. For example, a top-level JSON array or
   `api.methods.getUser: 1` raises a type error. An unknown method response
   reference currently logs warnings and becomes `void`, which can hide a typo.
   Report the schema path and expected shape, and reject unresolved references.
   Validate array descriptors rather than accepting only their first element.

3. **Medium: make response mode explicit when ambiguous.**
   `Schema.fromJson` interprets any nonempty object whose values are all objects
   as multiple named responses. A single response containing only a nested
   `profile` object therefore becomes a named entity unexpectedly. An explicit
   mode or a distinct `responses` key would remove this ambiguity, with a
   migration path for existing schemas.

4. **Medium: protect shared infrastructure during overwrite.**
   `Generator.generateBoilerplate` passes `--overwrite` through to the shared
   injector and base use-case templates. Regenerating one feature can replace
   manually maintained dependency registration used by other features. Prefer
   preserving shared files or updating a clearly marked generated section, with
   separate explicit control for replacing shared infrastructure.

5. **Medium: separate library error handling from process termination.**
   `CommandHelper.error` and `success` call `exit`, so direct library use can
   terminate the caller. Typed generation errors and exit handling confined to
   `bin/feature_gen_cli.dart` would simplify embedding, structured diagnostics,
   and future dry-run support.

## Validation and scope

Validation passed: 75 unit tests, formatting, static analysis, nine generated
Flutter feature variants, and a generated model conversion test. A publication
dry run from a clean temporary copy reported zero warnings.

The generated-project check covers three layers crossed with single responses,
root list responses, and multiple responses. It includes parameterless methods,
query/body/path parameters, nested request objects, list and void return types,
snake_case JSON keys, nested response objects, and model-to-entity conversion.
Remote datasource methods remain intentional `UnimplementedError` scaffolds;
network behavior is supplied by the consuming application.

Raising the SDK floor means Dart versions below 3.13.7 must continue using an
older package release. Local validation uses macOS; CI is configured for Linux.
