"""Serve the bundled Flutter web application."""

from __future__ import annotations

import mimetypes
from pathlib import Path

from django.conf import settings
from django.http import FileResponse, Http404, HttpResponse


def _frontend_root() -> Path:
    return Path(settings.FRONTEND_DIST)


def serve_frontend(request, path: str = ''):
    """Serve Flutter web assets, falling back to index.html for client routes."""
    root = _frontend_root()
    if not root.exists():
        return HttpResponse(
            'LitReview web app is not built yet. '
            'Run ./scripts/start.sh or ./scripts/build-web.sh, then restart the server.',
            status=503,
            content_type='text/plain',
        )

    if path:
        candidate = (root / path).resolve()
        root_resolved = root.resolve()
        if not str(candidate).startswith(str(root_resolved)):
            raise Http404('Invalid path')
        if candidate.is_file():
            content_type, _ = mimetypes.guess_type(str(candidate))
            return FileResponse(
                open(candidate, 'rb'),
                content_type=content_type or 'application/octet-stream',
            )

    index = root / 'index.html'
    if not index.is_file():
        return HttpResponse(
            'LitReview web app is missing index.html. '
            'Run ./scripts/build-web.sh, then recreate the Django container: '
            'docker compose up -d --force-recreate django',
            status=503,
            content_type='text/plain',
        )
    return FileResponse(open(index, 'rb'), content_type='text/html')
