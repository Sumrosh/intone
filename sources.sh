# INTONE çalışma paketlerinin sabitlenmiş kaynakları (build_python.sh ve build_ffmpeg.sh okur).
# Sürüm yükseltirken adres ile özet (sha256) ya da git işlemesi birlikte değişir; özet tutmazsa derleme durur.

PY_VERSION=3.12.12
PY_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.12.12+20251014-aarch64-apple-darwin-install_only.tar.gz"
PY_SHA256=6ceba34fe78802853a30bde6f303a0a54f71f6ab07a673da34e90c0aa06c786e

FFMPEG_VERSION=7.1.5
FFMPEG_GIT=https://github.com/FFmpeg/FFmpeg
FFMPEG_COMMIT=3a0867c2bfda4a4d4309ca1a8cbdc6175e67f587   # n7.1.5
X264_GIT=https://github.com/mirror/x264
X264_COMMIT=31e19f92f00c7003fa115047ce50978bc98c3a0d     # stable dalı
FREETYPE_GIT=https://github.com/freetype/freetype
FREETYPE_COMMIT=0a0221a1347e2f1e07c395263540026e9a0aa7c7 # VER-2-14-3
FRIBIDI_URL=https://github.com/fribidi/fribidi/releases/download/v1.0.16/fribidi-1.0.16.tar.xz
FRIBIDI_SHA256=1b1cde5b235d40479e91be2f0e88a309e3214c8ab470ec8a2744d82a5a9ea05c
HARFBUZZ_URL=https://github.com/harfbuzz/harfbuzz/releases/download/10.1.0/harfbuzz-10.1.0.tar.xz
HARFBUZZ_SHA256=6ce3520f2d089a33cef0fc48321334b8e0b72141f6a763719aaaecd2779ecb82
LIBASS_URL=https://github.com/libass/libass/releases/download/0.17.4/libass-0.17.4.tar.xz
LIBASS_SHA256=78f1179b838d025e9c26e8fef33f8092f65611444ffa1bfc0cfac6a33511a05a

# indirip özetini denetler: fetch adres özet hedef
fetch() {
  curl -sSfL --retry 3 -o "$3" "$1"
  echo "$2  $3" | shasum -a 256 -c - >/dev/null || { echo "Özet uyuşmuyor: $1"; exit 1; }
}

# git deposunu tam o işlemede getirir: git_at adres işleme klasör
git_at() {
  mkdir -p "$3"
  git -C "$3" init -q
  git -C "$3" fetch -q --depth 1 "$1" "$2"
  git -C "$3" checkout -q FETCH_HEAD
  [ "$(git -C "$3" rev-parse HEAD)" = "$2" ] || { echo "İşleme uyuşmuyor: $1"; exit 1; }
}
