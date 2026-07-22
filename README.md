# LitReview

**AI-powered literature reviews from PubMed** — search papers, retrieve full text, synthesize sections with configurable LLMs, export Word documents.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Features

- PubMed search with relevance filtering per document section
- PMC full-text retrieval when available
- LLM synthesis with numbered citations (OpenAI or local LM Studio)
- Async generation via Celery with live progress logs
- Neo4j graph storage + filesystem hybrid for large texts
- Flutter UI (login, document history, reader, Word download)
- REST API with OpenAPI docs (`/api/docs/`)
- CLI for headless use

## Quick start (Docker)

```bash
git clone https://github.com/mohamadmoin/litreview.git
cd litreview
cp .env.example .env
# Edit .env: set PUBMED_EMAIL (required), NEO4J_PASSWORD, LLM settings

docker compose up -d --build
```

| Service | URL |
|---------|-----|
| API | http://127.0.0.1:8002/api |
| Swagger | http://127.0.0.1:8002/api/docs/ |
| Neo4j Browser | http://127.0.0.1:7475 |

> **Note:** Default host port is **8002** to avoid clashing with other local services. Change `ports` in `docker-compose.yml` if needed.

### LLM setup

**Local (default)** — [LM Studio](https://lmstudio.ai/): load a model, start server on port 1234, set:

```env
LLM_PROVIDER=lmstudio
LM_STUDIO_BASE_URL=http://host.docker.internal:1234/v1
LM_STUDIO_MODEL=google/gemma-4-12b
```

**OpenAI**:

```env
LLM_PROVIDER=openai
OPENAI_API_KEY=your-openai-key
OPENAI_MODEL=gpt-4o-mini
```

### PubMed / NCBI

NCBI requires a contact email for Entrez API use:

```env
PUBMED_EMAIL=your.email@example.com
PUBMED_TOOL=LitReview
PUBMED_API_KEY=          # optional, increases rate limits
```

Register: https://www.ncbi.nlm.nih.gov/account/settings/

## Flutter client

```bash
cd frontend
flutter pub get
flutter run -d windows   # or chrome, macos, etc.
```

API base URL: `http://127.0.0.1:8002/api` (see `lib/core/config/app_config.dart`).

After login, the **document list** is the home screen — start a new literature review from the FAB.

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
litreview/
├── backend/          Django API + Celery + generation pipeline
├── frontend/         Flutter client
├── cli/              Command-line interface
├── docs/             Architecture documentation
├── data/             Generated text and .docx (gitignored)
└── docker-compose.yml
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for system design.

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
# Backend locally (requires Neo4j + Redis running)
cd backend
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 0.0.0.0:8001

# Celery worker (separate terminal)
celery -A litreview worker -l INFO
```

## License

MIT — see [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
