# Getting started with LitReview

This guide is for **researchers and non-developers** who want to run LitReview locally without installing Flutter, Python, or Neo4j manually.

Developers who want to change code should also read [CONTRIBUTING.md](../CONTRIBUTING.md).

## What you need

| Requirement | Why |
|-------------|-----|
| **Docker Desktop** | Runs the database, API, and background workers |
| **Flutter SDK** | One-time build of the web UI (`scripts/build-web.sh`) |
| **An LLM** | OpenAI API key **or** [LM Studio](https://lmstudio.ai/) running on your computer |
| **PubMed email** | NCBI requires a contact email for literature searches |
| **~4 GB free disk** | Docker images and generated documents |

You do **not** need Python or Node.js. Flutter is only used to **build** the web app once (or after UI updates) — not while using the app day to day.

## Quick start (recommended)

### macOS / Linux

```bash
git clone https://github.com/mohamadmoin/pubmed-lit-review.git
cd pubmed-lit-review
./scripts/start.sh
```

### Windows

Double-click `scripts/start.bat`, or run it from Command Prompt.

The script will:

1. Create `.env` from the template (first run only)
2. Build and start all services
3. Open **http://127.0.0.1:8002/** in your browser

### First-time `.env` setup

When `.env` is created, edit these values before generating documents:

```env
# Required — use your real email (NCBI policy)
PUBMED_EMAIL=your.email@example.com

# Required — pick any strong password (used by Neo4j)
NEO4J_PASSWORD=choose-a-strong-password
```

## Choosing an LLM (required for document generation)

LitReview needs a language model to write and synthesize sections. Pick **one** option:

### Option A — OpenAI (easiest if you have an API key)

```env
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-your-key-here
OPENAI_MODEL=gpt-4o-mini
```

No extra software to install. Usage is billed by OpenAI.

### Option B — LM Studio (free, runs on your machine)

1. Install [LM Studio](https://lmstudio.ai/)
2. Download and load a model (e.g. Gemma, Llama, or Mistral)
3. Open **Local Server** tab and click **Start Server** (default port **1234**)
4. In `.env`:

```env
LLM_PROVIDER=lmstudio
LM_STUDIO_BASE_URL=http://host.docker.internal:1234/v1
LM_STUDIO_MODEL=your-model-id-from-lm-studio
```

Keep LM Studio running while generating documents.

> **Note:** `host.docker.internal` lets Docker reach LM Studio on your computer. On Linux, Docker Compose already maps this; if it fails, see [Troubleshooting](#troubleshooting).

## Using the web app

1. Open **http://127.0.0.1:8002/** — the app starts in **guest mode** automatically (no sign-in required for local open-source use)
2. Click **+** to start a new literature review
3. Enter your topic, wait for generation (progress is shown live)
4. Read the result in the app or download Word (`.docx`)

Optional: click **Sign in** in the top bar to use your own account, or register a new one. Login remains available at `/login`.

> Guest mode uses a shared local `demo` account. Set `LITREVIEW_DEMO_MODE=False` in `.env` to require sign-in (recommended for public deployments).

## What runs in the background

| Service | What it does | You interact with it? |
|---------|--------------|------------------------|
| **Web app** | Browser UI at port 8002 | Yes — this is what you open |
| **API** | Handles login, documents, downloads | Automatically used by the web app |
| **Celery worker** | Long-running document generation | No — runs in Docker |
| **Neo4j** | Stores paper relationships | No — optional browser at port 7475 |
| **Redis** | Task queue for Celery | No |

## Stopping and restarting

```bash
docker compose down          # stop
docker compose up -d         # start again (no rebuild)
./scripts/start.sh           # rebuild + start + open browser
```

Your documents and account persist in Docker volumes and the `./data` folder until you remove volumes.

## Troubleshooting

### “Web app not built” or blank page

Build the Flutter web app, then restart:

```bash
./scripts/build-web.sh
docker compose up -d
```

If `flutter` is not found, install Flutter and ensure it is on your PATH (restart the terminal after install).

### `Package not available (authorization failed)` during build

This means your machine cannot reach **pub.dev** to download packages (common with regional network restrictions, ISP blocks, or VPN/firewall interference). It is **not** a bug in this repo.

Try in order:

```bash
cd frontend
flutter pub get -v          # see which package fails
```

1. **Toggle VPN** — try with VPN on, or off if VPN is blocking pub.dev
2. **Check stale pub tokens:**
   ```bash
   dart pub token list
   dart pub token remove https://pub.dev   # only if a bad token is listed
   ```
3. **Retry on a different network** (mobile hotspot, etc.)

After `flutter pub get` succeeds once, `./scripts/build-web.sh` should work.

### Document generation fails immediately

1. Check `.env`: `PUBMED_EMAIL` must be set
2. Check LLM:
   - **OpenAI:** valid `OPENAI_API_KEY`
   - **LM Studio:** server running, model loaded, `LM_STUDIO_MODEL` matches the loaded model ID
3. View logs:

```bash
docker compose logs django celery
```

### LM Studio not reachable from Docker

- Confirm the LM Studio server is started (green/running in the app)
- Try `LM_STUDIO_BASE_URL=http://host.docker.internal:1234/v1` in `.env`
- Restart: `docker compose down && docker compose up -d`

### Port 8002 already in use

Edit `docker-compose.yml` and change `"8002:8001"` to another host port (e.g. `"8080:8001"`), then open `http://127.0.0.1:8080/`.

## What cannot be simplified (and why)

| Step | Why it’s required |
|------|-------------------|
| **PubMed email** | NCBI Entrez API policy — identifies your organization for fair use |
| **LLM setup** | Synthesis is done by an external model; we don’t ship model weights |
| **Docker** | Bundles Neo4j, Redis, and Python API so you don’t install each piece |
| **Flutter build (once)** | Compiles the browser UI into `backend/frontend_dist/` — Docker serves those static files |
| **First build time** | Flutter web compile (~2–5 min) + Docker image pull on first run |

## Next steps

- [README](../README.md) — feature overview and CLI
- [ARCHITECTURE.md](ARCHITECTURE.md) — how the system works
- [RELEASE.md](RELEASE.md) — version numbers and releases (for maintainers)
