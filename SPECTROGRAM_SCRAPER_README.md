# Spectrogram Scraper & Analyzer

Automated pipeline for downloading and analyzing Schumann resonance spectrogram images from HeartMath GCI.

## Overview

This workflow automatically:
- 🕷️ Scrapes the latest spectrogram images from HeartMath's website
- 🧠 Analyzes each image using computer vision (OpenCV)
- 📊 Extracts peak Schumann resonance frequencies (7-9 Hz range)
- 💾 Saves results with timestamps and analysis summaries
- 🔄 Runs every 6 hours via GitHub Actions

## File Structure

```
api/
├── test_scraping.py          # Main scraper & analyzer script
└── requirements.txt          # Python dependencies

.github/workflows/
└── update-spectrogram.yml   # GitHub Actions workflow

spectrograms_YYYY_MM_DD/     # Auto-created folders with data
├── site1_image.jpg          # Downloaded spectrogram images
├── site2_image.jpg
└── analysis_summary.csv     # Analysis results
```

## How It Works

### 1. Automated Browser (Playwright)
- Launches headless Chromium browser
- Navigates to HeartMath spectrogram calendar
- Scans for dated JPG image links
- Identifies the latest available date automatically

### 2. Image Download
- Downloads all spectrogram images for the latest date
- Saves to dated folder: `spectrograms_YYYY_MM_DD/`
- Organizes by site name for easy identification

### 3. Computer Vision Analysis (OpenCV)
Each spectrogram image is analyzed to extract the peak frequency:

```python
def analyze_spectrogram(image_path):
    # Convert to grayscale and apply Gaussian blur
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (5, 5), 0)
    
    # Calculate row intensity profile
    row_intensity = np.mean(gray, axis=1)
    
    # Focus on 7-9 Hz frequency range
    height = gray.shape[0]
    FMAX = 50
    low_freq = 7
    high_freq = 9
    
    y_low = int(height * (1 - high_freq / FMAX))
    y_high = int(height * (1 - low_freq / FMAX))
    
    # Find peak intensity in target range
    region = row_intensity[y_low:y_high]
    peak_index = np.argmax(region)
    peak_row = peak_index + y_low
    
    # Convert pixel position to frequency
    frequency = (1 - peak_row / height) * FMAX
    
    return round(frequency, 2)
```

### 4. Results Summary
Creates `analysis_summary.csv` with:
- Site name
- Peak frequency (Hz)
- Date of measurement

## Installation

### Local Testing

```bash
# Install dependencies
pip install playwright numpy opencv-python-headless
python -m playwright install chromium

# Run the scraper
python api/test_scraping.py
```

### GitHub Actions Setup

The workflow is pre-configured in `.github/workflows/update-spectrogram.yml`:

```yaml
name: Update Spectrogram Data

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:        # Manual trigger available

permissions:
  contents: write

jobs:
  scrape-data:
    runs-on: ubuntu-latest
    
    env:
      FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
    
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-python@v6
        with:
          python-version: '3.12'
      
      - name: Install dependencies
        run: |
          pip install playwright numpy opencv-python-headless
          python -m playwright install chromium
      
      - name: Run scraper
        run: python api/test_scraping.py
      
      - name: Commit results
        run: |
          git config --global user.name "github-actions[bot]"
          git add spectrograms_*/
          git commit -m "Auto-update Schumann resonance data [skip ci]" || echo "No changes"
          git push
```

## Usage

### Manual Trigger

1. Go to your GitHub repository
2. Click **Actions** tab
3. Select **"Update Spectrogram Data"** workflow
4. Click **"Run workflow"** button
5. Wait for completion (~2-5 minutes)

### Automatic Execution

The workflow runs automatically every 6 hours (at 00:00, 06:00, 12:00, 18:00 UTC).

## Output Format

### Downloaded Images
Saved as: `spectrograms_YYYY_MM_DD/{site}_{filename}.jpg`

Example:
```
spectrograms_2024_03_18/
├── gci001_spectrogram_2024_03_18.jpg  # California, USA
├── gci002_spectrogram_2024_03_18.jpg  # Hofuf, Saudi Arabia
├── gci003_spectrogram_2024_03_18.jpg  # Lithuania
└── analysis_summary.csv
```

### Analysis Summary CSV

```csv
site,frequency,date
gci001,7.85,2024_03_18
gci002,7.78,2024_03_18
gci003,7.82,2024_03_18
```

## Technical Details

### Frequency Analysis Range
- **FMAX**: 50 Hz (maximum frequency represented in spectrogram)
- **Target Range**: 7-9 Hz (primary Schumann resonance band)
- **Method**: Intensity profile analysis with peak detection

### Dependencies
- **playwright==1.40.0**: Browser automation
- **opencv-python-headless==4.9.0.80**: Computer vision
- **numpy==1.26.3**: Numerical operations

### Error Handling
- Timeout handling for slow-loading pages
- Graceful degradation if no images found
- Silent failure when no new images available
- `[skip ci]` flag prevents recursive workflow triggers

## Troubleshooting

### "Exit Code 2" Error
Usually means file not found. Check:
- Script path in workflow: `python api/test_scraping.py`
- Folder path for commits: `spectrograms_*/`

### Node.js Deprecation Warning
Already silenced with `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true` environment variable.

### No Images Downloaded
- Site might be slow - timeout is set to 10 seconds
- Check HeartMath website availability
- Verify date pattern matching in URLs

### Analysis Returns Error
- Ensure spectrogram images are valid JPG format
- Check image dimensions meet minimum requirements
- Verify frequency range calculations match spectrogram scale

## Data Access

All downloaded data is committed to the repository and available at:
```
https://github.com/Kapil072/gaiatryst-frequency-monitor/tree/main/spectrograms_YYYY_MM_DD/
```

## License

This tool is part of the GAIATRYST SYNOPSIS project for scientific research and educational purposes.

## Credits

- **Data Source**: HeartMath Global Coherence Initiative (https://www.heartmath.org/gci/)
- **Analysis Method**: Computer vision-based spectrogram analysis
- **Automation**: GitHub Actions CI/CD pipeline
