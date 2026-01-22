# GAIATRYST SYNOPSIS - Real-time Schumann Resonance Monitor

A Flutter application that monitors real-time Schumann Resonance frequencies from the Global Coherence Initiative, featuring live Earth visualization and automatic data updates.

## 🌟 Features

- **Real-time Frequency Monitoring**: Tracks Schumann Resonance from 6 global stations
- **Live Earth Visualization**: Interactive 3D Earth with pulsating location markers
- **Automatic Updates**: Data refreshed every minute via GitHub Actions
- **Cross-platform**: Runs on Android, iOS, Web, and Desktop
- **Offline Capability**: Works with cached data when offline

## 📊 Data Sources

The app collects live data from Global Coherence Initiative monitoring stations:
- **GCI001**: California, USA (~118 Hz)
- **GCI002**: Hofuf, Saudi Arabia 
- **GCI003**: Lithuania (~150 Hz)
- **GCI004**: Alberta, Canada
- **GCI005**: Northland, New Zealand
- **GCI006**: Hluhluwe, South Africa (~500 Hz)

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.0+
- Node.js 16+ (for server deployment)
- Python 3.8+ (for data collection)

### Installation

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/gaiatryst-synopsis.git
cd gaiatryst-synopsis

# Install Flutter dependencies
flutter pub get

# Install server dependencies
cd server
npm install
cd ..

# Install Python dependencies
pip install selenium webdriver-manager
```

### Running the Application

#### Option 1: Automatic Server Launch (Desktop - Recommended)
```bash
# Windows: Double-click launch_app_with_server.bat
# Or run in PowerShell: .\launch_app_with_server.ps1
```
This automatically starts the data server and Flutter app with live data.

#### Option 2: Manual Server Control
```bash
# Terminal 1: Start data server
cd server
npm start

# Terminal 2: Run Flutter app
flutter run
```

#### Option 3: Mobile Deployment
Update server URL in `lib/main.dart` to your deployed server address.

## ⚙️ Automated Data Collection

This repository uses GitHub Actions for automatic data collection:
- **Frequency**: Every minute
- **Data Source**: GCI website scraping
- **Storage**: CSV file in `assets/gci_hourly_log_clean.csv`
- **Trigger**: Scheduled workflow or manual dispatch

## 🏗️ Architecture

```
GCI Website → Python Scraper → CSV Storage → GitHub Actions → Flutter App
```

### Components

1. **Flutter Frontend** (`lib/main.dart`)
   - Real-time 3D Earth visualization
   - Live frequency display
   - Automatic data synchronization

2. **Data Collector** (`python/main.py`)
   - Selenium-based web scraping
   - Automated data extraction
   - CSV format storage

3. **GitHub Actions** (`.github/workflows/auto-frequency-update.yml`)
   - Scheduled data collection
   - Automatic commits and pushes
   - Continuous data updates

## 📱 Deployment Options

### Mobile Apps
```bash
# Android APK
flutter build apk --release

# iOS App Bundle
flutter build ios --release
```

### Web Deployment
```bash
flutter build web
# Deploy build/web to hosting service
```

### Server Deployment
Deploy `server/` directory to:
- Heroku
- Render.com
- DigitalOcean App Platform
- AWS/GCP/Azure

## 🔧 API Endpoints

When deployed, the server provides:
- `GET /api/data` - Latest frequency data
- `POST /api/update` - Manual data refresh

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- Global Coherence Initiative for data sources
- Flutter team for the amazing framework
- Open source community for various libraries
