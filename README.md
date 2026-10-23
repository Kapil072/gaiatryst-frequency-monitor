# GAIATRYST SYNOPSIS — Schumann Resonance Link

**Gaiatryst Schumann Sync Link** is a cross-platform Flutter application that visualizes live Schumann Resonance data from the [HeartMath Global Coherence Initiative (GCI)](https://www.heartmath.org/gci/) on a rotating 3D Earth globe. It combines real-time frequency monitoring, animated station markers, educational content, and an automated data pipeline built from web scraping and computer vision.

---

## Table of Contents

1. [What This Project Does](#what-this-project-does)
2. [High-Level Architecture](#high-level-architecture)
3. [Project Structure](#project-structure)
4. [Flutter Mobile App](#flutter-mobile-app)
5. [Data Pipeline & Web Scraping](#data-pipeline--web-scraping)
6. [Data Format (`data.json`)](#data-format-datajson)
7. [Monitoring Stations](#monitoring-stations)
8. [GitHub Actions Automation](#github-actions-automation)
9. [Local Development Setup](#local-development-setup)
10. [Building for Production](#building-for-production)
11. [Platform Configuration](#platform-configuration)
12. [Assets & 3D Models](#assets--3d-models)
13. [External Links & Credits](#external-links--credits)
14. [Troubleshooting](#troubleshooting)
15. [Related Documentation Files](#related-documentation-files)

---

## What This Project Does

The app serves as a **real-time Schumann Resonance monitor** and **educational portal**:

- Displays the **global average frequency** (Hz) from GCI monitoring stations worldwide
- Shows **per-station readings** for 6 GCI sites (USA, Saudi Arabia, Lithuania, Canada, New Zealand, South Africa)
- Renders a **3D rotating Earth** with golden pulsing dots at each station location
- Provides scrollable **educational content** about Schumann resonance, Gaiatryst philosophy, and contributor links
- Handles **offline / no-internet** states gracefully with retry logic

**Data source:** HeartMath Institute's Global Coherence Initiative sensor network.

**Concept:** Gaiatrysts are DIY tech tools to sync breathing, heartbeats, brain waves, and planetary Schumann resonance — promoting collective consciousness and ecological awareness.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        HEARTMATH GCI (Data Source)                       │
│  • Spectrogram calendar: nocc.heartmath.org/spectrogram/index.php       │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │ Spectrogram scraper   │
                    │ (Playwright + OpenCV) │
                    │ api/test_scraping.py  │
                    └───────────┬───────────┘
                                │ GitHub Actions (every 6h)
                                │ commits data.json to repo
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Hosted JSON (production feed for Flutter app)
│  • Primary:   raw.githubusercontent.com/Kapil072/gaiatryst-frequency-monitor/main/data.json
│  • Fallback:  cdn.jsdelivr.net/gh/Kapil072/gaiatryst-frequency-monitor@main/data.json
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ HTTP GET every 3 minutes
                                ▼
                    ┌───────────────────────┐
                    │   Flutter App         │
                    │   lib/main.dart       │
                    │   (iOS/Android/Web/  │
                    │    Windows/macOS/     │
                    │    Linux)             │
                    └───────────────────────┘
```

### Current Production Data Path

The **Flutter app currently fetches remote JSON only** — it does **not** read local CSV files or a local API server at runtime. The canonical live feed is hosted on GitHub:

| Priority | URL |
|----------|-----|
| Primary | `https://raw.githubusercontent.com/Kapil072/gaiatryst-frequency-monitor/main/data.json` |
| Fallback | `https://cdn.jsdelivr.net/gh/Kapil072/gaiatryst-frequency-monitor@main/data.json` |

The spectrogram scraper in this repo (`api/test_scraping.py`) generates `data.json`, and GitHub Actions commits it so the hosted JSON stays updated.

---

## Project Structure

```
GAIATRYST SYNOPSIS/
│
├── lib/
│   └── main.dart                          # Entire Flutter app (UI + 3D globe + data fetching)
│
├── api/
│   ├── test_scraping.py                   # Spectrogram scraper + OpenCV analyzer → data.json
│   └── requirements.txt                   # Python dependencies for the scraper
│
├── .github/workflows/
│   └── update-spectrogram-v2.yml          # Runs the scraper every 6 hours
│
├── assets/                                # Images, 3D models, textures
│   ├── IMG_8725.JPG.jpeg                  # Earth surface texture (applied at runtime)
│   └── [educational images, app icon, etc.]
│
├── android/                               # Android platform config
├── ios/                                   # iOS platform config
├── web/                                   # Web platform entry
├── windows/ macos/ linux/                 # Desktop platform configs
│
├── data.json                              # Live frequency data (updated by GitHub Actions)
│
├── pubspec.yaml                           # Flutter dependencies & asset declarations
└── README.md                              # This file
```

---

## Flutter Mobile App

**Package name:** `gaiatryst_schumann_sync`  
**Entry point:** `lib/main.dart` (single-file architecture — all UI, 3D, and networking live here)  
**Version:** 1.0.0+1  
**Orientation:** Portrait only (locked via `SystemChrome.setPreferredOrientations`)

### Dependencies

| Package | Purpose |
|---------|---------|
| `vector_math` | Matrices for the globe's camera and rotation |
| `http` | Fetch live JSON data from GitHub/CDN |
| `url_launcher` | Open external links (Gaiatryst, HeartMath, YouTube, etc.) |

### App Screens & UI Layout

The app has one main screen: `EarthViewPage`.

```
┌─────────────────────────────────────┐
│  Header: Logo + "GAIATRYST SYNOPSIS │
│          SCHUMANN RESONANCE LINK"   │
├─────────────────────────────────────┤
│                                     │
│     3D Rotating Earth Globe         │  ← 60% of screen height
│     (golden pulsing station dots)   │
│                                     │
├─────────────────────────────────────┤
│  Average Data: XX.XX Hz             │  ← Live / OFFLINE / NO SIGNAL
│  Status: Live / No Connection       │
├─────────────────────────────────────┤
│  Monitoring Stations Grid           │  ← 6 station cards (110×80 px)
│  [USA] [Saudi] [Lithuania] ...      │
├─────────────────────────────────────┤
│  Info Panel (scrollable)            │  ← Educational text, images, links
│  - Why this App                     │
│  - Schumann resonance explanation   │
│  - Gaiatryst origins & credits      │
└─────────────────────────────────────┘
     Animated star field (background)
```

### 3D Globe System (`_GlobeWidget`)

**Earth (`_GlobePainter`):**
- 48×24 UV sphere generated in code (2,208 triangles), drawn with one `Canvas.drawVertices` call per frame
- Texture from `assets/IMG_8725.JPG.jpeg` (downscaled to 1024px width); vertices carry no colors, so output is identical on Skia, Impeller and web
- Only front-facing triangles are drawn, so no depth sorting is needed; all buffers are allocated once
- Model transform: tilt (Z, -23.5°) × spin (Y, 9.375°/s) × base (X, -90°, scale 3×)

**Golden station dots:**
- Projected with the same camera and drawn in the same painter
- Solid `#FFD700` gold core with a radial-gradient gold glow
- Fade out as they rotate behind the globe's limb
- **Pulse animation:** sine wave, 1.2s period

**Lat/lon → 3D position:**
```dart
// Radius 0.505 on unit sphere, converted from degrees
Vector3(
  r * cos(lat) * cos(lon),
  r * cos(lat) * sin(lon),
  r * sin(lat),
)
```

**Performance optimizations:**
- `RepaintBoundary` around globe, star field, and info sections
- No per-frame object allocation, lighting, or triangle sorting
- Animation drives only the painter (`repaint:` listenable), never a widget rebuild
- Animation pauses while the globe is scrolled out of view
- Delta time clamped to 50ms max per frame

### Star Field Background (`_StarField`)

- 120 procedurally placed stars (seeded random: `Random(42)`)
- Each star twinkles independently via sine wave opacity
- Rendered with `CustomPaint` on a full-screen canvas

### Live Data Fetching (`EarthViewPage`)

**Schedule:**
- First fetch: 3 seconds after app launch
- Refresh: every **3 minutes** via `Timer.periodic`

**Fetch logic:**
1. Check internet via DNS lookup to `google.com` (5s timeout)
2. If offline → show "NO SIGNAL" banner, retry in 30 seconds
3. If online → HTTP GET to primary or fallback JSON URL (alternates on retry)
4. Parse JSON on background isolate via `compute(_parseJson, ...)`
5. Validate: `is_live == true` AND `global_avg != null`
6. Extract per-station values from `stations` map for known GCI IDs
7. On failure → exponential backoff retry (5 attempts, max 60s delay)

**Display states:**

| Condition | Average Display | Status Text |
|-----------|----------------|-------------|
| Live data received | `X.XX Hz` (cyan) | "Live" |
| No internet | `NO SIGNAL` (orange) | "No Internet" |
| Online but no live data | `OFFLINE` (red) | "No Connection" |

**HTTP headers sent:**
```
Accept: application/json, text/plain, */*
User-Agent: GaiatrystApp/1.0
Cache-Control: no-cache, no-store, must-revalidate
Pragma: no-cache
Connection: keep-alive
```

### Info Panel Content

Scrollable educational section includes:
- Gaiatryst mission and philosophy text
- "Why this App" image and Medium article link
- Schumann resonance science explanation with diagrams
- Contributor credits (Gaiatryst, Integrative Tech Solutions, HeartMath, Sacred Animals Party)
- YouTube links and additional imagery

All external links open via `url_launcher` with fallback modes (external app → in-app browser → platform default).

---

## Data Pipeline & Web Scraping

### Spectrogram Scraper

**File:** `api/test_scraping.py`  
**Method:** Playwright browser automation + OpenCV image analysis  
**Output:** `data.json` (project root)  
**Schedule:** GitHub Actions every 6 hours + manual trigger

#### Step 1: Scrape HeartMath Spectrogram Calendar

```
URL: https://nocc.heartmath.org/spectrogram/index.php
```

> HeartMath moved this page in 2026. The old `heartmath.org/gci/gcms/live-data/spectrogram-calendar/` URL now redirects to the GCI home page and has no images.

1. Launch headless Chromium via Playwright
2. Wait for page network idle (60s timeout)
3. Scan all page frames for `<a href="...jpg">` links (e.g. `gci001/SPGRM_2026_10_21_ch2.jpg`)
4. Extract dates from URLs using regex `(\d{4}_\d{2}_\d{2})`
5. Select the **latest (maximum) date** found
6. Download all JPG spectrogram images for that date into `spectrograms_YYYY_MM_DD/`
7. If no images are found or none can be analyzed, exit with code 1 so the workflow run fails visibly

#### Step 2: Analyze Each Spectrogram (OpenCV)

Each image is a frequency-vs-time spectrogram. The analyzer finds the peak Schumann frequency:

| Parameter | Value |
|-----------|-------|
| Max frequency (FMAX) | 50 Hz |
| Target band | 7–9 Hz (primary Schumann resonance) |
| Method | Row intensity profile → argmax in target band |

```python
# Convert image to grayscale, blur, compute row mean intensity
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
gray = cv2.GaussianBlur(gray, (5, 5), 0)
row_intensity = np.mean(gray, axis=1)

# Map 7–9 Hz to pixel rows (inverted Y axis)
y_low  = int(height * (1 - 9 / 50))   # 9 Hz
y_high = int(height * (1 - 7 / 50))   # 7 Hz

peak_row = argmax(row_intensity[y_low:y_high]) + y_low
frequency = (1 - peak_row / height) * 50
```

#### Step 3: Build & Save `data.json`

- Maps site folder names (`gci001`…`gci006`) → GCI station IDs
- Computes `global_avg` from all valid station frequencies
- Sets `is_live: true` when at least one station has data
- Also writes `spectrograms_YYYY_MM_DD/analysis_summary.csv` (not committed)

---

## Data Format (`data.json`)

This is the schema consumed by the Flutter app:

```json
{
  "timestamp": "2026-10-23 13:51:41 UTC",
  "global_avg": 7.95,
  "stations": {
    "GCI001": 7.95,
    "GCI003": 7.86,
    "GCI005": 8.04
  },
  "active_stations": 3,
  "source": "HeartMath Spectrogram Analysis",
  "status": "live",
  "is_live": true
}
```

| Field | Type | Required by App | Description |
|-------|------|-----------------|-------------|
| `timestamp` | string | No | UTC timestamp of last data update |
| `global_avg` | number | **Yes** | Average frequency across active stations (Hz) |
| `stations` | object | No | Map of GCI ID → frequency (Hz) |
| `active_stations` | number | No | Count of stations with data |
| `source` | string | No | Data origin description |
| `status` | string | No | `"live"` or `"offline"` |
| `is_live` | boolean | **Yes** | Must be `true` for app to display data |

**App validation rule:** Data is shown only when `is_live == true` AND `global_avg` is not null.

---

## Monitoring Stations

Six GCI stations are hardcoded in `lib/main.dart`:

| ID | Display Name | Latitude | Longitude | HeartMath Location |
|----|-------------|----------|-----------|-------------------|
| GCI001 | USA | 33.0 | 162.05 | California, USA |
| GCI002 | Saudi Arabia | 26.8 | -45.16 | Hofuf, Saudi Arabia |
| GCI003 | Lithuania | 55.83 | -75.72 | Lithuania |
| GCI004 | Canada | 47.6 | 165.57 | Alberta, Canada |
| GCI005 | New Zealand | -39.73 | 84.32 | Northland, New Zealand |
| GCI006 | South Africa | -28.02 | -62.28 | Hluhluwe, South Africa |

Each station appears as:
- A **golden pulsing dot** on the 3D globe at its lat/lon coordinates
- A **card in the station grid** showing name + frequency or "Offline"

The HeartMath spectrogram page currently publishes GCI001, GCI003 and GCI005; the other stations show "Offline" until HeartMath publishes them again.

---

## GitHub Actions Automation

**Active workflow:** `.github/workflows/update-spectrogram-v2.yml`

| Setting | Value |
|---------|-------|
| Trigger | Cron `0 */6 * * *` (every 6 hours UTC) |
| Manual trigger | Yes (`workflow_dispatch`) |
| Python version | 3.12 |
| Script | `python api/test_scraping.py` |

**What it does:**
1. Installs the packages in `api/requirements.txt` and Playwright's Chromium
2. Runs spectrogram scraper & analyzer (fails the run if no spectrograms are found)
3. Commits only `data.json` to the repository; downloaded images are never committed
4. Uses `[skip ci]` in commit message to prevent infinite workflow loops

**Permissions required:** `contents: write` (so the bot can push commits)

**Auto-disable:** GitHub disables scheduled workflows after 60 days without repository activity. If the Actions tab shows the workflow as disabled, open it and click **Enable workflow**, then use **Run workflow** to test it.

---

## Local Development Setup

### Prerequisites

- **Flutter SDK** ≥ 3.0.0
- **Python** 3.8+ (for the scraper)
- **Git**

### Flutter App

```bash
# Clone and enter project
git clone <repo-url>
cd "GAIATRYST SYNOPSIS"

# Install Flutter dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Run on specific platform
flutter run -d chrome      # Web
flutter run -d windows     # Windows desktop
flutter run -d android     # Android
```

### Spectrogram Scraper (Manual)

```bash
pip install -r api/requirements.txt
python -m playwright install chromium
python api/test_scraping.py
# Updates data.json in project root
```

---

## Building for Production

```bash
flutter build apk          # Android APK
flutter build appbundle    # Android App Bundle (Play Store)
flutter build ios          # iOS (requires macOS + Xcode)
flutter build web          # Web deployment
flutter build windows      # Windows desktop
flutter build macos        # macOS desktop
flutter build linux        # Linux desktop
```

**App icon:** Generated from `assets/WhatsApp_Image_2025-12-28_at_5.00.39_PM-removebg-preview (1).png` via `flutter_launcher_icons`.

---

## Platform Configuration

### Android (`android/app/src/main/AndroidManifest.xml`)

- `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE` permissions
- `usesCleartextTraffic="true"` for HTTP fallback scenarios
- Custom network security config for GitHub/jsDelivr HTTPS
- Default renderer (Impeller)
- `<queries>` block for Android 11+ URL launching

### iOS (`ios/Runner/Info.plist`)

- Display name: **Gaiatryst**
- Impeller **disabled** (`FLTEnableImpeller=false`)
- Supports portrait and landscape orientations

### Web (`web/index.html`, `web/manifest.json`)

Standard Flutter web bootstrap. The app works in browsers with WebGL support for 3D rendering.

---

## Assets & 3D Models

| Asset | Purpose |
|-------|---------|
| `IMG_8725.JPG.jpeg` | Earth surface texture (runtime-applied) |
| `why this app.png` | Info panel illustration |
| `Picture1.png` | Schumann field diagram |
| `More about Schumann Vibes .jpg` | Educational image |
| `IMG_9429.jpeg` | SR Final Full Monte section image |
| `WhatsApp_Image_...png` | App header logo & launcher icon |

---

## External Links & Credits

Hardcoded in `_kLinks` constant:

| Key | URL | Used For |
|-----|-----|----------|
| `gaiatryst` | https://gaiatryst.com/ | Concept / Big Medicine's Gaiatryst team |
| `dev` | https://www.integrativetechsolutions.com | Development credit |
| `heartmath` | https://www.heartmath.org/gci/ | Data source credit |
| `sacred` | https://sacredanimalsparty.net | Project nursery |
| `youtube` | https://www.youtube.com/watch?v=k8xynWgxQ1U | Stefan Burb cosmic evolution video |
| `medium` | https://medium.com/@neurokinetikz/... | Schumann-Resonant Brain Dynamics article |

---

## Troubleshooting

### App shows "OFFLINE" or "NO SIGNAL"

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| NO SIGNAL (orange) | Device has no internet | Check WiFi/mobile data; app retries every 30s |
| OFFLINE (red) | JSON fetch failed or `is_live: false` | Verify GitHub JSON URL is accessible in browser |
| Stale data | CDN cache | App sends `Cache-Control: no-cache`; wait for next 3-min refresh |

### Android network issues

- Ensure `INTERNET` permission is in manifest (already configured)
- Ensure `<queries>` block exists for Android 11+ (already configured)
- Check `network_security_config.xml` trusts GitHub/jsDelivr certificates

### 3D globe not loading

- Check console for texture load errors on `IMG_8725.JPG.jpeg`
- If issues persist, try `flutter clean && flutter pub get`

### Scraper fails locally

```bash
pip install -r api/requirements.txt
python -m playwright install chromium
python api/test_scraping.py
```

If it prints `Could not find any dated image links`, HeartMath has probably moved the spectrogram page again. Find the new page from https://www.heartmath.org/gci/gcms/ and update `url` in `api/test_scraping.py`.

### GitHub Actions not updating data

- Check the Actions tab: a workflow marked **disabled** (60 days of inactivity) must be re-enabled by hand
- Open the failed run's "Run the Spectrogram Scraper & Analyzer" log for the scraper's error
- Verify `contents: write` permission in workflow
- HeartMath site may be slow — scraper has 60s page timeout

---

## Related Documentation Files

This file contains additional detail on the data pipeline:

| File | Topic |
|------|-------|
| `SPECTROGRAM_SCRAPER_README.md` | Spectrogram pipeline deep dive |

---

## License & Contact

**License:** Proprietary — developed by [Integrative Tech Solutions](https://www.integrativetechsolutions.com).

**Concept:** [Big Medicine's Gaiatryst team](https://gaiatryst.com/)

**Data:** [HeartMath Global Coherence Initiative](https://www.heartmath.org/gci/)

For questions or support, contact the development team at Integrative Tech Solutions.
