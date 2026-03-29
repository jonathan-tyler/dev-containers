#!/usr/bin/env bash
set -euo pipefail

apt-get update
apt-get install -y --no-install-recommends \
	python3 \
	python3-pip \
	python3-venv \
	pipx

python3 -m pip install --no-cache-dir --break-system-packages \
	black \
	debugpy \
	Pillow \
	pytest \
	pytesseract \
	ruff

rm -rf /var/lib/apt/lists/*