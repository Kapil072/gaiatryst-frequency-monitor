# Deploy to GitHub Instructions

## Step 1: Create GitHub Repository

1. Go to https://github.com
2. Click "New repository" (green button)
3. Repository name: `gaiatryst-frequency-monitor`
4. Description: "Real-time Schumann Resonance monitoring with automatic data updates"
5. Make it Public (recommended)
6. **Don't** initialize with README
7. Click "Create repository"

## Step 2: Connect Local Repository to GitHub

Replace `YOUR_USERNAME` with your actual GitHub username in the command below:

```bash
git remote add origin https://github.com/YOUR_USERNAME/gaiatryst-frequency-monitor.git
```

## Step 3: Push to GitHub

```bash
git push -u origin main
```

## Step 4: Enable GitHub Actions

After pushing:
1. Go to your repository on GitHub
2. Click on "Actions" tab
3. You should see the workflow "Auto Frequency Data Update"
4. Click "Enable workflow"
5. The system will now automatically collect data every minute!

## Step 5: Update Flutter App for GitHub Data

In your Flutter app (`lib/main.dart`), update the mobile data fetching to use GitHub raw content:

Find the `_fetchMobileData()` method and update the URL to:
```dart
final githubRawUrl = 'https://raw.githubusercontent.com/YOUR_USERNAME/gaiatryst-frequency-monitor/main/assets/gci_hourly_log_clean.csv';
```

## What Happens Automatically

Once deployed, GitHub Actions will:
- Run every minute to collect new frequency data
- Update the CSV file in your repository
- Commit and push changes automatically
- Your Flutter app will fetch the latest data from GitHub

## Testing

After deployment, you can:
1. Check the Actions tab to see workflow runs
2. View commit history to see data updates
3. Run your Flutter app to verify it gets fresh data

## Troubleshooting

If the workflow fails:
- Check the Actions logs for error details
- Verify Python dependencies are correctly installed
- Ensure the CSV file path is correct