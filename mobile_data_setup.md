# Mobile Data Setup Instructions

## Running the App with Live Data Updates

To run the Flutter app with live data updates every 1 minute:

### Prerequisites:
- Make sure you have Node.js installed
- Make sure you have Python with Selenium installed (`pip install selenium webdriver-manager`)
- Make sure you have Flutter installed

### Steps:

1. **Start the data server**:
   ```bash
   cd server
   npm install
   npm start
   ```
   The server will run on `http://localhost:3000`

2. **Connect mobile device to the same network** (if using real device):
   - Find your computer's IP address
   - Update the server URL in `lib/main.dart` from `'http://10.0.2.2:3000/api/data'` to `'http://YOUR_COMPUTER_IP:3000/api/data'`

3. **Run the Flutter app**:
   ```bash
   flutter run
   ```

### How it Works:
- When the app starts, it immediately updates the CSV data
- The app then refreshes the data every 1 minute
- On mobile devices, the app connects to the server API to fetch updated data
- On desktop platforms, the app runs the Python script directly to update data

### Troubleshooting:
- If using Android emulator, make sure to use `http://10.0.2.2:3000/api/data` as the server URL
- If using iOS simulator, use `http://localhost:3000/api/data` as the server URL
- If using a real device, make sure the device is on the same network as the server and use your computer's IP address
- Make sure the firewall allows connections on port 3000