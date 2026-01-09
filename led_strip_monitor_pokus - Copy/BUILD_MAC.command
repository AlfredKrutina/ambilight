#!/bin/bash
cd "$(dirname "$0")"

echo "=========================================="
echo "      Building AmbiLight for Mac"
echo "=========================================="
echo ""
echo "⚠️  NOTE: This script now calls the universal build.py"
echo "   For more control, run: python3 build.py"
echo ""

# Zkontroluj Python
if ! command -v python3 &> /dev/null; then
    echo "[ERROR] Python 3 not found. Install it first (brew install python)."
    exit 1
fi

# Spusť univerzální build skript
python3 build.py
