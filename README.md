# Whale 🐋

[![CI](https://github.com/thangminhtran/Whale/actions/workflows/ci.yml/badge.svg)](https://github.com/thangminhtran/Whale/actions/workflows/ci.yml)
[![Release](https://github.com/thangminhtran/Whale/actions/workflows/release.yml/badge.svg)](https://github.com/thangminhtran/Whale/actions/workflows/release.yml)

A native macOS application that provides a unified, modern interface for AI coding assistants. Whale brings together Claude Code, Cursor, and Codex CLI tools into a single, streamlined workspace.

## Overview

Whale is a SwiftUI-based macOS app that acts as a GUI wrapper for multiple AI coding assistant CLI tools. It manages your projects and sessions, providing persistent chat history, syntax highlighting, and a clean interface for interacting with AI agents.

## Features

- **Multi-Provider Support**: Seamlessly work with Claude Code, Cursor, and Codex from one interface
- **Project Management**: Add and switch between multiple projects with automatic session organization
- **Session Persistence**: All conversations are saved and restored across app launches
- **Git Integration**: Displays current branch information for each project
- **Rich Code Display**: 
  - Syntax highlighting for multiple languages
  - Copyable code blocks
  - Diff visualization for code changes
  - Markdown rendering with inline code support
- **Real-time Streaming**: Watch AI responses arrive in real-time with step-by-step visualization
- **Provider Switching**: Transfer conversation context between different AI providers mid-session
- **Dark Mode**: Beautiful dark-themed interface optimized for coding

## Requirements

- macOS 14.0 or later
- At least one of the following CLI tools installed:
  - `claude` (Claude Code CLI)
  - `cursor-agent` (Cursor CLI)
  - `codex` (Codex CLI)

## Architecture

### Domain Models
- **Project**: Represents a code project with path, display name, and timestamps
- **Session**: Manages a conversation with an AI provider, tracking session ID, provider type, model, and activity
- **Step**: Individual interaction steps (user prompts, agent responses, tool calls)
- **Provider**: Enumeration of supported AI providers (Claude, Cursor, Codex)
- **PermissionMode**: Controls agent permissions (allow all, confirm, deny)

### Services
- **AgentCLIService**: Protocol for wrapping provider CLIs as subprocesses
  - `ClaudeCLIService`: Claude Code CLI integration
  - `CursorCLIService`: Cursor CLI integration
- **ProcessStreamRunner**: Manages subprocess execution and output streaming
- **JSONLineDecoder**: Parses JSON Lines format from CLI streams
- **Event Parsers**: Provider-specific parsing of CLI output
- **Persistence**: Project and session storage using JSON files

### UI Components
- **SessionView**: Main chat interface with message timeline
- **ComposerView**: Input area for user prompts with attachment support
- **StepTimelineView**: Visualizes conversation steps with expandable details
- **CodeSyntaxHighlighter**: Renders code blocks with syntax highlighting
- **DiffCodeBlock**: Shows code diffs with add/remove highlighting
- **SessionSidebarView**: Lists all sessions for the current project

## Installation

### Download Pre-built Release

Download the latest release from the [Releases page](https://github.com/thangminhtran/Whale/releases):
- **DMG**: Download `.dmg`, open it, and drag Whale to Applications
- **ZIP**: Download `.zip`, extract, and move to Applications

### Build from Source

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project file generation.

```bash
# Install XcodeGen if needed
brew install xcodegen

# Generate the Xcode project
xcodegen

# Build release (creates DMG and ZIP in dist/)
make release

# Or build and run debug version
make run

# Or open in Xcode
open Whale.xcodeproj
```

Available make commands:
- `make build` - Build debug version
- `make release` - Build release version with DMG and ZIP
- `make run` - Build and run debug version
- `make test` - Run unit tests
- `make clean` - Clean build artifacts
- `make install` - Install release build to /Applications

## Usage

1. **Add a Project**: Use File → Open Project (⌘O) or the onboarding screen to add a project folder
2. **Create Sessions**: Start conversations with your preferred AI provider
3. **Send Prompts**: Type your coding questions or requests in the composer
4. **View Results**: Watch as the AI agent responds with code, explanations, and tool calls
5. **Switch Providers**: Change AI providers mid-conversation to leverage different models
6. **Manage Sessions**: Browse past conversations in the sidebar, organized by project

## Project Structure

```
Whale/
├── Domain/              # Core data models
├── Services/            # CLI integration and business logic
│   ├── Parsing/         # Provider-specific event parsers
│   └── Persistence/     # Data storage
├── ViewModels/          # MVVM view models
├── Views/               # SwiftUI views
│   ├── DesignSystem/    # Theme and styling
│   ├── Onboarding/      # Project setup views
│   ├── Session/         # Chat interface components
│   └── Sidebar/         # Navigation components
└── Support/             # Utilities and helpers

WhaleTests/              # Unit tests
```

## Testing

The project includes unit tests for core functionality:
- JSON Lines decoding
- Process stream handling
- Markdown text parsing

Run tests in Xcode with ⌘U or via:
```bash
xcodebuild test -scheme Whale
```

## CI/CD

This project uses GitHub Actions for continuous integration and release automation:

### CI Workflow
Runs on every push and pull request to `main` or `develop`:
- Generates Xcode project with XcodeGen
- Builds the app
- Runs all unit tests
- Checks for compilation warnings

### Release Workflow
Triggers when pushing a version tag (e.g., `v1.0.0`):
- Builds release version of the app
- Creates distributable `.dmg` and `.zip` files
- Generates SHA-256 checksums
- Automatically creates a GitHub Release with download links

To create a release:
```bash
git tag v1.0.0
git push origin v1.0.0
```

## License

Copyright © 2026 Thang Minh Tran

## Contributing

This is a personal project. Feel free to fork and adapt for your own use.
