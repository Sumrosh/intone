#!/bin/bash
# libass'lı (altyazı yakma) ve libx264'lü FFmpeg'i kaynaktan, durağan bağlı derler (Apple Silicon, macOS 12+).
# Çıkan ffmpeg ve ffprobe yalnız macOS'un kendi kitaplıklarına bağlıdır; brew gerekmez.
# Derleme araçları: meson, ninja, pkg-config (GitHub'ın macOS makinelerinde var; yoksa brew install meson ninja pkgconf).
# Kullanım: build_ffmpeg.sh [çıktı klasörü]. Çıktı: intone-ffmpeg-<sürüm>-macos-arm64.tar.gz ve ffmpeg.json.
set -euo pipefail
cd "$(dirname "$0")"
. ./sources.sh
OUT="$(mkdir -p "${1:-dist}" && cd "${1:-dist}" && pwd)"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

[ "$(uname -sm)" = "Darwin arm64" ] || { echo "Apple Silicon Mac gerekir"; exit 1; }
export MACOSX_DEPLOYMENT_TARGET=12.0
P="$WORK/prefix"
SRC="$WORK/src"
mkdir -p "$P" "$SRC"
export PKG_CONFIG_PATH="$P/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$P/lib/pkgconfig"   # brew'daki kopyalar karışmasın
JOBS=$(sysctl -n hw.ncpu)
MESON=(--prefix="$P" --libdir=lib --buildtype=release --default-library=static -Db_ndebug=true)

echo "== x264"
git_at "$X264_GIT" "$X264_COMMIT" "$SRC/x264"
(cd "$SRC/x264" && ./configure --prefix="$P" --enable-static --enable-pic --disable-cli --disable-opencl \
  && make -j"$JOBS" && make install)

echo "== freetype"
git_at "$FREETYPE_GIT" "$FREETYPE_COMMIT" "$SRC/freetype"
(cd "$SRC/freetype" && meson setup build "${MESON[@]}" -Dbrotli=disabled -Dbzip2=disabled -Dharfbuzz=disabled \
  -Dpng=disabled -Dzlib=disabled -Dtests=disabled && meson install -C build)

echo "== fribidi"
fetch "$FRIBIDI_URL" "$FRIBIDI_SHA256" "$SRC/fribidi.tar.xz"
tar -xf "$SRC/fribidi.tar.xz" -C "$SRC" && mv "$SRC"/fribidi-*/ "$SRC/fribidi"
(cd "$SRC/fribidi" && meson setup build "${MESON[@]}" -Ddocs=false -Dbin=false -Dtests=false && meson install -C build)

echo "== harfbuzz"
fetch "$HARFBUZZ_URL" "$HARFBUZZ_SHA256" "$SRC/harfbuzz.tar.xz"
tar -xf "$SRC/harfbuzz.tar.xz" -C "$SRC" && mv "$SRC"/harfbuzz-*/ "$SRC/harfbuzz"
(cd "$SRC/harfbuzz" && meson setup build "${MESON[@]}" -Dfreetype=enabled -Dglib=disabled -Dgobject=disabled \
  -Dcairo=disabled -Dchafa=disabled -Dicu=disabled -Dgraphite2=disabled -Dtests=disabled -Ddocs=disabled \
  -Dutilities=disabled -Dintrospection=disabled && meson install -C build)

echo "== libass"
fetch "$LIBASS_URL" "$LIBASS_SHA256" "$SRC/libass.tar.xz"
tar -xf "$SRC/libass.tar.xz" -C "$SRC" && mv "$SRC"/libass-*/ "$SRC/libass"
# yazı tipleri macOS'un CoreText'inden bulunur (fontconfig gerekmez)
(cd "$SRC/libass" && ./configure --prefix="$P" --disable-shared --enable-static --disable-fontconfig \
  --enable-coretext --disable-libunibreak && make -j"$JOBS" && make install)

