"""Read the application version from VERSION file."""

from pathlib import Path


def get_version() -> str:
    backend_dir = Path(__file__).resolve().parent.parent
    for path in (backend_dir / 'VERSION', backend_dir.parent / 'VERSION'):
        if path.exists():
            return path.read_text(encoding='utf-8').strip()
    return '0.0.0'
