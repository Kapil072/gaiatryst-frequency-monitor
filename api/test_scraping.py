name: Update Spectrogram Data v2

on:
  schedule:
    - cron: '0 */6 * * *'
  workflow_dispatch:

permissions:
  contents: write

# Prevent two runs at the same time — cancels older run if new one starts
concurrency:
  group: update-spectrogram
  cancel-in-progress: false

jobs:
  scrape-data:
    runs-on: ubuntu-latest

    env:
      FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true

    steps:
      - name: Checkout repository
        uses: actions/checkout@v5

      - name: Set up Python
        uses: actions/setup-python@v6
        with:
          python-version: '3.12'

      - name: Install Python packages and Playwright browser
        run: |
          python -m pip install --upgrade pip
          pip install playwright numpy opencv-python-headless requests
          python -m playwright install chromium

      - name: Run the Spectrogram Scraper & Analyzer
        run: |
          set -e
          cd $GITHUB_WORKSPACE
          python api/test_scraping.py
          echo "✅ Script finished"

      - name: Debug - Show what was produced
        run: |
          echo "=== data.json in root? ==="
          cat $GITHUB_WORKSPACE/data.json || echo "❌ NOT FOUND in root"
          echo ""
          echo "=== data.json in api/? ==="
          cat $GITHUB_WORKSPACE/api/data.json || echo "❌ NOT FOUND in api/"

      - name: Move data.json to repo root if saved in wrong place
        run: |
          if [ -f "$GITHUB_WORKSPACE/api/data.json" ] && [ ! -f "$GITHUB_WORKSPACE/data.json" ]; then
            echo "Moving data.json from api/ to root"
            cp $GITHUB_WORKSPACE/api/data.json $GITHUB_WORKSPACE/data.json
          fi
          if [ ! -f "$GITHUB_WORKSPACE/data.json" ]; then
            echo "❌ FATAL: data.json not found anywhere!"
            exit 1
          fi
          echo "✅ data.json ready"
          cat $GITHUB_WORKSPACE/data.json

      - name: Commit and Push
        run: |
          cd $GITHUB_WORKSPACE

          git config --global user.name "github-actions[bot]"
          git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"

          # Pull latest to avoid push rejection conflict
          git pull --rebase origin main

          git add data.json
          rm -rf spectrograms_*/
          git add -u

          git status

          if git diff --cached --quiet; then
            echo "⚠️ No changes to commit"
          else
            git commit -m "Auto-update Schumann resonance data [skip ci]"
            git push
            echo "✅ Pushed successfully"
          fi
