"""
Test script to verify HeartMath data scraping works
"""

from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
import time
import json

def test_scraping():
    print("Testing HeartMath data scraping...")
    
    chrome_options = Options()
    chrome_options.add_argument("--headless")
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    
    try:
        driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
        print("Browser launched successfully")
        
        target_url = "https://nocc.heartmath.org/power_levels/public/charts/power_levels.html"
        print(f"Navigating to: {target_url}")
        
        driver.get(target_url)
        print("Page loaded, waiting for chart...")
        
        # Wait longer for chart to load
        time.sleep(20)
        
        # Test if Highcharts is available
        chart_check = driver.execute_script("""
        if (typeof Highcharts !== 'undefined') {
            return {
                'exists': true,
                'chartCount': Highcharts.charts.length,
                'seriesCount': Highcharts.charts.length > 0 ? Highcharts.charts[0].series.length : 0
            };
        } else {
            return {'exists': false};
        }
        """)
        
        print(f"Chart check result: {chart_check}")
        
        if chart_check['exists'] and chart_check['chartCount'] > 0:
            # Try to extract the data
            raw_data = driver.execute_script("""
            if (typeof Highcharts !== 'undefined' && Highcharts.charts.length > 0) {
                return Highcharts.charts[0].series.map(s => ({
                    name: s.name, 
                    data: s.options.data
                }));
            } else {
                return null;
            }
            """)
            
            print(f"Raw data extraction result: {raw_data}")
            
            if raw_data:
                print("SUCCESS: Data extracted!")
                for series in raw_data:
                    print(f"  Series: {series['name']}, Points: {len(series['data']) if series['data'] else 0}")
                    
                    # Print last point if available
                    if series['data'] and len(series['data']) > 0:
                        last_point = series['data'][-1]
                        print(f"    Last point: {last_point}")
            else:
                print("FAILED: No data extracted")
        else:
            print("FAILED: Chart not found")
        
        driver.quit()
        
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_scraping()
