# Google Gemini OpenAI-Compatible Proxy

Proxy ringan yang mengubah request format OpenAI → Google Gemini API. Cocok untuk tools yang hanya support OpenAI format tapi ingin pakai Gemini.

## Fitur

- **OpenAI-compatible** — drop-in replacement, ganti `base_url` saja
- **Auto-strip params** — hapus otomatis param yang tidak didukung Gemini (`store`, `user`, `thinking`, dll)
- **Auto-rename** — `max_completion_tokens` → `max_tokens` otomatis
- **Fix double-path** — strip `/v1` prefix otomatis agar tidak conflict dengan Google endpoint
- **JSON error response** — error dari Google dikembalikan sebagai JSON bersih, bukan binary gzip
- **Systemd service** — auto-start saat boot
- **Zero dependency** — hanya butuh Python 3 (stdlib)

---

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

## Integrasi OpenClaw (Lengkap dari Awal)

Panduan ini untuk fresh install OpenClaw yang ingin menggunakan Google Gemini sebagai model utama melalui proxy.

### Kenapa perlu proxy?

OpenClaw mengirim beberapa parameter yang **tidak didukung** oleh Google Gemini API, seperti `store`, `thinking`, `thinking_effort`. Tanpa proxy, setiap request akan gagal dengan error 400, lalu OpenClaw akan terus retry → tagihan API membengkak.

Proxy ini memfilter parameter tersebut sebelum diteruskan ke Google.

---

### Langkah 1 — Dapatkan Google Gemini API Key

