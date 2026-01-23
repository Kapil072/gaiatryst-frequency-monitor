"""
GAIATRYST SYNOPSIS - Backend API Server
Serves Schumann Resonance data from CSV via REST API
"""

import time
import json
from datetime import datetime
from flask import Flask, jsonify
from flask_cors import CORS
import os
import csv
import threading
from pathlib import Path

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter web/mobile

# Global data cache using a mutable object to avoid global declaration issues
data_cache = {
    "timestamp": None,
    "global_avg": 0,
    "stations": {},
    "last_update": None
}

ALL_GCI_STATIONS = ["GCI001", "GCI002", "GCI003", "GCI004", "GCI005", "GCI006"]
UPDATE_INTERVAL = 720  # 12 minutes (for demo purposes, actual data refreshes twice daily)

def read_csv_data():
    """Read data from existing CSV file"""
    # Get the project root directory (two levels up from api/)
    script_dir = Path(__file__).resolve().parent
    project_root = script_dir.parent
    
    # Define the CSV file path
    csv_path = project_root / 'gci_hourly_log_clean.csv'
    
    if csv_path.exists():
        try:
            with open(csv_path, 'r') as file:
                lines = file.readlines()
                if len(lines) < 2:
                    print(f"No data in CSV file: {csv_path}")
                    return None
                
                # Get the last data row
                last_line = lines[-1].strip()
                if not last_line or last_line.startswith('Timestamp'):
                    print(f"Last line is header or empty in CSV: {csv_path}")
                    return None
                    
                parts = last_line.split(',')
                if len(parts) < 8:  # Need at least timestamp, avg, and 6 stations
                    print(f"Not enough columns in CSV row: {len(parts)}")
                    return None
                
                # Parse the data
                timestamp = parts[0].strip('"\'')
                global_avg = float(parts[1])
                
                stations = {}
                for i, station in enumerate(ALL_GCI_STATIONS):
                    if i + 2 < len(parts):
                        try:
                            stations[station] = float(parts[i + 2])
                        except ValueError:
                            stations[station] = 0
                
                return {
                    "timestamp": timestamp,
                    "global_avg": global_avg,
                    "stations": stations,
                    "last_update": timestamp
                }
        except Exception as e:
            print(f"Error reading CSV {csv_path}: {e}")
            return None
    else:
        print(f"CSV file does not exist: {csv_path}")
        return None

def update_data_periodically():
    """Background thread that updates data every 5 minutes"""
    # Initialize on first run
    csv_data = read_csv_data()
    if csv_data:
        data_cache.update(csv_data)
        print(f"✅ Initial data loaded from CSV: {data_cache['global_avg']} Hz")
    
    while True:
        try:
            csv_data = read_csv_data()
            if csv_data:
                data_cache.update(csv_data)
                print(f"✅ Data updated from CSV: {data_cache['global_avg']} Hz")
            else:
                print("⚠️ Could not read data from CSV")
        except Exception as e:
            print(f"❌ Error in update loop: {e}")
        
        time.sleep(UPDATE_INTERVAL)

@app.route('/api/data', methods=['GET'])
def get_data():
    """API endpoint to get current data"""
    if data_cache["timestamp"] is None:
        # Try to initialize with CSV data if not already loaded
        csv_data = read_csv_data()
        if csv_data:
            data_cache.update(csv_data)
            print(f"Initialized from CSV: {data_cache['global_avg']} Hz")
        
    if data_cache["timestamp"] is None:
        return jsonify({"error": "Data not available yet, please try again in a moment"}), 503
    
    return jsonify(data_cache.copy())

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "last_update": data_cache.get("last_update", "Never"),
        "update_interval": f"{UPDATE_INTERVAL} seconds"
    })

@app.route('/', methods=['GET'])
def index():
    """Root endpoint with API documentation"""
    return jsonify({
        "name": "GAIATRYST SYNOPSIS API",
        "version": "1.0",
        "endpoints": {
            "/api/data": "Get current Schumann Resonance data",
            "/api/health": "Check API health status"
        },
        "update_interval": f"{UPDATE_INTERVAL} seconds (1 minute)"
    })

if __name__ == '__main__':
    print("=" * 60)
    print("🌍 GAIATRYST SYNOPSIS API Server Starting...")
    print("=" * 60)
    
    # Start background data updater
    updater_thread = threading.Thread(target=update_data_periodically, daemon=True)
    updater_thread.start()
    
    # Initial data fetch
    print("Loading initial data from CSV...")
    csv_data = read_csv_data()
    if csv_data:
        data_cache.update(csv_data)
        print(f"✅ Initial data loaded from CSV: {data_cache['global_avg']} Hz")
    else:
        print("⚠️ Could not load initial data from CSV")
    
    print("\n🚀 API Server running on http://localhost:5002")
    print("📡 Endpoints:")
    print("   - GET http://localhost:5002/api/data")
    print("   - GET http://localhost:5002/api/health")
    print("\n🔄 Auto-refreshing every 1 minute\n")
    
    # Run Flask server on port 5001 instead of 5000
    app.run(host='0.0.0.0', port=5002, debug=False)