echo "== FFmpeg $FFMPEG_VERSION"
git_at "$FFMPEG_GIT" "$FFMPEG_COMMIT" "$SRC/ffmpeg"
(cd "$SRC/ffmpeg" && ./configure --prefix="$P" --pkg-config-flags=--static \
  --extra-cflags="-I$P/include" --extra-ldflags="-L$P/lib -framework CoreText -framework CoreFoundation -framework CoreGraphics" \
  --extra-libs="-lc++" --enable-gpl --enable-libx264 --enable-libass \
  --disable-autodetect --enable-zlib --enable-bzlib --enable-iconv --enable-videotoolbox --enable-audiotoolbox \
  --disable-ffplay --disable-doc --disable-debug --disable-shared --enable-static \
  && make -j"$JOBS" && make install)

PKG="$WORK/ffmpeg"
mkdir -p "$PKG/bin" "$PKG/licenses"
cp "$P/bin/ffmpeg" "$P/bin/ffprobe" "$PKG/bin/"
cp "$SRC/ffmpeg/COPYING.GPLv2" "$PKG/licenses/FFmpeg-GPLv2.txt"
cp "$SRC/x264/COPYING" "$PKG/licenses/x264.txt"
cp "$SRC/libass/COPYING" "$PKG/licenses/libass.txt"
cp "$SRC/fribidi/COPYING" "$PKG/licenses/fribidi.txt"
cp "$SRC/harfbuzz/COPYING" "$PKG/licenses/harfbuzz.txt"
cp "$SRC/freetype/LICENSE.TXT" "$PKG/licenses/freetype.txt"
cat > "$PKG/licenses/KAYNAK.txt" <<TXT
Bu FFmpeg, INTONE için şu kaynaklardan derlendi (GPL): betik build_ffmpeg.sh, sürümler sources.sh.
FFmpeg $FFMPEG_GIT @ $FFMPEG_COMMIT
x264 $X264_GIT @ $X264_COMMIT
freetype $FREETYPE_GIT @ $FREETYPE_COMMIT
$FRIBIDI_URL
$HARFBUZZ_URL
$LIBASS_URL
TXT
for bin in "$PKG"/bin/*; do strip -x "$bin"; codesign --force --sign - "$bin"; done

echo "== Denetim"
for bin in "$PKG"/bin/*; do
  # yalnız macOS'un kendi kitaplıkları: brew ya da derleme klasörüne bağ kalmamalı
  if otool -L "$bin" | tail -n +2 | awk '{print $1}' | grep -vE '^(/usr/lib/|/System/Library/)'; then
    echo "$bin dışarıdaki bir kitaplığa bağlı"; exit 1
  fi
done
FF="$PKG/bin/ffmpeg"
"$FF" -hide_banner -filters | awk '$2 == "subtitles" { found = 1 } END { exit !found }' || { echo "libass yok"; exit 1; }
"$FF" -hide_banner -encoders | grep -q libx264 || { echo "libx264 yok"; exit 1; }
printf '1\n00:00:00,000 --> 00:00:01,000\nMerhaba dünya, ışık\n' > "$WORK/t.srt"
"$FF" -v error -nostdin -f lavfi -i testsrc=size=320x240:rate=25:duration=1 -f lavfi -i sine=duration=1 \
  -vf "subtitles=$WORK/t.srt" -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest "$WORK/t.mp4"
[ "$("$PKG/bin/ffprobe" -v error -show_entries stream=codec_name -of csv=p=0 "$WORK/t.mp4" | tr '\n' ' ')" = "h264 aac " ] \
  || { echo "deneme videosu beklendiği gibi değil"; exit 1; }
"$FF" -hide_banner -version | head -1

NAME="intone-ffmpeg-$FFMPEG_VERSION-macos-arm64.tar.gz"
tar -czf "$OUT/$NAME" -C "$WORK" ffmpeg
SHA=$(shasum -a 256 "$OUT/$NAME" | cut -d' ' -f1)
SIZE=$(stat -f%z "$OUT/$NAME")
cat > "$OUT/ffmpeg.json" <<JSON
{"file": "$NAME", "sha256": "$SHA", "size": $SIZE, "version": "$FFMPEG_VERSION"}
JSON
echo "Hazır: $OUT/$NAME ($((SIZE / 1000000)) MB)"
