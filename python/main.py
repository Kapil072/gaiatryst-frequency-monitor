import time
import csv
import os
import datetime
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager

# --- CONFIGURATION ---
TARGET_URL = "https://nocc.heartmath.org/power_levels/public/charts/power_levels.html"
CSV_FILE = "gci_hourly_log_clean.csv"
CHECK_INTERVAL = 3600  # 1 Hour

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

    current_time = datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    row_data = {"Timestamp (UTC)": current_time}
    
    site_values = []
    
    # --- FILTERING LOGIC ---
    for series in raw_data:
        site_name = series.get('name', 'Unknown')
        
        # 🛑 STRICT FILTER: Only accept sites starting with "GCI"
        # This removes "All", "Average", or any other extra lines
        if not site_name.startswith("GCI"):
            continue

        points = series.get('data', [])
        
        if points:
            # Grab the LAST point (Latest)
            last_point = points[-1]
            power_val = last_point[1]
            
            site_values.append(power_val)
            row_data[site_name] = power_val
    
    if not site_values:
        print("⚠️ Data found but empty.")
        return

    # Calculate Global Average (Using only the filtered sites)
    global_avg = sum(site_values) / len(site_values)
    row_data["Global Avg Power"] = round(global_avg, 2)
    
    print(f"✅ Success! Captured {len(site_values)} sites (Filtered).")
    print(f"   Global Avg: {global_avg:.2f}")

    # Save to CSV
    file_exists = os.path.isfile(CSV_FILE)
    
    # Define column order: Timestamp -> Avg -> GCI001 -> GCI002 ...
    fieldnames = ["Timestamp (UTC)", "Global Avg Power"] + sorted([k for k in row_data.keys() if k.startswith("GCI")])
    
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