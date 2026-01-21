# Server Setup for Real-Time Data on Mobile

## Overview
This document explains how to set up a web server that runs the Python script to fetch real-time Schumann Resonance data and provides an API for the mobile app.

## Prerequisites
- Node.js installed on your server
- Python with required packages (selenium, webdriver-manager) installed on the server
- Access to run both Node.js and Python on your server

## Server Setup

### 1. Navigate to the server directory:
```bash
cd server/
```

### 2. Install dependencies:
```bash
npm install
```

### 3. Run the server:
```bash
npm start
```

The server will:
- Run the Python script every 10 minutes to fetch new data
- Host an API at `http://localhost:3000/api/data` (or your server URL)
- Provide endpoints to manually trigger updates

## API Endpoints

### GET `/api/data`
Returns the latest collected data

Response:
```json
{
  "success": true,
  "data": {
    "Timestamp (UTC)": "2023-12-01 12:00:00",
    "Global Avg Power": "7.8",
    "GCI001": "7.8",
    "GCI002": "7.9",
    "...": "..."
  },
  "lastUpdated": "2023-12-01T12:00:00.000Z",
  "timestamp": "2023-12-01T12:00:00.000Z"
}
```

### POST `/api/update`
Manually triggers a data update

## Mobile App Integration

### 1. Update the API URL in your Flutter app
Replace the placeholder URL in `_fetchMobileData()` function:

```dart
// Change this line in lib/main.dart:
final apiUrl = 'https://your-actual-server.com/api/data';
```

### 2. Rebuild your app:
```bash
flutter clean
flutter pub get
flutter build apk
```

## Deployment Options

### Option 1: Self-hosted Server
Deploy the Node.js server to any VPS or cloud provider that supports both Node.js and Python.

### Option 2: Cloud Platforms
Some cloud platforms that support both Node.js and Python:
- DigitalOcean
- AWS EC2
- Google Cloud Platform
- Azure

### Option 3: Container Solution
Create a Docker container that runs both the Node.js server and Python environment.

## Docker Setup (Optional)

Create a `Dockerfile`:
```dockerfile
FROM node:18

WORKDIR /app

# Install Python and other dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    chromium-browser \
    chromium-chromedriver \
    && rm -rf /var/lib/apt/lists/*

# Create symbolic links
RUN ln -s /usr/bin/python3 /usr/bin/python
RUN ln -s /usr/bin/chromium-browser /usr/bin/google-chrome

COPY server/package*.json ./
RUN npm install

COPY . .

EXPOSE 3000

CMD ["npm", "start"]
```

Build and run:
```bash
docker build -t schumann-api .
docker run -p 3000:3000 schumann-api
```

## Security Considerations

- Use HTTPS in production
- Implement rate limiting
- Add authentication if needed
- Secure the manual update endpoint

## Troubleshooting

### Python Script Issues
- Ensure Chrome and ChromeDriver are installed on the server
- Check that the server has internet access
- Verify Python dependencies are installed

### API Issues
- Check server logs for errors
- Verify the API endpoint is accessible
- Test the API directly with a tool like Postman or curl

## Maintenance

The server automatically updates data every 10 minutes, but you should:
- Monitor server logs
- Ensure the server has sufficient resources
- Update dependencies periodically
- Monitor the API availability