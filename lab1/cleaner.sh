#!/usr/bin/env bash
TARGET_DIR=${1:-.}
echo "Починаємо очищення в директорії: $TARGET_DIR"

echo "Видаляємо порожні файли..."
find "$TARGET_DIR" -type f -empty -delete

echo "Видаляємо порожні директорії..."
find "$TARGET_DIR" -type d -empty -delete

echo "Очищення завершено."
