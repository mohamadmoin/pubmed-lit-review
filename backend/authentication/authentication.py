"""Authentication helpers for open-source demo / guest access."""

from rest_framework import exceptions
from rest_framework.authentication import BaseAuthentication, TokenAuthentication, get_authorization_header

from .demo import demo_mode_enabled, ensure_demo_user


class DemoAwareTokenAuthentication(TokenAuthentication):
    """
    Token auth that falls back to demo mode when a stale token is sent locally.

    Without this, an invalid Authorization header raises 401 before DemoAuthentication runs.
    """

    def authenticate(self, request):
        try:
            return super().authenticate(request)
        except exceptions.AuthenticationFailed:
            if demo_mode_enabled():
                return (ensure_demo_user(), None)
            raise


class DemoAuthentication(BaseAuthentication):
    """
    When demo mode is enabled, treat unauthenticated requests as the shared demo user.

    Requests with a valid Authorization: Token header are handled by DemoAwareTokenAuthentication.
    """

    def authenticate(self, request):
        if not demo_mode_enabled():
            return None

        auth = get_authorization_header(request).split()
        if auth and auth[0].lower() == b'token':
            return None

        return (ensure_demo_user(), None)
