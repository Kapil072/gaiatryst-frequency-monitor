name: Update Spectrogram Data v2

on:
  schedule:
    - cron: '0 */6 * * *'
  workflow_dispatch:

permissions:
  contents: write

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
          pip install playwright numpy opencv-python-headless
          python -m playwright install chromium

      - name: Run the Spectrogram Scraper & Analyzer
        run: |
          set -e
          # Run from REPO ROOT so data.json saves to root
          cd $GITHUB_WORKSPACE
          python api/test_scraping.py
          echo "✅ Script finished"

      - name: Debug - Show all files created
        run: |
          echo "=== Repo root files ==="
          ls -la $GITHUB_WORKSPACE/
          echo ""
          echo "=== api/ folder files ==="
          ls -la $GITHUB_WORKSPACE/api/ || echo "api/ not found"
          echo ""
          echo "=== data.json in root? ==="
          cat $GITHUB_WORKSPACE/data.json || echo "❌ NOT FOUND in root"
          echo ""
          echo "=== data.json in api/? ==="
          cat $GITHUB_WORKSPACE/api/data.json || echo "❌ NOT FOUND in api/"

      - name: Move data.json to repo root if saved in wrong place
        run: |
          # If script saved it in api/ folder, move it to root
          if [ -f "$GITHUB_WORKSPACE/api/data.json" ] && [ ! -f "$GITHUB_WORKSPACE/data.json" ]; then
            echo "⚠️ data.json found in api/ — moving to repo root"
            cp $GITHUB_WORKSPACE/api/data.json $GITHUB_WORKSPACE/data.json
          fi

          # Final check - must exist in root now
          if [ ! -f "$GITHUB_WORKSPACE/data.json" ]; then
            echo "❌ FATAL: data.json not found anywhere!"
            exit 1
          fi

          echo "✅ data.json confirmed at repo root"
          echo "Content:"
          cat $GITHUB_WORKSPACE/data.json

      - name: Commit and Push data.json
        run: |
          cd $GITHUB_WORKSPACE

          git config --global user.name "github-actions[bot]"
          git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"

          # Stage data.json from root
          git add data.json

          # Clean up spectrogram folders
          rm -rf spectrograms_*/
          git add -u  # Stage deleted files

          echo "=== Git status before commit ==="
          git status

          git diff --cached --stat

          # Commit only if there are actual changes
          if git diff --cached --quiet; then
            echo "⚠️ No changes to commit — data.json is identical to last run"
          else
            git commit -m "Auto-update Schumann resonance data [skip ci]"
            git push
            echo "✅ Pushed successfully"
          fi
