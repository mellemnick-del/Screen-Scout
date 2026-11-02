FROM python:3.12-slim
# ffmpeg pulls frames; deno is the JavaScript runtime yt-dlp needs to read YouTube pages
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg curl unzip ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://deno.land/install.sh | DENO_INSTALL=/usr/local sh -s -- -y
WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app
ENV SCOUT_DB=/data/reviews.db
EXPOSE 8000
# Hosts like Render tell the app which port to use through $PORT.
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}
