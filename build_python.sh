#!/bin/bash
# Python + INTONE paketlerini tek, taşınabilir pakete koyar (Apple Silicon, macOS 14+): python-build-standalone'un
# Python'u açılır, requirements.lock'taki sabit sürümler özet denetimiyle kurulur. Kullanım: build_python.sh [çıktı klasörü]
# Çıktı: intone-python-<sürüm>-<kilit>-macos-arm64.tar.gz ve özellikleri (python.json).
set -euo pipefail
cd "$(dirname "$0")"
. ./sources.sh
OUT="$(mkdir -p "${1:-dist}" && cd "${1:-dist}" && pwd)"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

[ "$(uname -sm)" = "Darwin arm64" ] || { echo "Apple Silicon Mac gerekir"; exit 1; }
REQ_HASH=$(sed -n 's/^# requirements.txt sha256: //p' requirements.lock)
LOCK_HASH=$(shasum -a 256 requirements.lock | cut -d' ' -f1)

echo "Python $PY_VERSION indiriliyor"
fetch "$PY_URL" "$PY_SHA256" "$WORK/python.tar.gz"
tar -xzf "$WORK/python.tar.gz" -C "$WORK"
PY="$WORK/python/bin/python3"

echo "Paketler kuruluyor (requirements.lock)"
"$PY" -m pip install --no-cache-dir --disable-pip-version-check --no-deps --only-binary :all: --require-hashes \
  -r requirements.lock
rm -rf "$WORK/python/lib/python3.12/test" "$WORK/python/lib/python3.12/idlelib" "$WORK/python/lib/python3.12/tkinter"

echo "Deneme: paketler açılıyor"
"$PY" - <<'PY'
import ssl, sqlite3, lzma, ctypes   # standart kitaplığın derlenmiş parçaları
import numpy, onnxruntime, torch, transformers, mlx.core, mlx_whisper, huggingface_hub, certifi
print("numpy", numpy.__version__, "torch", torch.__version__, "transformers", transformers.__version__,
      "mlx", mlx.core.__version__, "onnxruntime", onnxruntime.__version__)
assert torch.backends.mps.is_built()
PY

cat > "$WORK/python/INTONE-RUNTIME.json" <<JSON
{"python": "$PY_VERSION", "requirements_sha256": "$REQ_HASH", "lock_sha256": "$LOCK_HASH"}
JSON
NAME="intone-python-$PY_VERSION-${LOCK_HASH:0:8}-macos-arm64.tar.gz"
tar -czf "$OUT/$NAME" -C "$WORK" python
SHA=$(shasum -a 256 "$OUT/$NAME" | cut -d' ' -f1)
SIZE=$(stat -f%z "$OUT/$NAME")
cat > "$OUT/python.json" <<JSON
{"file": "$NAME", "sha256": "$SHA", "size": $SIZE, "version": "$PY_VERSION", "requirements_sha256": "$REQ_HASH"}
JSON
echo "Hazır: $OUT/$NAME ($((SIZE / 1000000)) MB)"
