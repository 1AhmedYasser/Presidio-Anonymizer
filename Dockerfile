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

# Install minimal dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Upgrade pip
RUN pip install --upgrade pip

# Install torch CPU-only ONCE (use extra-index-url to allow other packages from PyPI)
RUN pip install --only-binary=:all: \
    torch==2.4.0 \
    --extra-index-url https://download.pytorch.org/whl/cpu

# Install all other packages in one go (faster, resolves dependencies together)
RUN pip install --only-binary=:all: \
    transformers==4.36.0 \
    flask==3.0.0 \
    flask-cors==6.0.0 \
    flask-restx==1.3.0 \
    presidio-analyzer==2.2.354 \
    presidio-anonymizer==2.2.354 \
    spacy==3.7.2 \
    pyyaml==6.0.1 \
    urllib3==2.5.0 \
    requests==2.32.4 \
    setuptools==78.1.1 \
    werkzeug==3.0.3 \
    zipp==3.19.1 \
    onnxruntime==1.19.2 \
    optimum[onnx]==2.0.0

# Install estnltk (needs compilation - do this separately)
RUN apt-get update && apt-get install -y --no-install-recommends gcc g++ && \
    pip install estnltk==1.7.2 && \
    apt-get remove -y gcc g++ && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Download spaCy model
RUN python -m spacy download xx_ent_wiki_sm

# Create user
RUN groupadd -r presidio && \
    useradd -r -g presidio -m presidio && \
    mkdir -p /app/config /app/logs /app/models && \
    chown -R presidio:presidio /app

# Copy app files LAST (for better layer caching)
COPY --chown=presidio:presidio . .

USER presidio

EXPOSE $PORT

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:${PORT}/ || exit 1

CMD ["python", "app.py"]