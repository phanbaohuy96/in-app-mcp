#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
CACHE_DIR="${MODEL_CACHE_DIR:-$ROOT_DIR/model_cache}"
MODEL_FILE="gemma-4-E2B-it.litertlm"
MODEL_URL="https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm"
TARGET_PATH="$CACHE_DIR/$MODEL_FILE"
TEMP_PATH="$TARGET_PATH.partial"

mkdir -p "$CACHE_DIR"

if [[ -s "$TARGET_PATH" ]]; then
  echo "Model already cached: $TARGET_PATH"
else
  echo "Downloading Gemma 4 E2B model to: $TARGET_PATH"
  rm -f "$TEMP_PATH"
  curl -fL --progress-bar "$MODEL_URL" -o "$TEMP_PATH"
  mv "$TEMP_PATH" "$TARGET_PATH"
  echo "Download complete."
fi

if [[ -f "$ENV_FILE" ]]; then
  sed -i.bak \
    -e '/^LLM_ADAPTER=/d' \
    -e '/^E2E_MODE=/d' \
    -e '/^MODEL_CACHE_DIR=/d' \
    -e '/^GEMMA_MODEL_PATH=/d' \
    "$ENV_FILE"
  rm -f "$ENV_FILE.bak"
else
  touch "$ENV_FILE"
fi

{
  echo "LLM_ADAPTER=gemma"
  echo "E2E_MODE=false"
  echo "MODEL_CACHE_DIR=$CACHE_DIR"
  echo "GEMMA_MODEL_PATH=$TARGET_PATH"
} >> "$ENV_FILE"

echo "Updated $ENV_FILE"
echo "Run with VS Code launch: Example (Gemma from .env)"