1. Buka [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Login dengan akun Google
3. Klik **Create API Key**
4. Copy key (format: `AIzaSy...`)

---

### Langkah 2 — Install Proxy

```bash
git clone https://github.com/Aris-Setyawan/gemini-proxy.git
cd gemini-proxy
sudo bash install.sh
```

Masukkan API key saat diminta. Proxy akan berjalan di `http://127.0.0.1:9998`.

Verifikasi:
```bash
systemctl status gemini-proxy
curl -s http://127.0.0.1:9998/v1/models \
  -H "Authorization: Bearer YOUR_GEMINI_API_KEY" | python3 -m json.tool | head -20
```

---

### Langkah 3 — Konfigurasi `openclaw.json`

File config utama OpenClaw biasanya di `~/.openclaw/openclaw.json`.

#### 3a. Tambah provider Google

Cari atau tambahkan section `providers` di dalam `openclaw.json`:

```json
{
  "providers": {
    "gemini": {
      "name": "Google Gemini (via proxy)",
      "baseUrl": "http://127.0.0.1:9998",
      "api": "openai-completions",
      "models": [
        {
          "id": "models/gemini-2.5-flash",
          "name": "gemini-2.5-flash",
          "reasoning": false,
          "input": ["text", "image"],
          "contextWindow": 1048576,
          "maxTokens": 65536
        },
        {
          "id": "models/gemini-2.5-pro",
          "name": "gemini-2.5-pro",
          "reasoning": true,
          "input": ["text", "image"],
          "contextWindow": 1048576,
          "maxTokens": 65536
        }
      ]
    }
  }
}
```

> **Penting:** `baseUrl` harus `http://127.0.0.1:9998` (proxy lokal), **bukan** langsung ke `generativelanguage.googleapis.com`.

#### 3b. Set model primary agent

Untuk agent yang ingin pakai Gemini sebagai primary (misal `agent1`), update bagian `agents.list`:

```json
{
  "agents": {
    "list": [
      {
        "id": "agent1",
        "model": {
          "primary": "gemini/models/gemini-2.5-flash",
          "fallbacks": [
            "deepseek/deepseek-chat",
            "openrouter/deepseek/deepseek-chat"
          ]
        }
      }
    ]
  }
}
```

#### 3c. Set `defaults` agar tidak ke OpenRouter

Pastikan `defaults.model.primary` **tidak** mengarah ke `openrouter/google/...` karena itu mahal. Gunakan langsung:

```json
{
  "defaults": {
    "model": {
      "primary": "gemini/models/gemini-2.5-flash",
      "fallbacks": [
        "deepseek/deepseek-chat"
      ]
    }
  }
}
```

---

### Langkah 4 — Konfigurasi `auth-profiles.json`

Setiap agent punya file auth di `~/.openclaw/agents/<agent_id>/agent/auth-profiles.json`.

Tambahkan profil Google:

```json
{
  "profiles": {
    "google:default": {
      "provider": "google",
      "key": "AIzaSy...",
      "Authorization": "Bearer AIzaSy..."
    }
  }
}
```

> **Catatan:** Isi `key` dan `Authorization` dengan API key yang sama. Format `Bearer AIzaSy...` diperlukan untuk header Authorization.

Lakukan untuk semua agent yang ingin pakai Gemini:
```bash
for agent in agent1 agent2 agent3 agent4 main; do
  python3 -c "
import json
path = '$HOME/.openclaw/agents/$agent/agent/auth-profiles.json'
try:
    d = json.load(open(path))
except:
    d = {'profiles': {}}
d['profiles']['google:default'] = {
    'provider': 'google',
    'key': 'YOUR_GEMINI_API_KEY',
    'Authorization': 'Bearer YOUR_GEMINI_API_KEY'
}
json.dump(d, open(path, 'w'), indent=2)
print(f'Updated {path}')
"
done
```

---

### Langkah 5 — Juga Update `openclaw.json` untuk Header Authorization

OpenClaw menyimpan API key juga langsung di `openclaw.json` dalam format `Authorization: Bearer`. Cari dan update semua kemunculan key lama:

```bash
# Ganti key lama dengan key baru di openclaw.json
sed -i 's/AIzaSyOLD_KEY_HERE/AIzaSyNEW_KEY_HERE/g' ~/.openclaw/openclaw.json
```

Atau cek berapa kali key muncul:
```bash
grep -c "AIzaSy" ~/.openclaw/openclaw.json
```

---

### Langkah 6 — Restart OpenClaw

```bash
# Restart agent openclaw
openclaw restart
# atau via systemd jika disetup sebagai service
systemctl restart openclaw
```

---

### Langkah 7 — Verifikasi

Test langsung via proxy:
```bash
GEMINI_KEY="AIzaSy..."
curl -s -X POST "http://127.0.0.1:9998/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $GEMINI_KEY" \
  -d '{
    "model": "gemini-2.5-flash",
    "messages": [{"role": "user", "content": "say hi"}],
    "max_tokens": 50
  }' | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'])"
```

Expected output: `Hi` atau `Hello!`

---

### Troubleshooting OpenClaw

**Agent pakai OpenRouter padahal sudah set Gemini**

Cek `defaults.model.primary` di `openclaw.json` — pastikan tidak ada `openrouter/google/...`:
```bash
grep -A2 '"primary"' ~/.openclaw/openclaw.json | grep openrouter
```
Kalau ada, ganti ke `gemini/models/gemini-2.5-flash`.

**Error 400 "API key expired"**

Key sudah di-revoke atau expired. Buat key baru di [Google AI Studio](https://aistudio.google.com/app/apikey) lalu update:
- `~/.openclaw/agents/*/agent/auth-profiles.json`
- `~/.openclaw/openclaw.json` (cari `AIzaSy` lama, replace semua)

**Agent fallback ke DeepSeek terus padahal Gemini sudah OK**

OpenClaw tidak auto-revert ke primary setelah fallback. Reset session agent:
- Via Telegram: ketik `/new` ke agent
- Atau restart OpenClaw

**Error 400 "unsupported param" masih muncul**

Pastikan proxy sudah jalan dan `baseUrl` mengarah ke proxy:
```bash
systemctl status gemini-proxy
grep "baseUrl" ~/.openclaw/openclaw.json | grep 9998
```

**Proxy tidak mau start**

```bash
journalctl -u gemini-proxy -n 30
# Cek apakah port 9998 sudah dipakai
ss -tlnp | grep 9998
```

---

## Cara Pakai (Umum)

### Python (OpenAI SDK)
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://127.0.0.1:9998/v1",
    api_key="YOUR_GEMINI_API_KEY"
)

response = client.chat.completions.create(
    model="gemini-2.5-flash",
    messages=[{"role": "user", "content": "Halo!"}]
)
print(response.choices[0].message.content)
```

### curl
```bash
curl -X POST http://127.0.0.1:9998/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_GEMINI_API_KEY" \
  -d '{
    "model": "gemini-2.5-flash",
    "messages": [{"role": "user", "content": "Halo!"}]
  }'
```

---

## Konfigurasi

| Variable | Default | Keterangan |
|----------|---------|------------|
| `PROXY_PORT` | `9998` | Port proxy |
| `PROXY_HOST` | `127.0.0.1` | Bind address |
| `GOOGLE_BASE` | `https://generativelanguage.googleapis.com/v1beta/openai` | Google API endpoint |

Edit `/opt/gemini-proxy/.env` lalu restart:
```bash
systemctl restart gemini-proxy
```

---

## Manajemen Service

```bash
systemctl status gemini-proxy     # Status
journalctl -u gemini-proxy -f     # Log realtime
systemctl restart gemini-proxy    # Restart
systemctl stop gemini-proxy       # Stop
sudo bash install.sh uninstall    # Uninstall
```

---

## Model yang Didukung

| Model | Keterangan |
|-------|------------|
| `gemini-2.5-flash` | Cepat, recommended untuk sehari-hari |
| `gemini-2.5-pro` | Paling powerful, lebih lambat |
| `gemini-2.0-flash` | Stabil, alternatif |
| `gemini-1.5-flash` | Hemat, konteks panjang |

Daftar lengkap: [Google AI Models](https://ai.google.dev/gemini-api/docs/models)

---

## Lisensi

MIT License — bebas digunakan dan dimodifikasi.
