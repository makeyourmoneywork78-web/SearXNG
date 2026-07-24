# SearXNG search backend (Docker → Render)

A self-contained SearXNG image tuned to be a **reliable, private search backend**
for the discovery app. It fixes the two defaults that otherwise break the
integration:

- enables the **JSON API** (`search.formats: [html, json]`) — off by default,
- forces **HTTP GET** search (`server.method: GET`) — the app calls SearXNG with GET,
- disables the **bot limiter** so the app's automated calls are not rate-limited.

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Builds on the official `searxng/searxng` image. |
| `settings.yml` | The tuned config (JSON on, GET, limiter off, bounded timeouts). |
| `render-entrypoint.sh` | Installs the config, injects a random secret, binds to `$PORT`. |

## Build & test locally

```bash
docker build -t epfo-searxng deploy/searxng
docker run --rm -p 8080:8080 epfo-searxng

# In another terminal — this MUST return JSON (proves the integration works):
curl "http://localhost:8080/search?q=Infosys%20CIN&format=json&categories=general" | head
```

If you get JSON with a `results` array, the backend is correct.

## Deploy on Render

1. Push this repo to GitHub (Render builds from the repo + Dockerfile).
2. Render → **New → Web Service** → connect the repo.
3. Settings:
   - **Runtime:** Docker
   - **Dockerfile Path:** `deploy/searxng/Dockerfile`
   - **Docker Build Context Directory:** `deploy/searxng`
   - **Health Check Path:** `/` (SearXNG root returns 200)
4. (Optional) Environment variables:
   - `SEARXNG_SECRET` — set a fixed random string if you want the secret stable across restarts.
   - `SEARXNG_ENGINES` is **not** set here — it is sent per-request by the app (see below).
5. Deploy. Note the service URL, e.g. `https://epfo-searxng.onrender.com`.

Render sets `$PORT` (10000); `render-entrypoint.sh` binds SearXNG to it automatically.

### Verify the deployed instance

```bash
curl "https://<your-service>.onrender.com/search?q=Infosys%20CIN&format=json" | head
```

## Connect the app

Set these on the **main app** service (not on SearXNG):

```bash
# Enables SearXNG as an automatic fallback after DDGS/HTML (DDGS stays primary).
SEARXNG_BASE_URL=https://<your-service>.onrender.com

# Optional engine tuning sent per-request. A lean, reliable set that resolves
# Indian company/registry pages (zaubacorp/tofler/thecompanycheck) well and
# avoids Google's aggressive scraping blocks:
SEARXNG_ENGINES=bing,duckduckgo,brave
```

- Keep `SOURCE_SEARCH_PROVIDER=auto` (the default) to keep **DDGS primary** and SearXNG as the reliable backstop.
- To make SearXNG **primary** instead, set `SOURCE_SEARCH_PROVIDER=searxng,ddgs,html`.

The app already sends smart, registry-targeted queries (`"<name>" CIN`,
`site:zaubacorp.com …`, etc.) and adaptively fires only the cheapest query first —
so SearXNG receives focused keywords, not broad noise.
