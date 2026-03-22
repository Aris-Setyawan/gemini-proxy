# Google Gemini OpenAI-Compatible Proxy

Proxy ringan yang mengubah request format OpenAI → Google Gemini API. Cocok untuk tools yang hanya support OpenAI format tapi ingin pakai Gemini.

## Fitur

- **OpenAI-compatible** — drop-in replacement, ganti `base_url` saja
- **Auto-strip params** — hapus otomatis param yang tidak didukung Gemini (`store`, `user`, `thinking`, dll)
- **Auto-rename** — `max_completion_tokens` → `max_tokens` otomatis
- **Systemd service** — auto-start saat boot
- **Zero dependency** — hanya butuh Python 3 (stdlib)

## Cara Install

### 1. Clone repo
```bash
git clone https://github.com/Aris-Setyawan/gemini-proxy.git
cd gemini-proxy
```

### 2. Jalankan installer
```bash
sudo bash install.sh
```

Installer akan:
- Minta Google Gemini API key
- Install proxy ke `/opt/gemini-proxy/`
- Buat & enable systemd service
- Test koneksi otomatis

### 3. Selesai!
```
Proxy URL: http://127.0.0.1:9998
```

---

## Cara Uninstall
```bash
sudo bash install.sh uninstall
```

---

## Cara Pakai

### Python (OpenAI SDK)
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://127.0.0.1:9998",
    api_key="YOUR_GEMINI_API_KEY"
)

response = client.chat.completions.create(
    model="gemini-2.0-flash",
    messages=[{"role": "user", "content": "Halo!"}]
)
print(response.choices[0].message.content)
```

### curl
```bash
curl -X POST http://127.0.0.1:9998/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_GEMINI_API_KEY" \
  -d '{
    "model": "gemini-2.0-flash",
    "messages": [{"role": "user", "content": "Halo!"}]
  }'
```

### OpenClaw / Claude Code
```json
{
  "model": "google/gemini-2.0-flash",
  "provider": {
    "baseURL": "http://127.0.0.1:9998",
    "apiKey": "YOUR_GEMINI_API_KEY"
  }
}
```

---

## Konfigurasi

Edit `/opt/gemini-proxy/.env` lalu restart:
```bash
systemctl restart gemini-proxy
```

| Variable | Default | Keterangan |
|----------|---------|------------|
| `PROXY_PORT` | `9998` | Port proxy |
| `PROXY_HOST` | `127.0.0.1` | Bind address |
| `GEMINI_API_KEY` | — | API key dari Google AI Studio |
| `GOOGLE_BASE` | `https://generativelanguage.googleapis.com/v1beta/openai` | Google API endpoint |

### Ganti port
```bash
PROXY_PORT=8080 sudo bash install.sh
```

---

## Manajemen Service

```bash
# Status
systemctl status gemini-proxy

# Log realtime
journalctl -u gemini-proxy -f

# Restart
systemctl restart gemini-proxy

# Stop
systemctl stop gemini-proxy
```

---

## Model yang Didukung

| Model | Keterangan |
|-------|------------|
| `gemini-2.5-flash` | Cepat, gratis quota |
| `gemini-2.5-pro` | Paling powerful |
| `gemini-2.0-flash` | Stabil, recommended |
| `gemini-1.5-flash` | Hemat, konteks panjang |
| `gemini-1.5-pro` | Pro versi lama |

Daftar lengkap: [Google AI Models](https://ai.google.dev/gemini-api/docs/models)

---

## Dapatkan API Key

1. Buka [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Login dengan akun Google
3. Klik **Create API Key**
4. Copy dan gunakan saat install

---

## Troubleshooting

**HTTP 400 / invalid param**
→ Pastikan model name benar (lihat tabel di atas)

**HTTP 401 Unauthorized**
→ API key salah atau tidak aktif

**Connection refused**
→ `systemctl status gemini-proxy` — cek service jalan

**HTTP 429 Too Many Requests**
→ Quota gratis habis, tunggu atau upgrade ke paid tier

---

## Lisensi

MIT License — bebas digunakan dan dimodifikasi.
