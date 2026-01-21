const express = require('express');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Store the latest data
let latestData = null;
let lastUpdated = null;

// Function to run the Python script
function runPythonScript() {
    return new Promise((resolve, reject) => {
        console.log('Running Python script to fetch latest data...');
        
        const pythonProcess = spawn('python', ['../python/main.py'], {
            cwd: __dirname,
            detached: true,
            stdio: ['pipe', 'pipe', 'pipe']
        });

        let output = '';
        let errorOutput = '';

        pythonProcess.stdout.on('data', (data) => {
            output += data.toString();
        });

        pythonProcess.stderr.on('data', (data) => {
            errorOutput += data.toString();
        });

        pythonProcess.on('close', (code) => {
            if (code === 0) {
                console.log('Python script executed successfully');
                
                // Read the generated CSV file from assets folder
                const csvFilePath = path.join(__dirname, '../assets/gci_hourly_log_clean.csv');
                
                fs.readFile(csvFilePath, 'utf8', (err, data) => {
                    if (err) {
                        console.error('Error reading CSV file:', err);
                        reject(err);
                        return;
                    }
                    
                    // Parse the CSV data
                    const lines = data.trim().split('\n');
                    if (lines.length < 2) {
                        console.error('CSV file is empty or has no data');
                        reject(new Error('No data in CSV file'));
                        return;
                    }
                    
                    const headers = lines[0].split(',');
                    const lastLine = lines[lines.length - 1].split(',');
                    
                    // Create a structured object from the CSV data
                    const dataObject = {};
                    headers.forEach((header, index) => {
                        dataObject[header.trim()] = lastLine[index]?.trim() || null;
                    });
                    
                    latestData = {
                        ...dataObject,
                        timestamp: new Date().toISOString(),
                        rawData: lines // Include raw data if needed
                    };
                    
                    lastUpdated = new Date();
                    console.log('Latest data updated:', latestData);
                    resolve(latestData);
                });
            } else {
                console.error('Python script failed with code:', code);
                console.error('Error output:', errorOutput);
                reject(new Error(`Python script failed: ${errorOutput}`));
            }
        });
    });
}

// Initial run when server starts
async function initializeServer() {
    try {
        await runPythonScript();
        console.log('Server initialized with latest data');
    } catch (error) {
        console.error('Error initializing server:', error.message);
    }
}

// Endpoint to get latest data
app.get('/api/data', (req, res) => {
    if (latestData) {
        res.json({
            success: true,
            data: latestData,
            lastUpdated: lastUpdated,
            timestamp: new Date().toISOString()
        });
    } else {
        res.status(500).json({
            success: false,
            error: 'No data available'
        });
    }
});

// Endpoint to manually trigger data update
app.post('/api/update', async (req, res) => {
    try {
        await runPythonScript();
        res.json({
            success: true,
            message: 'Data updated successfully',
            data: latestData,
            lastUpdated: lastUpdated
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Schedule periodic updates (every 1 minute)
setInterval(async () => {
    try {
        await runPythonScript();
        console.log('Scheduled data update completed');
    } catch (error) {
        console.error('Scheduled data update failed:', error.message);
    }
}, 1 * 60 * 1000); // 1 minute

// Initialize the server
initializeServer();

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`API endpoints:`);
    console.log(`  GET  /api/data  - Get latest data`);
    console.log(`  POST /api/update - Manually trigger update`);
});