FROM python:3.9-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    FLASK_APP=app.py \
    FLASK_ENV=production \
    PORT=8000 \
    HOST=0.0.0.0 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Install ONLY curl (no compilers needed if we use wheels)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# CRITICAL FIX: Install packages with ONLY BINARY WHEELS (no compilation)
RUN pip install --upgrade pip

# 1. Install torch CPU-only (binary wheel, fast)
RUN pip install --only-binary=:all: torch==2.1.0 --index-url https://download.pytorch.org/whl/cpu

# 2. Install spaCy and dependencies with ONLY pre-built wheels (NO COMPILATION)
RUN pip install --only-binary=:all: \
    spacy==3.7.2 \
    thinc==8.2.5 \
    blis==0.7.11 \
    cymem==2.0.8 \
    murmurhash==1.0.10 \
    preshed==3.0.9 \
    pathy==0.11.0

# 3. Install remaining packages (all have binary wheels)
RUN pip install --only-binary=:all: \
    transformers==4.36.0 \
    flask==3.0.0 \
    flask-cors==6.0.0 \
    flask-restx==1.3.0 \
    presidio-analyzer==2.2.354 \
    presidio-anonymizer==2.2.354 \
    pyyaml==6.0.1 \
    urllib3==2.5.0 \
    requests==2.32.4 \
    setuptools==78.1.1 \
    werkzeug==3.0.3 \
    zipp==3.19.1 \
    optimum[onnx]==2.0.0 \
    onnxruntime==1.19.2 \
    torch==2.4.0  # Reinstall to ensure compatibility

# 4. Install estnltk (may need compilation but it's small)
RUN apt-get update && apt-get install -y --no-install-recommends gcc g++ && \
    pip install estnltk==1.7.2 && \
    apt-get remove -y gcc g++ && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# 5. Download spaCy model (fast, ~10MB)
RUN python -m spacy download xx_ent_wiki_sm

# Create user
RUN groupadd -r presidio && \
    useradd -r -g presidio -m presidio && \
    mkdir -p /app/config /app/logs /app/models && \
    chown -R presidio:presidio /app

# Copy app files LAST
COPY --chown=presidio:presidio . .

USER presidio

EXPOSE $PORT

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:${PORT}/ || exit 1

CMD ["python", "app.py"]