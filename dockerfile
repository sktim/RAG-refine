# CUDA ベースイメージを指定
FROM nvidia/cuda:12.6.3-cudnn-devel-ubuntu22.04

# 環境変数の設定
ENV PYTHONUNBUFFERED=1
ENV PATH="/root/.local/bin:$PATH"

# 必要なパッケージのインストール
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    build-essential \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Poetry のインストール
RUN curl -sSL https://install.python-poetry.org | python3

# Ollama のインストール
RUN curl -fsSL https://ollama.com/install.sh | sh

# 作業ディレクトリを設定
WORKDIR /app

# pyproject.toml と poetry.lock をコピー
COPY pyproject.toml poetry.lock ./

# Poetry を使って依存関係をインストール（仮想環境なしでシステムにインストール）
RUN poetry config virtualenvs.create false \
    && poetry install --no-dev

# ollama と langchain-ollama をシステムにインストール
RUN pip install ollama langchain-ollama

# アプリケーションコードをコピー
COPY src/ /app/src

# エントリーポイントの設定
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
