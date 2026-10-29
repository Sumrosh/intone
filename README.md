# INTONE çalışma paketleri (Sumrosh/intone)

INTONE Mac uygulaması ilk açılışta brew ya da Terminal gerektirmeden şunları indirir ve
`~/Library/Application Support/INTONE/runtime` altına açar:

- **Python ortamı** (`intone-python-*.tar.gz`): python-build-standalone'un Python 3.12'si ve
  `requirements.lock`'taki sabit sürümlü paketler (numpy, onnxruntime, torch, transformers, mlx-whisper…).
  Apple Silicon, macOS 14 ve üstü.
- **FFmpeg** (`intone-ffmpeg-*.tar.gz`): libass (altyazı yakma) ve libx264 ile, kaynaktan durağan derlenmiş
  `ffmpeg` ve `ffprobe`. Yalnız macOS'un kendi kitaplıklarına bağlıdır.

Her dosyanın adresi, boyutu ve sha256 özeti uygulamanın içindeki `runtime.json`'da sabittir; özet tutmazsa
dosya kullanılmaz. Kaynaklar da `sources.sh`'ta sabittir (adres + sha256 ya da git işlemesi).

| Dosya | Görevi |
| --- | --- |
| `sources.sh` | Python ve FFmpeg kaynaklarının sabit adresleri ve özetleri |
| `requirements.lock` | Paketlerin sabit sürümleri ve özetleri (`lock.sh` üretir) |
| `build_python.sh`, `build_ffmpeg.sh` | Paketleri derler ve dener (Apple Silicon Mac) |
| `workflow.yml` | GitHub Actions: ikisini derler, istenirse Release'e koyar |

## Yeni paket yayımlamak

1. INTONE deposunda `requirements.txt` değiştiyse `mac/runtime/lock.sh` çalıştırılır.
2. `mac/runtime/` içindekiler açık `Sumrosh/intone` deposunun köküne kopyalanır
   (`workflow.yml` → `.github/workflows/build.yml`).
3. Orada Actions → Paketler → Run workflow, "Release olarak yayımla" işaretli.
4. Release'teki `manifest.json`, INTONE deposundaki `mac/runtime/manifest.json`'ın yerine konur;
   uygulama yeniden derlenince yeni paketler kullanılır.

Bu depoda INTONE'un kendi kodu yoktur; yalnız açık kaynak parçalar ve onları üreten betikler durur.
FFmpeg ve x264 GPL lisanslıdır; lisans metinleri ve kaynak işlemeleri paketin `licenses/` klasöründedir.
