"""
Spectrogram Scraper & Analyzer for HeartMath GCI
Automatically downloads and analyzes Schumann resonance spectrogram images
Saves results to data.json for Flutter app integration
"""

import os
import cv2
import numpy as np
import re
import json
from datetime import datetime, timezone
from playwright.sync_api import sync_playwright


# ==========================================
# 1. THE ANALYZER FUNCTION
# ==========================================
def analyze_spectrogram(image_path):
    """Analyze spectrogram to extract peak Schumann resonance frequency"""
    img = cv2.imread(image_path)

    if img is None:
        return "Error: Could not read image"

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (5, 5), 0)

    height = gray.shape[0]
    FMAX = 50
    row_intensity = np.mean(gray, axis=1)

    low_freq = 7
    high_freq = 9

    y_low = int(height * (1 - high_freq / FMAX))
    y_high = int(height * (1 - low_freq / FMAX))

    if y_low >= y_high or y_low < 0 or y_high > height:
         return "Error: Region out of bounds"

    region = row_intensity[y_low:y_high]
    peak_index = np.argmax(region)
    peak_row = peak_index + y_low
    frequency = (1 - peak_row / height) * FMAX
    
    return round(frequency, 2)


# ==========================================
# 2. THE DYNAMIC SCRAPER & PIPELINE
# ==========================================
def auto_scrape_and_analyze():
    url = "https://www.heartmath.org/gci/gcms/live-data/spectrogram-calendar/"
    
    with sync_playwright() as p:
        print("🚀 Launching automated browser...")
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        print("📡 Navigating to HeartMath Calendar...")
        page.goto(url, wait_until="networkidle", timeout=60000)
        
        try:
            # Wait for ANY .jpg link to appear
            page.locator('a[href*=".jpg"]').first.wait_for(timeout=10000)
        except:
            print("⚠️ Timeout waiting for links to load. The site might be slow today.")

        print("🔍 Scanning the page to determine the latest available date...")
        
        all_image_urls = []
        dates_found = set()
        
        # Regex pattern to find exactly 4 digits, underscore, 2 digits, underscore, 2 digits
        date_pattern = re.compile(r"(\d{4}_\d{2}_\d{2})")
        
        for frame in page.frames:
            links = frame.locator('a').element_handles()
            for link in links:
                full_url = link.get_property("href").json_value()
                
                if full_url and full_url.endswith(".jpg") and "thumb" not in full_url.lower():
                    all_image_urls.append(full_url)
                    
                    # Search the URL for our date pattern
                    match = date_pattern.search(full_url)
                    if match:
                        dates_found.add(match.group(1))

        if not dates_found:
            print("❌ Could not find any dated image links.")
            browser.close()
            return

        # Let Python find the maximum (newest) date automatically
        latest_date = max(dates_found)
        print(f"📅 Latest data available on server is for: {latest_date}")
        
        # Create the folder dynamically based on the latest date
        save_folder = f"spectrograms_{latest_date}"
        if not os.path.exists(save_folder):
            os.makedirs(save_folder)

        # Filter our giant list of URLs to only keep the ones that match our latest_date
        # We use list(set(...)) to remove any accidental duplicate links
        target_urls = list(set([u for u in all_image_urls if latest_date in u]))
        
        print(f"✅ Found {len(target_urls)} images for {latest_date}! Starting pipeline...\n")
        print("-" * 40)
        
        # Results storage
        results = []
        
        for img_url in target_urls:
            filename = img_url.split("/")[-1]
            site = img_url.split("/")[-2] 
            save_path = os.path.join(save_folder, f"{site}_{filename}")
            
            try:
                response = page.request.get(img_url)
                
                if response.ok:
                    with open(save_path, "wb") as f:
                        f.write(response.body())
                    print(f"⬇️ Saved: {site}")
                    
                    # Pass it to the analyzer
                    peak_freq = analyze_spectrogram(save_path)
                    print(f"🧠 Analysis for {site} -> Peak Frequency: {peak_freq} Hz")
                    results.append({
                        'site': site,
                        'frequency': peak_freq,
                        'date': latest_date
                    })
                    print("-" * 40)
                    
                else:
                    print(f"⚠️ Failed to download {filename} (Status: {response.status})")
            except Exception as e:
                print(f"⚠️ Error processing {filename}: {e}")

        # Save summary CSV
        if results:
            csv_path = os.path.join(save_folder, "analysis_summary.csv")
            with open(csv_path, 'w') as f:
                f.write("site,frequency,date\n")
                for r in results:
                    f.write(f"{r['site']},{r['frequency']},{r['date']}\n")
            print(f"📊 Summary saved to: {csv_path}")
            
            # Update data.json for Flutter app integration
            update_data_json(results)

        print("🏁 Pipeline Finished!")
        browser.close()


def update_data_json(results):
    """Update data.json with latest spectrogram analysis results"""
    # Map site names to GCI station IDs
    site_to_gci = {
        'gci001': 'GCI001',
        'gci002': 'GCI002',
        'gci003': 'GCI003',
        'gci004': 'GCI004',
        'gci005': 'GCI005',
        'gci006': 'GCI006'
    }
    
    # Build stations dictionary
    stations = {}
    frequencies = []
    
    for result in results:
        site = result['site'].lower()
        frequency = result['frequency']
        
        # Try to map to GCI ID
        gci_id = site_to_gci.get(site)
        if not gci_id:
            # Use site name as fallback
            gci_id = site.upper().replace('_', '')[:7]
        
        stations[gci_id] = frequency
        if isinstance(frequency, (int, float)) and frequency > 0:
            frequencies.append(frequency)
    
    # Calculate global average
    global_avg = round(sum(frequencies) / len(frequencies), 2) if frequencies else 0.0
    
    # Create data structure
    data = {
        "timestamp": datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC'),
        "global_avg": global_avg,
        "stations": stations,
        "active_stations": len(frequencies),
        "source": "HeartMath Spectrogram Analysis",
        "status": "live" if frequencies else "offline",
        "is_live": True if frequencies else False
    }
    
    # Determine save path (project root)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    json_path = os.path.join(project_root, "data.json")
    
    # Save to JSON
    with open(json_path, 'w') as f:
        json.dump(data, f, indent=2)
    
    print(f"✅ data.json updated: {global_avg} Hz from {len(frequencies)} stations")
    print(f"   Saved to: {json_path}")


if __name__ == "__main__":
    # No date needed! Just run it.
    auto_scrape_and_analyze() 

