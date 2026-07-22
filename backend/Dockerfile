# LitReview backend API (Flutter web UI is built separately — see scripts/build-web.sh)
FROM python:3.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV FRONTEND_DIST=/app/frontend_dist

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    wget \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY VERSION /app/VERSION
COPY backend/ .

RUN mkdir -p /app/logs /app/frontend_dist && chmod 777 /app/logs

EXPOSE 8001

CMD ["sh", "-c", "python manage.py migrate --noinput && python manage.py ensure_demo_user && python manage.py runserver 0.0.0.0:8001"]
