from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import AIGeneratedDocumentViewSet

# Document router for regular document endpoints
router = DefaultRouter()
router.register(r'documents', AIGeneratedDocumentViewSet, basename='document')

urlpatterns = [
    # Include main document routes
    path('', include(router.urls)),
] 