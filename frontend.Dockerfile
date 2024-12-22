# ベースイメージ
FROM python:3.12-slim

# 環境変数の設定
ENV PYTHONUNBUFFERED=1
ENV PATH="/root/.local/bin:$PATH"

# 作業ディレクトリを設定
WORKDIR /app/frontend

# 必要なパッケージのインストール
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Poetry のインストール
RUN curl -sSL https://install.python-poetry.org | python3

# pyproject.toml と poetry.lock をコピー
COPY frontend/pyproject.toml frontend/poetry.lock ./

# Poetry を使って依存関係をインストール
RUN poetry config virtualenvs.create false \
    && poetry install --no-dev --no-root

# アプリケーションコードをコピー
COPY frontend/ /app/frontend
