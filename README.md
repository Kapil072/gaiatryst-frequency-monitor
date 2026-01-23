# GAIATRYST SYNOPSIS

A cross-platform Flutter application that visualizes Schumann Resonance data with a 3D rotating Earth visualization. This app monitors Earth's electromagnetic field and displays real-time data from Global Coherence Initiative (GCI) monitoring stations.

## Features

- 🌍 **3D Earth Visualization**: Interactive rotating globe with real-time location markers
- 📊 **Live Data Monitoring**: Real-time Schumann resonance frequency display
- 📍 **Station Tracking**: Monitor 6 GCI stations worldwide (USA, Saudi Arabia, Lithuania, Canada, New Zealand, South Africa)
- 📱 **Cross-Platform**: Runs on iOS, Android, Web, Windows, macOS, and Linux
- 🔴 **Offline Mode**: Graceful fallback when live data is unavailable
- 🎓 **Educational Content**: Comprehensive information about Schumann resonance and collective consciousness

## Architecture

### Frontend (Flutter App)
- **Location**: `/lib/main.dart`
- **Dependencies**: flutter_cube, http, csv, url_launcher
- **Features**: 3D rendering, real-time data display, offline fallback

### Backend Services

#### API Server (`/api/server.py`)
- Flask-based REST API on port 5002
- `/api/data` endpoint for live Schumann data
- Auto-refreshes every 60 seconds
- CORS-enabled for Flutter integration

#### Data Collector (`/python/main.py`)
- Selenium-based web scraper for HeartMath website
- Collects data every hour from 6 GCI monitoring stations
- Stores data in CSV format for persistence

## Setup Instructions

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Python 3.8+
- Chrome/Chromium browser
- Git

### Installation

1. **Clone the repository:**
```bash
git clone <your-repo-url>
cd gaiatryst-synopsis
```

2. **Install Flutter dependencies:**
```bash
flutter pub get
```

3. **Install Python dependencies:**
```bash
cd api
pip install -r requirements.txt
```

4. **Run the API server:**
```bash
python server.py
```

5. **Run the Flutter app:**
```bash
flutter run
```

## Data Refresh Schedule

The system automatically refreshes data **twice daily**:
- **Morning**: 6:00 AM UTC
- **Evening**: 6:00 PM UTC

This ensures fresh data while respecting API limitations and providing consistent updates.

## API Endpoints

- `GET /api/data` - Current Schumann resonance data
- `GET /api/health` - API health status
- `GET /` - API documentation

## Project Structure

```
.
├── api/                 # Backend API server
│   ├── server.py       # Flask API server
│   ├── requirements.txt # Python dependencies
│   └── test_scraping.py # Testing utilities
├── assets/             # Static assets
│   ├── 13902_Earth_v1_l3.obj # 3D Earth model
│   ├── 8k_earth_daymap.jpg   # Earth texture
│   └── various images
├── lib/                # Flutter source code
│   └── main.dart       # Main application
├── python/             # Data collection scripts
│   └── main.py         # Web scraper
├── README.md           # This file
└── pubspec.yaml        # Flutter dependencies
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is proprietary software developed by Integrative Tech Solutions.

## Contact

For questions or support, please contact the development team.
