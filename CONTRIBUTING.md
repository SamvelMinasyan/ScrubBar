# Contributing to ScrubBar

Thanks for considering a contribution! ScrubBar is a small, focused project and we value clear, well-tested changes.

## Prerequisites

- macOS 13.0 or later
- Xcode 15+ or Swift 5.9+ Command Line Tools
- No external dependencies required

## Getting Started

```bash
git clone https://github.com/SamvelMinasyan/ScrubBar.git
cd ScrubBar/ScrubBar
swift build
swift test
```

## Development Workflow

1. **Fork** the repository and create a feature branch from `main`.
2. **Make your changes** — keep commits focused and atomic.
3. **Run tests** before pushing: `swift test` from the `ScrubBar/` directory.
4. **Open a pull request** with a clear description of what and why.

## Code Style

- **SwiftUI conventions** — Server Components where possible, `@State`/`@StateObject` for local state, `@EnvironmentObject` for shared state.
- **Use `os.Logger`** for logging, never `print()` in the app or core library. `print()` is acceptable only in CLI tools (`ScrubBarCLI`, `ScrubBarVerifier`).
- **No external dependencies** — ScrubBar uses only Swift stdlib and Apple frameworks. If your change requires a third-party package, open an issue first to discuss.
- **MARK comments** for section organization (e.g., `// MARK: - Actions`).
- **Test new detection patterns** — if you add a regex pattern to `PIIDetector`, add a corresponding test case in `PIIDetectorTests.swift`.

## Project Structure

```
ScrubBar/
├── Sources/
│   ├── ScrubBar/          # Main macOS menu bar app (SwiftUI)
│   ├── ScrubBarCore/      # Shared library (detection, state, file ops)
│   ├── ScrubBarCLI/       # Command-line file scrubber
│   └── ScrubBarVerifier/  # Verification utility
├── Tests/
│   └── ScrubBarTests/     # XCTest suite
└── Package.swift
```

## Reporting Bugs

Please [open an issue](../../issues/new) with:

- **macOS version** (e.g., macOS 14.2)
- **Steps to reproduce**
- **Expected behavior** vs. **actual behavior**
- **Console logs** if applicable (filter by `com.scrubbar` in Console.app)

## Adding Detection Patterns

ScrubBar detects PII using regex patterns in `PIIDetector.swift`. To add a new pattern:

1. Add a static constant for the type (e.g., `public static let MY_TYPE = "MYTYPE"`).
2. Add the regex in `compilePatterns()` using `addPattern(type:regex:)`.
3. Add a toggle entry in `DetectionSettingsView.allTypes`.
4. Write a test case in `PIIDetectorTests.swift`.
5. Use **synthetic test data only** — never include real PII in tests.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
