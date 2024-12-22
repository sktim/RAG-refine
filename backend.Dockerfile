# CUDA ベースイメージを指定
FROM nvidia/cuda:12.6.3-cudnn-devel-ubuntu24.04

# 環境変数の設定
ENV PYTHONUNBUFFERED=1
ENV PATH="/root/.local/bin:$PATH"
ENV VENV_PATH="/opt/venv"
ENV PATH="$VENV_PATH/bin:$PATH"

# 必要なパッケージのインストール
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Poetry のインストール
RUN curl -sSL https://install.python-poetry.org | python3

# Ollama のインストール
RUN curl -fsSL https://ollama.com/install.sh | sh

# 仮想環境の作成
RUN python3 -m venv $VENV_PATH

# 仮想環境内で pip のアップグレード
RUN pip install --upgrade pip

# 作業ディレクトリを設定
WORKDIR /app/backend

# pyproject.toml と poetry.lock をコピー
COPY backend/pyproject.toml backend/poetry.lock ./

# Poetry を使って依存関係をインストール（仮想環境でインストール）
RUN poetry config virtualenvs.create false \
    && poetry install --no-dev --no-root

# ollama と langchain-ollama を仮想環境内にインストール
RUN pip install ollama langchain-ollama

# アプリケーションコードをコピー
COPY backend/ /app/backend
