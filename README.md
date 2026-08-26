# 💠 Tesservox

[![CI](https://github.com/DARREN-2000/tesservox/actions/workflows/ci.yaml/badge.svg)](https://github.com/DARREN-2000/tesservox/actions/workflows/ci.yaml)
[![GitHub Pages](https://github.com/DARREN-2000/tesservox/actions/workflows/pages.yml/badge.svg)](https://github.com/DARREN-2000/tesservox/actions/workflows/pages.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

> The ultimate, secure, offline-first AAC platform for unparalleled speech independence.

**Tesservox** (formerly vaani) is a free, offline, multilingual AAC (augmentative and alternative communication) system designed for individuals who cannot speak. It runs on minimal hardware, requires no cloud synchronization, and respects user privacy by keeping all operations local.

## 🚀 Key Features

- **Offline-First**: Does not require an internet connection, ever.
- **Privacy Guaranteed**: No accounts, no data telemetry.
- **Cross-Platform**: Builds effortlessly on Android, Web, and Desktop.
- **Accessible Interface**: Optimized for diverse motor needs.

## 🏗 Architecture

Tesservox strictly adheres to a domain-driven architectural pattern utilizing Riverpod for pure-Dart dependency injection, ensuring the application stays fast and maintainable.

```mermaid
graph TD;
    UI[Flutter UI Layer] --> DI[Riverpod State/DI Layer];
    DI --> Domain[Core Domain Logic];
    Domain --> LocalStorage[Shared Preferences];
    Domain --> TTS[Platform TTS];
```

## 🛠 Quick Start

Ensure you have [Flutter](https://flutter.dev/) installed.

```bash
# Get dependencies
flutter pub get

# Run the app
make run
```

## 🐋 Dockerization

We use a highly optimized multi-stage build.

```bash
# Build the Docker image
make docker-build

# Run via Docker Compose
docker-compose up
```

## 🤝 Governance

Tesservox operates under strict open-source governance. Please review:
- [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)
- [SECURITY.md](./SECURITY.md)
- [CONTRIBUTING.md](./CONTRIBUTING.md)
- [MAINTAINERS.md](./MAINTAINERS.md)
