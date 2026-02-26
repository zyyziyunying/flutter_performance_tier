# Repository Guidelines

## Scope
- This file covers `flutter_performance_tier/` only.
- Workspace-level coordination rules live in `../AGENTS.md`.

## Project Structure & Module Organization
- `lib/performance_tier/` contains the core package, split into `config/`, `engine/`, `model/`, `policy/`, and `service/`.
- `lib/main.dart` is the demo app entry point used for local validation.
- `android/app/src/main/kotlin/com/example/flutter_performance_tier/` holds native Android channel code (for example, `DeviceSignalChannelHandler.kt`).
- `ios/Runner/` is the iOS host app scaffold.
- `test/performance_tier/` covers tiering logic; `test/widget_test.dart` keeps a basic widget smoke test.
- Treat `.dart_tool/` and `build/` as generated output.

## Build, Test, and Development Commands
- `flutter pub get` - install or update dependencies from `pubspec.yaml`.
- `flutter analyze` - run static analysis using project lints.
- `dart format lib test` - format source and test files before commit.
- `flutter test` - run unit and widget tests.
- `flutter run` - launch the app locally for manual checks.
- `flutter build apk --release` - build a release APK for packaging checks.

## Coding Style & Naming Conventions
- Follow `analysis_options.yaml` (`package:flutter_lints/flutter.yaml`).
- Use 2-space indentation in Dart; prefer trailing commas to keep formatter-friendly diffs.
- Naming: files in `snake_case.dart`, types in `PascalCase`, members in `camelCase`.
- Keep model and tier decision objects immutable and explicit; avoid hidden side effects in engine logic.

## Testing Guidelines
- Use `flutter_test` with behavior-focused test names (example: `returns low tier when low-ram device is reported`).
- Mirror `lib/` structure under `test/` when adding coverage.
- Add deterministic tests for new rules in engine, policy resolver, and service orchestration.
- No enforced coverage threshold yet; increase coverage with each feature or bug fix.

## Commit & Pull Request Guidelines
- Prefer Conventional Commit prefixes, as seen in history (for example, `feat: scaffold performance tier...`).
- Keep commit messages concise and imperative; split unrelated changes into separate commits.
- PRs should include purpose, key changes, and validation steps run (`flutter analyze`, `flutter test`).
- Link related issues or tasks, and include screenshots or recordings for UI-visible changes.

## Security & Configuration Tips
- Never commit secrets, keystores, or signing credentials.
- Keep MethodChannel contracts synchronized across Dart and platform code (`performance_tier/device_signals`).
