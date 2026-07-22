# Contributing to LitReview

Thank you for your interest in contributing.

## Getting started

1. Fork the repository
2. Copy `.env.example` to `.env` and configure PubMed email + LLM
3. Start the stack:

```bash
./scripts/start.sh
# or for backend live reload:
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build
```

4. For **frontend UI changes** (requires Flutter SDK):

```bash
cd frontend && flutter pub get && flutter analyze
flutter run -d chrome
```

5. To rebuild the bundled web app locally:

```bash
./scripts/build-web.sh
```

## Pull requests

- Keep changes focused on literature review functionality
- No secrets or credentials in code or commits
- Update README or docs if you change setup or API behavior
- Run `dart analyze` (frontend) before submitting UI changes
- Bump [`VERSION`](VERSION) and [`CHANGELOG.md`](CHANGELOG.md) only on releases (see [docs/RELEASE.md](docs/RELEASE.md))

## Code style

- **Python**: follow existing Django/DRF patterns in `backend/documents/`
- **Dart**: follow `flutter_lints`; match existing widget structure
- **API URLs**: use `AppConfig.current.apiBaseUrl` — do not hardcode host/port

## Reporting issues

Include: OS, Docker/Flutter versions, `.env` settings (redact secrets), steps to reproduce, and relevant API or Celery logs.

## Releases

Maintainers: see [docs/RELEASE.md](docs/RELEASE.md).
