#!/bin/sh
set -e

echo "Applying database migrations..."
python manage.py migrate --noinput

echo "Starting LitReview API on port 8001..."
python manage.py runserver 0.0.0.0:8001
