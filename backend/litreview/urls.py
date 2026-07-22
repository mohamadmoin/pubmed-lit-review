"""URL configuration for LitReview API."""
from django.contrib import admin
from django.urls import path, include
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularRedocView,
    SpectacularSwaggerView,
)
from rest_framework.permissions import AllowAny

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/', include('authentication.urls')),
    path('api/', include('documents.urls')),
    path(
        'api/schema/',
        SpectacularAPIView.as_view(
            permission_classes=[AllowAny],
            authentication_classes=[],
        ),
        name='schema',
    ),
    path(
        'api/docs/',
        SpectacularSwaggerView.as_view(
            url_name='schema',
            permission_classes=[AllowAny],
            authentication_classes=[],
        ),
        name='swagger-ui',
    ),
    path(
        'api/redoc/',
        SpectacularRedocView.as_view(
            url_name='schema',
            permission_classes=[AllowAny],
            authentication_classes=[],
        ),
        name='redoc',
    ),
]
