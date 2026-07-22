"""Shared demo user for open-source local deployments."""

from django.conf import settings
from django.contrib.auth import get_user_model

DEMO_USERNAME = 'demo'
DEMO_EMAIL = 'demo@litreview.local'
DEMO_PASSWORD = 'demo'


def ensure_demo_user():
    """Create or update the local demo account."""
    User = get_user_model()
    user, created = User.objects.get_or_create(
        username=DEMO_USERNAME,
        defaults={'email': DEMO_EMAIL, 'is_active': True},
    )
    if created or not user.has_usable_password():
        user.set_password(DEMO_PASSWORD)
        user.email = DEMO_EMAIL
        user.is_active = True
        user.save(update_fields=['password', 'email', 'is_active'])
    return user


def demo_mode_enabled() -> bool:
    return getattr(settings, 'LITREVIEW_DEMO_MODE', True)
