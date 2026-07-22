# LitReview

**AI-powered literature reviews from PubMed** — search papers, retrieve full text, synthesize sections with configurable LLMs, export Word documents.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](VERSION)

## Features

- PubMed search with relevance filtering per document section
- PMC full-text retrieval when available
- LLM synthesis with numbered citations (OpenAI or local LM Studio)
- Async generation via Celery with live progress logs
- Neo4j graph storage + filesystem hybrid for large texts
- **Web app** — open in your browser, no Flutter install required
- REST API with OpenAPI docs (`/api/docs/`)
- CLI for headless use

## Quick start (non-developers)

**Requirements:** [Docker Desktop](https://docs.docker.com/get-docker/) + [Flutter SDK](https://docs.flutter.dev/get-started/install) (one-time web build) + an LLM (OpenAI key or [LM Studio](https://lmstudio.ai/))

```bash
git clone https://github.com/mohamadmoin/pubmed-lit-review.git
cd pubmed-lit-review
./scripts/start.sh          # macOS / Linux — builds web UI, starts Docker, opens browser
# scripts\start.bat         # Windows
```

Or step by step:

```bash
cp .env.example .env        # edit PUBMED_EMAIL, NEO4J_PASSWORD, LLM settings
./scripts/build-web.sh      # build Flutter web → backend/frontend_dist/
docker compose up -d --build
# open http://127.0.0.1:8002/
```

| Service | URL |
|---------|-----|
| **Web app** | http://127.0.0.1:8002/ |
| API | http://127.0.0.1:8002/api |
| Swagger | http://127.0.0.1:8002/api/docs/ |
| Neo4j Browser | http://127.0.0.1:7475 |

> Default host port is **8002** to avoid clashing with other local services.

## Documentation

| Guide | Audience |
|-------|----------|
| [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) | First-time users, troubleshooting, LLM setup |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design |
| [docs/RELEASE.md](docs/RELEASE.md) | Versioning and releases |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Developers |

## Flutter development (optional)

Only needed if you are **changing the UI**. End users should use the web app via Docker.

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

API base URL defaults to `http://127.0.0.1:8002/api`. The bundled web build uses `/api` (same origin).

Rebuild the web app into the backend:

```bash
./scripts/build-web.sh
```

## CLI

```bash
python cli/litreview.py health --api-url http://127.0.0.1:8002/api
python cli/litreview.py register --username demo --email demo@example.com --password secret123
python cli/litreview.py login --username demo --password secret123
python cli/litreview.py generate --token YOUR_TOKEN --subject "Machine learning in drug discovery" --words 2500 --wait
```

Set `LITREVIEW_API_URL` to override the default API base.

## Project structure

```
pubmed-lit-review/
├── backend/          Django API + Celery + generation pipeline
├── frontend/         Flutter client (web build bundled in Docker)
├── scripts/          start.sh, build-web.sh, release.sh
├── cli/              Command-line interface
├── docs/             User and developer documentation
├── VERSION           Release version (single source of truth)
├── backend/Dockerfile  Python API image (web UI built separately)
└── docker-compose.yml
```

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PUBMED_EMAIL` | Yes | NCBI Entrez contact email |
| `DJANGO_SECRET_KEY` | Yes (prod) | Django secret |
| `NEO4J_PASSWORD` | Yes | Neo4j password (match docker-compose) |
| `LLM_PROVIDER` | No | `lmstudio` (default) or `openai` |
| `OPENAI_API_KEY` | If OpenAI | Cloud LLM key |
| `LM_STUDIO_BASE_URL` | If local | OpenAI-compatible endpoint |
| `PUBMED_API_KEY` | No | NCBI API key for higher limits |

Full list: [.env.example](.env.example)

## Development

```bash
# Backend live reload inside Docker
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build

# Or run backend locally (requires Neo4j + Redis)
cd backend
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 0.0.0.0:8001
```

## License

MIT — see [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
