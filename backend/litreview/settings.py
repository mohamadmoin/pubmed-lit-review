"""
Django settings for LitReview — PubMed AI literature review API.
"""
from pathlib import Path
import os

from litreview.version import get_version

BASE_DIR = Path(__file__).resolve().parent.parent
APP_VERSION = get_version()

DEBUG = os.getenv('DEBUG', 'False') == 'True'
SECRET_KEY = os.getenv('DJANGO_SECRET_KEY', 'change-me-in-production')
ALLOWED_HOSTS = os.getenv('DJANGO_ALLOWED_HOSTS', 'localhost,127.0.0.1').split(',')

# Open-source default: shared demo user for zero-setup local use. Set False in production.
LITREVIEW_DEMO_MODE = os.getenv('LITREVIEW_DEMO_MODE', 'True') == 'True'

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'rest_framework.authtoken',
    'corsheaders',
    'drf_spectacular',
    'django_celery_results',
    'documents',
    'authentication',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'litreview.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'litreview.wsgi.application'

TEXT_STORAGE_PATH = os.getenv('TEXT_STORAGE_PATH', str(BASE_DIR / 'data' / 'text_storage'))
DATA_DIR = Path(os.getenv('LITREVIEW_DATA_DIR', TEXT_STORAGE_PATH)).parent
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(TEXT_STORAGE_PATH, exist_ok=True)

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': DATA_DIR / 'db.sqlite3',
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
FRONTEND_DIST = Path(os.getenv('FRONTEND_DIST', BASE_DIR / 'frontend_dist'))
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# CORS — tighten in production
CORS_ALLOW_ALL_ORIGINS = DEBUG
CORS_ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.getenv(
        'CORS_ALLOWED_ORIGINS',
        'http://localhost:8080,http://127.0.0.1:8080,http://localhost:8001',
    ).split(',')
    if origin.strip()
]
CORS_ALLOW_CREDENTIALS = True

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'authentication.authentication.DemoAwareTokenAuthentication',
        'authentication.authentication.DemoAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
}

SPECTACULAR_SETTINGS = {
    'TITLE': 'LitReview API',
    'DESCRIPTION': 'PubMed-based AI literature review generation',
    'VERSION': APP_VERSION,
    'SERVE_INCLUDE_SCHEMA': False,
    'SCHEMA_PATH_PREFIX': '/api/',
    'TAGS': [
        {'name': 'auth', 'description': 'Registration and login'},
        {'name': 'documents', 'description': 'Literature review documents'},
    ],
}

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {'format': '{levelname} {asctime} {module} {message}', 'style': '{'},
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
    },
    'loggers': {
        'django': {'handlers': ['console'], 'level': 'INFO'},
        'documents': {'handlers': ['console'], 'level': 'DEBUG'},
    },
}

# Neo4j
NEO4J_URI = os.getenv('NEO4J_URI', 'bolt://neo4j:7687')
NEO4J_USER = os.getenv('NEO4J_USER', 'neo4j')
NEO4J_PASSWORD = os.getenv('NEO4J_PASSWORD', 'password')

NEO4J_CLIENT_CONFIG = {
    'uri': NEO4J_URI,
    'user': NEO4J_USER,
    'password': NEO4J_PASSWORD,
    'encrypted': False,
    'trust': 'TRUST_ALL_CERTIFICATES',
    'max_connection_lifetime': 300,
    'max_connection_pool_size': 50,
    'connection_timeout': 5,
    'keep_alive': True,
}

# Celery
CELERY_BROKER_URL = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
CELERY_RESULT_BACKEND = 'django-db'
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_TIMEZONE = TIME_ZONE
CELERY_TASK_TRACK_STARTED = True
CELERY_TASK_TIME_LIMIT = 30 * 60
CELERY_TASK_SOFT_TIME_LIMIT = 25 * 60

DOCUMENT_GENERATION = {
    'MAX_RETRIES': 3,
    'TIMEOUT_SECONDS': 3600,
    'BATCH_SIZE': 10,
    'USE_ENHANCED_FILTERING': True,
    'DEFAULT_CITATION_STYLE': 'apa',
    'MAX_SECTIONS': 10,
    'MIN_WORDS_PER_SECTION': 200,
    'MAX_WORDS_PER_SECTION': 2000,
}

# LLM — OpenAI or LM Studio (OpenAI-compatible local server)
LLM_PROVIDER = os.getenv('LLM_PROVIDER', 'lmstudio')
LLM_TEMPERATURE = float(os.getenv('LLM_TEMPERATURE', '0.7'))

OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
OPENAI_MODEL = os.getenv('OPENAI_MODEL', 'gpt-4o-mini')

LM_STUDIO_BASE_URL = os.getenv('LM_STUDIO_BASE_URL', 'http://127.0.0.1:1234/v1')
LM_STUDIO_API_KEY = os.getenv('LM_STUDIO_API_KEY', 'lm-studio')
LM_STUDIO_MODEL = os.getenv('LM_STUDIO_MODEL', 'google/gemma-4-12b')
LM_STUDIO_MAX_TOKENS = int(os.getenv('LM_STUDIO_MAX_TOKENS', '8192'))
LM_STUDIO_CONTEXT_TOKENS = int(os.getenv('LM_STUDIO_CONTEXT_TOKENS', '16000'))

# PubMed / NCBI Entrez (email required by NCBI policy)
PUBMED_EMAIL = os.getenv('PUBMED_EMAIL')
PUBMED_TOOL = os.getenv('PUBMED_TOOL', 'LitReview')
PUBMED_API_KEY = os.getenv('PUBMED_API_KEY')

from documents.python_document_generated_graph.engine.entrez_client import EntrezClient

ENTREZ_CLIENT = EntrezClient(
    tool=PUBMED_TOOL,
    email=PUBMED_EMAIL or 'litreview@localhost',
    api_key=PUBMED_API_KEY,
)

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'
os.makedirs(MEDIA_ROOT, exist_ok=True)
