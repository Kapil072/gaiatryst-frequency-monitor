import time
import csv
import os
import datetime
import socket
import sys
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager

# --- SINGLETON CHECK: Prevent multiple instances ---
try:
    lock_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    lock_socket.bind(('127.0.0.1', 58214))  # Arbitrary port
except socket.error:
    # Exit silently if already running
    sys.exit(0)

# --- CONFIGURATION ---
TARGET_URL = "https://nocc.heartmath.org/power_levels/public/charts/power_levels.html"
# Save to project root so Flutter can access it easily
CSV_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "gci_hourly_log_clean.csv")
CHECK_INTERVAL = 43200  # 12 Hours (twice daily)
ALL_GCI_STATIONS = ["GCI001", "GCI002", "GCI003", "GCI004", "GCI005", "GCI006"]

def get_live_data():
    """Launches a headless browser to extract Highcharts data."""
    print(f"\n[{datetime.datetime.now().strftime('%H:%M:%S')}] Launching browser...")
    
    chrome_options = Options()
    chrome_options.add_argument("--headless")
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
    
    try:
        driver.get(TARGET_URL)
        time.sleep(10) # Wait for chart to load
        
        # Extract name AND data series
        script = """
        if (typeof Highcharts !== 'undefined' && Highcharts.charts.length > 0) {
            return Highcharts.charts[0].series.map(s => ({
                name: s.name, 
                data: s.options.data
            }));
        } else {
            return null;
        }
        """
        raw_data = driver.execute_script(script)
        return raw_data

    except Exception as e:
        print(f"❌ Browser Error: {e}")
        return None
    finally:
        driver.quit()

def process_and_save(raw_data):
    if not raw_data:
        print("⚠️ No data extracted.")
        return

    current_time = datetime.datetime.now(datetime.UTC).strftime('%Y-%m-%d %H:%M:%S')
    row_data = {"Timestamp (UTC)": current_time}
    
    site_values = []
    
    # --- FILTERING LOGIC ---
    # Pre-fill all stations with 0 to ensure consistent CSV columns
    for station in ALL_GCI_STATIONS:
        row_data[station] = 0

    for series in raw_data:
        site_name = series.get('name', 'Unknown').replace('\n', '').strip()
        
        # 🛑 STRICT FILTER: Only accept sites starting with "GCI"
        # This removes "All", "Average", or any other extra lines
        if not site_name.startswith("GCI") or site_name not in ALL_GCI_STATIONS:
            continue

        points = series.get('data', [])
        
        if points:
            # Grab the LAST point (Latest)
            last_point = points[-1]
            power_val = last_point[1]
            
            # Only add to average calculation if value is greater than 0 (active station)
            if power_val > 0:
                site_values.append(power_val)
            
            # Always save the value to CSV (including 0 for offline stations)
            row_data[site_name] = power_val
    
    if not site_values:
        print("⚠️ Data found but empty.")
        return

    # Calculate Global Average (Using ONLY active stations with value > 0)
    active_count = len(site_values)
    global_avg = sum(site_values) / active_count if active_count > 0 else 0
    row_data["Global Avg Power"] = round(global_avg, 2)
    
    # Sanitize keys to remove any hidden newlines that break CSV
    row_data = {k.replace('\n', '').replace('\r', '').strip(): v for k, v in row_data.items()}
    
    print(f"✅ Success! Captured {active_count} active sites (out of total stations).")
    print(f"   Global Avg: {global_avg:.2f} Hz (from {active_count} active stations)")

    # Save to CSV
    file_exists = os.path.isfile(CSV_FILE)
    
    # Define column order: Timestamp -> Avg -> GCI001 -> GCI002 ...
    fieldnames = ["Timestamp (UTC)", "Global Avg Power"] + ALL_GCI_STATIONS
    
    with open(CSV_FILE, mode='a', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        
        if not file_exists:
            writer.writeheader()
        
        writer.writerow(row_data)
        
    print(f"   Saved to {CSV_FILE}")

# --- MAIN LOOP ---
print("--- GCI CORRECTED BOT STARTED ---")
print(f"Saving to: {os.path.abspath(CSV_FILE)}")
print("Press Ctrl+C to stop.\n")

try:
    while True:
        data = get_live_data()
        process_and_save(data)
        del data
        time.sleep(CHECK_INTERVAL)

except KeyboardInterrupt:
    print("\n🛑 Stopped by user.")