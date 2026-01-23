# Real-Time Data Setup Instructions

## Problem Solved ✅

Your Flutter app now receives **REAL-TIME** Schumann Resonance data from the Python scraper!

## What Was Fixed:

1. **Python Script**: Now saves CSV to project root (`d:\apppp\gci_hourly_log_clean.csv`)
2. **Flutter App**: Prioritizes reading from root directory first
3. **Refresh Rate**: App checks for updates every 5 minutes (instead of hourly)
4. **Debug Logging**: Added console logs to track file locations

---

## How to Use:

### Step 1: Start the Data Collector

**Option A - Double-click the batch file:**
```
start_data_collector.bat
```

**Option B - Run manually:**
```bash
cd d:\apppp
python python\main.py
```

This will:
- Launch a headless Chrome browser
- Scrape data from HeartMath GCI every hour
- Save to `gci_hourly_log_clean.csv` in the project root
- Run continuously until you press Ctrl+C

### Step 2: Run Your Flutter App

```bash
flutter run
```

The app will:
- Read the CSV file from the root directory
- Display the latest "Global Avg Power" value
- Auto-refresh every 5 minutes
- Show debug logs in console

---

## How It Works:

```
Python Scraper (every 1 hour)
    ↓
Fetches live data → Saves to root CSV
    ↓
Flutter App (every 5 minutes)
    ↓
Reads CSV → Displays latest frequency
```

---

## Verification Steps:

1. **Check Python is running:**
   - You should see console output like "Launching browser..."
   - After ~10 seconds: "✅ Success! Captured X sites"

2. **Check CSV is being updated:**
   - Open `gci_hourly_log_clean.csv`
   - New rows should appear every hour with current UTC timestamp

3. **Check Flutter app:**
   - Open Flutter debug console
   - Look for: "✅ CSV file found at: gci_hourly_log_clean.csv"
   - Look for: "✅ Updated frequency: XX.XX Hz"

---

## Troubleshooting:

### Python Script Not Running:
```bash
# Install dependencies if missing:
pip install selenium webdriver-manager
```

### CSV File Not Found in Flutter:
- Check Flutter console for path attempts
- Verify CSV exists in root: `d:\apppp\gci_hourly_log_clean.csv`

### Old Data Showing:
- Wait up to 5 minutes for app to refresh
- Or restart the Flutter app to force immediate reload

### No Internet Connection:
- Python scraper needs internet to fetch HeartMath data
- App will keep showing last known value from CSV

---

## File Locations:

- **CSV Data**: `d:\apppp\gci_hourly_log_clean.csv` (root)
- **Python Script**: `d:\apppp\python\main.py`
- **Flutter App**: `d:\apppp\lib\main.dart`
- **Start Script**: `d:\apppp\start_data_collector.bat`

---

## Next Steps:

1. Keep Python script running in background
2. Launch your Flutter app
3. Watch the frequency update in real-time!

The frequency display should change as new data comes in every hour from the Global Coherence Initiative monitoring stations worldwide.
