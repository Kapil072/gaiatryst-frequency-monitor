# GAIATRYST SYNOPSIS - API Setup Guide

## What is this?

This is a **backend API server** that automatically fetches live Schumann Resonance data from the HeartMath website and makes it available to your Flutter app. This enables **real-time updates on ALL platforms** including iOS and Android.

---

## Quick Start

### 1. Install Python Dependencies

```bash
cd api
pip install -r requirements.txt
```

### 2. Start the API Server

```bash
python server.py
```

You should see:
```
🌍 GAIATRYST SYNOPSIS API Server Starting...
✅ Initial data loaded: 127.50 Hz
🚀 API Server running on http://localhost:5000
🔄 Auto-refreshing every 5 minutes
```

### 3. Run Your Flutter App

The app will automatically connect to the API when it's running.

```bash
flutter run
```

---

## How It Works

1. **API Server** (`api/server.py`):
   - Runs in the background
   - Fetches live data from HeartMath every 5 minutes
   - Serves data via REST API at `http://localhost:5000/api/data`

2. **Flutter App** (`lib/main.dart`):
   - Tries to fetch from API first (works on ALL platforms)
   - Falls back to CSV if API is not available (desktop only)
   - Refreshes every 5 minutes automatically

---

## API Endpoints

### `GET /api/data`
Returns current Schumann Resonance data

**Response:**
```json
{
  "timestamp": "2026-01-20T12:30:00.000000+00:00",
  "global_avg": 127.5,
  "stations": {
    "GCI001": 137,
    "GCI002": 0,
    "GCI003": 118,
    "GCI004": 0,
    "GCI005": 0,
    "GCI006": 0
  },
  "last_update": "2026-01-20 12:30:00 UTC"
}
```

### `GET /api/health`
Check if the API is running

**Response:**
```json
{
  "status": "healthy",
  "last_update": "2026-01-20 12:30:00 UTC",
  "update_interval": "300 seconds"
}
```

---

## For Mobile Deployment (iOS/Android)

To use this on mobile devices:

1. Deploy the API server to a cloud service (Heroku, Railway, Google Cloud, etc.)
2. Update the API URL in `lib/main.dart`:
   ```dart
   Uri.parse('https://your-api-domain.com/api/data')
   ```

---

## Testing

Test the API manually:
```bash
curl http://localhost:5000/api/data
```

You should see JSON data with the current frequencies.

---

## Troubleshooting

**API Server won't start:**
- Make sure all dependencies are installed: `pip install -r requirements.txt`
- Check if port 5000 is available

**App shows "API not available":**
- Make sure the API server is running
- Check that `http://localhost:5000/api/data` is accessible in your browser

**Old data showing:**
- Wait 5 minutes for the next auto-refresh
- Or restart the app to force immediate reload
