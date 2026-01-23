#!/bin/bash

# GAIATRYST SYNOPSIS Deployment Script

echo "🚀 Deploying GAIATRYST SYNOPSIS Application"

# Install Flutter dependencies
echo "📦 Installing Flutter dependencies..."
flutter pub get

# Install Python dependencies
echo "🐍 Installing Python dependencies..."
cd api
pip install -r requirements.txt
cd ..

# Create necessary directories
mkdir -p logs data

echo "✅ Deployment completed!"
echo ""
echo "To run the application:"
echo "1. Start the API server: cd api && python server.py"
echo "2. In another terminal: flutter run"
echo ""
echo "The data will automatically refresh twice daily (6AM and 6PM UTC)"
