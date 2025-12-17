# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

This is a Swift/Xcode project. Use Xcode or xcodebuild:

```bash
# Build for macOS
xcodebuild -project PocketBaseAdminApp.xcodeproj -scheme PocketBaseAdminApp -destination 'platform=macOS' build

# Build for iOS Simulator
xcodebuild -project PocketBaseAdminApp.xcodeproj -scheme PocketBaseAdminApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run tests
xcodebuild -project PocketBaseAdminApp.xcodeproj -scheme PocketBaseAdminApp -destination 'platform=macOS' test
```

For development, open `PocketBaseAdminApp.xcodeproj` in Xcode.

## Architecture

### App Structure

Native SwiftUI admin client for PocketBase with cross-platform support (macOS 15+, iOS 18+, visionOS 2+, watchOS).

**Main Entry Point**: `PocketBaseAdminApp.swift` - Sets up the main window with authentication and PocketBase connection. Uses conditional compilation for different environments:
- Simulator/macOS: localhost
- DEBUG on device: local network IP
- Release: production URL

**Core Dependencies** (via Swift Package Manager):
- `PocketBase` - Swift client library (local package at `../PocketBase`)
- `PocketBaseUI` - UI components from PocketBase package
- `PocketBaseAdmin` - Admin API components from PocketBase package
- `BetterTable` - Enhanced table components (macOS only, local package)
- `NukeUI` - Async image loading

### State Management

Uses Swift's Observation framework (`@Observable`):
- `CollectionsState` - Manages list of collections loaded from PocketBase
- `CollectionState` - Per-collection state including records, pagination, and retry logic
- `Admin.Settings` - Application settings state

State is passed through SwiftUI environment using `.environment()`.

### Navigation

Adaptive tab-based navigation using `TabView` with `.sidebarAdaptable` style:
- Responds to `horizontalSizeClass` for compact vs regular layouts
- Main tabs: Collections, Logs, Settings
- Settings sections: System, Sync, Authentication

### Key Views

- `ContentView.swift` - Main navigation structure with adaptive TabView
- `CollectionView.swift` - Displays records in a Table with inspector panel
- `SettingsView.swift` - Settings navigation (compact layout)
- Individual settings views: `ApplicationSettingsView`, `MailSettingsView`, `FilesSettingsView`, `BackupsView`, etc.

### Platform Considerations

- macOS defines custom `UserInterfaceSizeClass` enum since `horizontalSizeClass` isn't available
- Conditional compilation (`#if os(macOS)`, `#if os(iOS)`) used throughout for platform-specific behavior
- Watch app is a separate target with its own SwiftUI views
