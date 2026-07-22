# Release process

LitReview uses [Semantic Versioning](https://semver.org/) (`MAJOR.MINOR.PATCH`).

## Single source of truth

| File | Purpose |
|------|---------|
| [`VERSION`](../VERSION) | Canonical version string |
| [`frontend/pubspec.yaml`](../frontend/pubspec.yaml) | Flutter app version (`x.y.z+build`) |
| [`backend/litreview/version.py`](../backend/litreview/version.py) | Reads `VERSION` for OpenAPI docs |
| [`CHANGELOG.md`](../CHANGELOG.md) | Human-readable release notes |

The Docker image reads `VERSION` at build time. OpenAPI `/api/docs/` shows the same version.

## Cutting a release

### 1. Bump the version

```bash
./scripts/release.sh patch   # 0.1.0 -> 0.1.1
./scripts/release.sh minor   # 0.1.0 -> 0.2.0
./scripts/release.sh major   # 0.1.0 -> 1.0.0
```

### 2. Update the changelog

Add a section under [`CHANGELOG.md`](../CHANGELOG.md):

```markdown
## [0.1.1] - 2026-07-22

### Fixed
- ...
```

Follow [Keep a Changelog](https://keepachangelog.com/) categories: Added, Changed, Fixed, Removed.

### 3. Commit and tag

```bash
git add VERSION frontend/pubspec.yaml CHANGELOG.md
git commit -m "Release v0.1.1"
git tag -a v0.1.1 -m "Release v0.1.1"
git push origin main
git push origin v0.1.1
```

### 4. Publish (optional)

Create a [GitHub Release](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository) from the tag. Paste the matching `CHANGELOG` section as release notes.

Tag pushes automatically run [`.github/workflows/release.yml`](../.github/workflows/release.yml), which verifies the Docker build.

## Docker image tags

After a release, rebuild and optionally tag the image locally:

```bash
VERSION=$(cat VERSION)
docker compose build
docker tag litreview-app:latest litreview-app:${VERSION}
```

## Pre-release checklist

- [ ] `./scripts/release.sh` run with correct bump level
- [ ] `CHANGELOG.md` updated
- [ ] `./scripts/build-web.sh` succeeds
- [ ] `./scripts/start.sh` works (web app at `http://127.0.0.1:8002/`)
- [ ] Register, login, and a short test generation succeed
- [ ] Git tag `vX.Y.Z` created and pushed

## Development vs production images

| Mode | Command | Web UI | Backend live reload |
|------|---------|--------|---------------------|
| **Normal** | `./scripts/build-web.sh && docker compose up -d` | Local build in `backend/frontend_dist/` | No |
| **Development** | `docker compose -f docker-compose.yml -f docker-compose.dev.yml up` | Same local build* | Yes (`./backend` mounted) |

\*After Flutter UI changes: `./scripts/build-web.sh`, then refresh the browser (restart Django only if needed).
