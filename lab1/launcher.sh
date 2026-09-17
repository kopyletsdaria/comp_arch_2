#!/usr/bin/env bash
TARGET_DIR=${1:-.}

echo "Запускаємо cleaner.sh у новому терміналі..."

gnome-terminal -- bash -c "./cleaner.sh '$TARGET_DIR'; exec bash"
