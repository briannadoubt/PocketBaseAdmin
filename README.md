# PocketBase Admin

A native SwiftUI admin client for PocketBase that provides a comprehensive interface for managing your PocketBase instances.

## Features

- 🔐 **Secure Authentication** - Superuser authentication with keychain storage
- 📊 **Collection Management** - Browse, view, and manage all collections and records
- ⚙️ **Settings Management** - Configure PocketBase settings including SMTP, S3, backups, and more
- 📱 **Cross-Platform** - Native support for macOS, iOS, and visionOS
- 🔄 **Real-time Updates** - Live data synchronization with PocketBase instances
- 📝 **Logs Viewer** - Monitor and review PocketBase application logs
- 🎨 **Modern UI** - Clean, intuitive SwiftUI interface with proper responsive design

## Requirements

- iOS 18.0+ / macOS 15.0+ / visionOS 2.0+
- Xcode 16.0+
- Swift 6.0+
- PocketBase instance (local or remote)

## Getting Started

### Quick Start

1. **Run PocketBase**: Start your PocketBase instance (see [PocketBase docs](https://pocketbase.io/docs/))
2. **Launch App**: Open PocketBaseAdmin
3. **Connect**: Configure your PocketBase URL in the app
4. **Authenticate**: Sign in with your superuser credentials

### Configuration

The app supports both local and remote PocketBase instances:

- **Local Development**: Uses `localhost:8090` by default
- **Local Network**: Configure your Mac's IP address for device testing
- **Production**: Set your production PocketBase URL

### Features Overview

#### Collections View
- Browse all collections (user and system)
- View collection schemas and field types
- Browse and search records within collections
- Support for different field types (text, files, relations, etc.)

#### Settings Management
- SMTP configuration for email delivery
- S3 configuration for file storage
- Backup settings and scheduling
- Rate limiting and security settings
- Token management and expiration

#### Logs Viewer
- Real-time log monitoring
- Filter logs by level and content
- Export and share log data

## Architecture

The app is built using:
- **SwiftUI** for the user interface
- **PocketBase Swift Library** for API communication
- **Observation Framework** for reactive data binding
- **SwiftData** integration (planned)

## Development

### Building from Source

```bash
git clone <repository-url>
cd PocketBaseAdmin
open PocketBaseAdminApp.xcodeproj
```

### Dependencies

- [PocketBase Swift](../PocketBase) - Core PocketBase client library
- [SDWebImageSwiftUI](https://github.com/SDWebImage/SDWebImageSwiftUI) - Async image loading

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

[Add your license information here]

## Support

- [PocketBase Documentation](https://pocketbase.io/docs/)
- [GitHub Issues](../../issues)
- [Discussions](../../discussions)