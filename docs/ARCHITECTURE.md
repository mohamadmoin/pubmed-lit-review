# Architecture — PubMed AI Literature Review

## Product summary

End-to-end system for **AI-assisted literature reviews** sourced from PubMed:

1. User submits topic + description + target word count
2. LLM plans document structure (sections)
3. PubMed search + relevance filtering per section
4. LLM selects papers; PMC full text retrieved when available
5. LLM writes sections with in-text citations
6. Graph persisted in Neo4j; large text on disk; `.docx` exported
7. User reads, downloads, and explores citations in Flutter UI (or CLI)

## High-level diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Client layer                              │
├──────────────────────┬──────────────────────────────────────────┤
│  Flutter frontend    │  CLI (litreview generate ...)            │
│  auth + doc list     │  direct pipeline / API client              │
└──────────┬───────────┴──────────────────┬───────────────────────┘
           │ REST + Token auth             │
           ▼                               ▼
┌─────────────────────────────────────────────────────────────────┐
│  Django REST API (port 8001)                                     │
│  • authentication — register, login, token                         │
│  • documents — CRUD, generate, content, download, full_text, logs│
└──────────┬──────────────────────────────────────────────────────┘
           │ Celery delay
           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Celery worker                                                   │
│  generate_document_task → DocumentGenerator                      │
└──────────┬──────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Generation pipeline (documents/python_document_generated_graph) │
│  ai_pubmed_search.py ─┬─ pubmed_structured_retrieval.py         │
│                       ├─ engine/entrez_client.py (NCBI)          │
│                       ├─ text_budget.py (local LLM context)    │
│                       └─ litreview.llm_client (OpenAI/LM Studio) │
│  document_generator.py → neo4j_client.py                         │
└──────────┬───────────────────────────────┬──────────────────────┘
           │                               │
           ▼                               ▼
    ┌─────────────┐                 ┌──────────────┐
    │   Neo4j     │                 │  Filesystem  │
    │   (graph)   │                 │ text_storage │
    └─────────────┘                 └──────────────┘
           ▲
           │ broker
    ┌─────────────┐
    │   Redis     │
    └─────────────┘
```

## Backend components

| Component | Path | Responsibility |
|-----------|------|----------------|
| Django project | `backend/litreview/` | Settings, URLs, Celery, LLM client |
| Documents app | `backend/documents/` | Models, views, tasks, Neo4j client |
| Pipeline | `backend/documents/python_document_generated_graph/` | PubMed + LLM synthesis |
| Auth app | `backend/authentication/` | Token auth (minimal) |
| SQLite | `backend/db.sqlite3` | Users, tokens, generation requests |
| Neo4j | Docker service | Documents, sections, papers, logs |

## Frontend components

| Area | Path | Responsibility |
|------|------|----------------|
| Entry | `frontend/lib/main.dart` | Auth gate → document list |
| Routes | `frontend/lib/app.dart` | Login, register, document flows only |
| Hub | `ui/pages/documents/documents_list_page.dart` | History + start generation |
| Generation | `document_generation_page.dart`, progress screens | Form + live steps |
| Reader | `document_preview_screen.dart`, `document_view_page.dart` | Citations, download |
| Services | `core/services/document_service.dart` | API client |
| State | `core/providers/document_provider.dart` | Document list + generation |

## API surface (kept)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/auth/register/` | Create user + token |
| POST | `/api/auth/login/` | Obtain token |
| GET | `/api/documents/` | List user's documents |
| POST | `/api/documents/generatedocument/` | Start generation |
| GET | `/api/documents/{id}/content/` | Full document payload |
| GET | `/api/documents/{id}/process_logs/` | Generation progress |
| GET | `/api/documents/{id}/download/` | Word export |
| GET | `/api/documents/{id}/papers/{pmid}/full_text/` | Paper full text |
| GET | `/api/documents/status/` | Health check |

## Data model

### SQLite (`DocumentGenerationRequest`)

Tracks async jobs: subject, description, word_count, status, user, document_id (Neo4j UUID).

### Neo4j (primary document store)

- **Document** — metadata, file_path, user_id
- **Section** — title, content_path (filesystem), search terms
- **Paper** — pmid, pmc_id, abstract, full_text_path
- **ProcessLog** — step messages for UI progress
- **References** — formatted bibliography

### Filesystem (`data/text_storage/`)

Section bodies, paper full text, generated `.docx` files (shared volume: django + celery).

## External dependencies

| Service | Protocol | Config |
|---------|----------|--------|
| NCBI Entrez | HTTPS E-utilities | `PUBMED_EMAIL`, optional `PUBMED_API_KEY` |
| OpenAI | HTTPS API | `OPENAI_API_KEY` when `LLM_PROVIDER=openai` |
| LM Studio | Local OpenAI-compatible | `LM_STUDIO_BASE_URL` when `LLM_PROVIDER=lmstudio` |
| Neo4j | Bolt | `NEO4J_URI`, `NEO4J_USER`, `NEO4J_PASSWORD` |
| Redis | TCP | `REDIS_URL` |

## Security model

- DRF Token authentication on document endpoints
- `AllowAny` only on register/login
- No secrets in repository; `.env` gitignored
- CORS configured for local Flutter web/desktop dev

## Scope

This repository contains the literature review product only: document generation API, Flutter client, CLI, and supporting infrastructure.

## Extension points

1. **New LLM provider** — add branch in `litreview/llm_client.py`
2. **Alternative vector store** — replace or supplement Neo4j (future)
3. **PDF export** — extend `ai_pubmed_search.create_word_document` pattern
4. **OAuth** — replace token auth in `authentication/`
