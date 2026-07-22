# Contributing to LitReview

Thank you for your interest in contributing.

## Getting started

1. Fork the repository
2. Copy `.env.example` to `.env` and configure PubMed email + LLM
3. Run `docker compose up --build` from the repo root
4. For frontend changes: `cd frontend && flutter pub get && flutter analyze`

## Pull requests

- Keep changes focused on literature review functionality
- No secrets or credentials in code or commits
- Update README or docs if you change setup or API behavior
- Run `dart analyze` (frontend) before submitting UI changes

## Code style

- **Python**: follow existing Django/DRF patterns in `backend/documents/`
- **Dart**: follow `flutter_lints`; match existing widget structure

## Reporting issues

Include: OS, Docker/Flutter versions, `.env` settings (redact secrets), steps to reproduce, and relevant API or Celery logs.
