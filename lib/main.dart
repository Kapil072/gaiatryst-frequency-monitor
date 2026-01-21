import 'dart:math' as math;
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cube/flutter_cube.dart';
import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io' show Platform;

// Import process_run only on platforms that support it
import 'package:process_run/shell.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GAIATRYST SYNOPSIS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Colors.blue,
          secondary: Colors.cyan,
        ),
      ),
      home: const EarthViewPage(),
    );
  }
}

class EarthViewPage extends StatefulWidget {
  const EarthViewPage({super.key});

  @override
  State<EarthViewPage> createState() => _EarthViewPageState();
}

class _EarthViewPageState extends State<EarthViewPage>
    with TickerProviderStateMixin {
  Object? _earthParent;
  final List<Object> _locationDots = [];

  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _starsController;

  double _rotationY = 0.0;
  Timer? _rotationTimer;

  double? _averageFrequency;
  Map<String, double> _countryFrequencies = {};
  Timer? _refreshTimer;

  // Only cache the Earth texture
  ui.Image? _cachedEarthImage;

  final Map<String, String> _countryNames = {
    'GCI001': 'USA',
    'GCI002': 'Saudi Arabia',
    'GCI003': 'Lithuania',
    'GCI004': 'Canada',
    'GCI005': 'New Zealand',
    'GCI006': 'South Africa',
  };

  final List<Map<String, dynamic>> _locations = [
    {'name': 'California, USA', 'lat': 15.7783, 'lon': -150.4179},
    {'name': 'Hofuf, Saudi Arabia', 'lat': 43.8813, 'lon': 80.1694},
    {'name': 'Lithuania', 'lat': -38.58, 'lon': -35.5613},
    {'name': 'Alberta, Canada', 'lat': 10.9333, 'lon': -140.5765},
    {'name': 'Northland, New Zealand', 'lat': -30.5795, 'lon': -76.7624},
    {'name': 'Hluhluwe, South Africa', 'lat': -50.0186, 'lon': 32.2813},
  ];

  @override
  void initState() {
    super.initState();

    _ensureCsvFileExists();

    double time = 0;
    _rotationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) return;
      setState(() {
        time += 0.15;

        // 1. Rotate Earth
        if (_earthParent != null) {
          _rotationY += 0.3;
          if (_rotationY >= 360) _rotationY = 0;
          _earthParent!.rotation.y = _rotationY;
          _earthParent!.updateTransform();
        }

        // 2. Pulse Dots (Yellow Blink)
        final double breathPhase = math.cos(time * 1.0472);
        final double pulseSize = 0.025 + (0.015 * breathPhase);

        // Calculate Yellow Intensity (Blinking Effect)
        // RGB: Yellow is (1, 1, 0). We scale the 1s.
        final double brightness =
            0.5 + (0.5 * (breathPhase + 1.0) / 2.0); // Wider range: 0.5 to 1.0
        final Vector3 yellowColor = Vector3(brightness, brightness, 0.0);

        for (var dot in _locationDots) {
          // Update Size
          dot.scale.setValues(pulseSize, pulseSize, pulseSize);

          // Update Color
          _updateDotColorRecursively(dot, yellowColor);

          dot.updateTransform();
        }

        if (_currentScene != null) {
          _currentScene!.update();
        }
      });
    });

    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _starsController.addListener(() {
      setState(() {});
    });

    // First update the CSV data on app start
    _updateCsvOnStart();

    // Then refresh data every 1 minute
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      debugPrint('Refreshing frequency data...');

      // On desktop, try to run Python script to get fresh data
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        _runPythonScript();
      } else {
        // On mobile, fetch from web service
        _fetchMobileData();
      }

      // Always reload the data after attempting update
      _loadFrequencyData();
    });
  }

  Future<void> _ensureCsvFileExists() async {
    try {
      final documentDir = await getApplicationDocumentsDirectory();
      final csvFile = File('${documentDir.path}/gci_hourly_log_clean.csv');

      // If the file doesn't exist in documents, copy it from assets
      if (!await csvFile.exists()) {
        final assetData =
            await rootBundle.loadString('assets/gci_hourly_log_clean.csv');
        await csvFile.writeAsString(assetData);
        debugPrint('CSV file copied to documents directory');
      }
    } catch (e) {
      debugPrint('Error ensuring CSV file exists: $e');
    }
  }

  Future<void> _updateCsvOnStart() async {
    debugPrint('Updating CSV data on app start...');

    // Load initial data first
    await _loadFrequencyData();

    // On desktop platforms, try to update data by running Python script
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await _runPythonScript();
    } else {
      // On mobile platforms, fetch data from web service
      await _fetchMobileData();
    }
  }

  Future<void> _runPythonScript() async {
    try {
      debugPrint('Running Python script to update data...');

      // Use Process.run to execute the Python script
      final processResult = await Process.run(
        'python',
        ['python/main.py'],
        workingDirectory: Directory.current.path,
      );

      if (processResult.exitCode == 0) {
        debugPrint('Python script executed successfully');

        // Copy the generated CSV from project root to assets and documents
        final rootCsv = File('gci_hourly_log_clean.csv');
        final documentDir = await getApplicationDocumentsDirectory();
        final docCsv = File('${documentDir.path}/gci_hourly_log_clean.csv');

        if (await rootCsv.exists()) {
          await rootCsv.copy('assets/gci_hourly_log_clean.csv');
          await rootCsv.copy(docCsv.path);
          debugPrint('CSV file updated in assets and documents');

          // Reload the data after updating
          await _loadFrequencyData();
        }
      } else {
        debugPrint('Python script failed: ${processResult.stderr}');
      }
    } catch (e) {
      debugPrint('Error running Python script: $e');
    }
  }

  Future<void> _fetchMobileData() async {
    try {
      debugPrint('Fetching data for mobile platform...');

      final documentDir = await getApplicationDocumentsDirectory();
      final csvFile = File('${documentDir.path}/gci_hourly_log_clean.csv');

      // Try to fetch from web API (replace with your actual server URL)
      try {
        // Example server URL - replace with your deployed server
        // For now, using a placeholder - you'll need to deploy the server
        final apiUrl =
            'http://10.0.2.2:3000/api/data'; // Server API endpoint for Android emulator
        // For iOS simulator, use: 'http://localhost:3000/api/data'
        // For real device, use your computer's IP address: 'http://YOUR_COMPUTER_IP:3000/api/data'

        final response = await http.get(Uri.parse(apiUrl));

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          if (jsonData['success'] && jsonData['data']) {
            // Convert the received data to CSV format
            final csvContent = _convertJsonToCsv(jsonData['data']);
            await csvFile.writeAsString(csvContent);
            debugPrint('Mobile data updated from web service');
            await _loadFrequencyData();
            return;
          }
        } else {
          debugPrint(
              'Failed to fetch data from server: ${response.statusCode}');
        }
      } catch (webError) {
        debugPrint('Web service fetch failed: $webError');
      }

      // If web service fails, try to update from assets
      try {
        final assetData =
            await rootBundle.loadString('assets/gci_hourly_log_clean.csv');
        await csvFile.writeAsString(assetData);
        debugPrint('Mobile data updated from assets (fallback)');
      } catch (assetError) {
        debugPrint('Asset fallback also failed: $assetError');
      }

      await _loadFrequencyData();
    } catch (e) {
      debugPrint('Error fetching mobile data: $e');

      // Final fallback - try to load from assets even in error case
      try {
        final documentDir = await getApplicationDocumentsDirectory();
        final csvFile = File('${documentDir.path}/gci_hourly_log_clean.csv');
        final assetData =
            await rootBundle.loadString('assets/gci_hourly_log_clean.csv');
        await csvFile.writeAsString(assetData);
        await _loadFrequencyData();
      } catch (finalError) {
        debugPrint('Final fallback failed: $finalError');
      }
    }
  }

  // Helper function to convert JSON data to CSV format
  String _convertJsonToCsv(Map<String, dynamic> jsonData) {
    // This is a simplified conversion - in practice you'd format according to your CSV structure
    final keys = jsonData.keys.toList();
    String csv = keys.join(',') + '\n';

    // Assuming the values are in the same order as keys
    final values = keys.map((key) => jsonData[key].toString()).toList();
    csv += values.join(',');

    return csv;
  }

  // --- UPDATE DOT COLOR ---
  void _updateDotColorRecursively(Object dot, Vector3 color) {
    // Set Diffuse to the yellow color
    dot.mesh.material.diffuse = color;
    // Set Ambient to make it glow slightly
    dot.mesh.material.ambient = Vector3(color.x * 0.5, color.y * 0.5, 0.0);

    for (var child in dot.children) {
      _updateDotColorRecursively(child, color);
    }
  }

  // --- LOAD EARTH TEXTURE (With Safety Check) ---
  Future<void> _applyEarthTexture(Object earth) async {
    try {
      if (_cachedEarthImage == null) {
        final data = await rootBundle.load('assets/8k_earth_daymap.jpg');
        final bytes = data.buffer.asUint8List();
        _cachedEarthImage = await decodeImageFromList(bytes);
      }
      final image = _cachedEarthImage!;

      void applyToHierarchy(Object node) {
        // !!! IMPORTANT FIX !!!
        // Check the name. If it is 'Dot', DO NOT apply the Earth texture.
        if (node.name == 'Dot') return;

        if (node.mesh.vertices.isNotEmpty) {
          node.mesh.texture = image;
          node.mesh.textureRect = Rect.fromLTWH(
              0, 0, image.width.toDouble(), image.height.toDouble());
        }

        for (var child in node.children) {
          applyToHierarchy(child);
        }
      }

      applyToHierarchy(earth);
      earth.scene?.updateTexture();
    } catch (e) {
      debugPrint('Failed to apply custom texture: $e');
    }
  }

  Future<void> _loadFrequencyData() async {
    try {
      debugPrint('Reading live data from CSV...');

      // Read from the documents directory first (for updated data), fallback to assets
      String csvContent;

      try {
        // First, try to load from documents directory (for updated data)
        final documentDir = await getApplicationDocumentsDirectory();
        final csvFile = File('${documentDir.path}/gci_hourly_log_clean.csv');

        if (await csvFile.exists()) {
          csvContent = await csvFile.readAsString();
          debugPrint('Loaded CSV from documents directory');
        } else {
          // Fallback to assets if no updated file exists
          csvContent =
              await rootBundle.loadString('assets/gci_hourly_log_clean.csv');
          debugPrint('Loaded CSV from assets');

          // Also save to documents directory for future use
          await csvFile.writeAsString(csvContent);
        }
      } catch (error) {
        debugPrint('Error loading CSV: $error');
        return;
      }

      final rows = const CsvToListConverter().convert(csvContent);

      if (rows.length < 2) return;

      final headerRow = rows[0];
      final avgPowerIndex = headerRow.indexOf('Global Avg Power');

      if (avgPowerIndex == -1) return;

      // Get the most recent (last) row of data
      final lastRow = rows[rows.length - 1];
      final avgPower = lastRow[avgPowerIndex];

      final newFrequency = (avgPower is num)
          ? avgPower.toDouble()
          : double.tryParse(avgPower.toString());

      final newCountryFreqs = <String, double>{};

      for (final station in _countryNames.keys) {
        final stationIndex = headerRow.indexOf(station);
        if (stationIndex != -1 && stationIndex < lastRow.length) {
          final value = lastRow[stationIndex];
          final freq = (value is num)
              ? value.toDouble()
              : double.tryParse(value.toString());
          newCountryFreqs[station] = freq ?? 0.0;
        }
      }

      if (newFrequency != null) {
        setState(() {
          _averageFrequency = newFrequency;
          _countryFrequencies = newCountryFreqs;
        });
        debugPrint('Updated frequency data: ${_averageFrequency} Hz');

        // Print details for each station to match Python script behavior
        for (final entry in newCountryFreqs.entries) {
          final value = entry.value;
          final status =
              value > 0 ? '${value.toStringAsFixed(1)} Hz' : 'Offline';
          debugPrint('${entry.key}: $status');
        }
      }
    } catch (e) {
      debugPrint('Error loading frequency data: $e');
    }
  }

  Scene? _currentScene;

  void _handleSceneCreated(Scene scene) {
    _currentScene = scene;
    scene.camera.position.z = 5;

    // Light is needed for Earth, but we will make dots "glow" via Ambient settings
    scene.light
      ..position.setValues(5, 5, 5)
      ..setColor(const Color.fromARGB(255, 255, 255, 255), 1.0, 1.0, 1.0);

    try {
      // 1. Create Earth
      final earthObject = Object(
        name: 'Earth',
        fileName: 'assets/13902_Earth_v1_l3.obj',
        scale: Vector3(3.0, 3.0, 3.0),
        rotation: Vector3(-90.0, 0, 0),
        lighting: true,
        backfaceCulling: true,
      );

      // Apply Earth Texture to Earth object first
      _applyEarthTexture(earthObject);

      // 2. Create Container and add Earth
      final container = Object(name: 'container');
      container.add(earthObject);

      // 3. Add YELLOW Dots separately (NOT as children of earth)
      _locationDots.clear();

      for (var loc in _locations) {
        final lat = loc['lat'] as double;
        final lon = loc['lon'] as double;
        final pos = _latLonToVector3(lat, lon);

        // Create Dot Object
        final dot = Object(
          name: 'Dot',
          fileName: 'assets/13902_Earth_v1_l3.obj',
          position: pos,
          scale: Vector3(0.08, 0.08, 0.08), // Larger for better visibility
          lighting: true, // Enable lighting to mix diffuse/ambient colors
        );

        // Set Initial Bright Yellow Color (R=1, G=1, B=0)
        dot.mesh.material.diffuse = Vector3(1.0, 1.0, 0.0); // Pure yellow
        dot.mesh.material.ambient =
            Vector3(0.8, 0.8, 0.0); // Bright ambient for visibility
        dot.mesh.material.specular = Vector3(1.0, 1.0, 0.8); // Shiny highlight
        dot.mesh.material.shininess = 80.0; // Moderate shininess

        // Ensure no texture is applied
        dot.mesh.texture = null;

        _locationDots.add(dot);
        container.add(dot); // Add dot directly to container, NOT to earth
      }

      scene.world.add(container);

      setState(() {
        _earthParent = container;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Error loading OBJ model: $error');
      _createSphereFallback(scene);
    }
  }

  Vector3 _latLonToVector3(double lat, double lon) {
    const double radius =
        0.52; // Slightly larger radius to place dots outside Earth surface
    final double phi = (90 - lat) * (math.pi / 180);
    final double theta = (lon + 180) * (math.pi / 180);
    final double x = -(radius * math.sin(phi) * math.cos(theta));
    final double z = radius * math.sin(phi) * math.sin(theta);
    final double y = radius * math.cos(phi);
    return Vector3(x, y, z);
  }

  void _createSphereFallback(Scene scene) {
    try {
      final sphereObj = Object(
        name: 'Earth',
        fileName: 'assets/13902_Earth_v1_l3.obj',
        scale: Vector3(3.0, 3.0, 3.0),
        lighting: true,
      );

      final container = Object(name: 'container');
      container.add(sphereObj);
      scene.world.add(container);

      _applyEarthTexture(sphereObj);

      setState(() {
        _earthParent = container;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to load: $error';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _starsController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _starsController,
            builder: (context, child) {
              return CustomPaint(
                painter: StarryBackgroundPainter(),
                size: MediaQuery.of(context).size,
              );
            },
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(top: 64.0),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Cube(
                                key: const ValueKey('earth_cube'),
                                onSceneCreated: _handleSceneCreated,
                                interactive: false,
                              ),
                              if (_isLoading)
                                Container(
                                  color: Colors.black.withOpacity(0.5),
                                  padding: const EdgeInsets.all(16),
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              if (!_isLoading && _errorMessage != null)
                                Container(
                                  color: Colors.black.withOpacity(0.6),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.orange,
                                        size: 48,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_averageFrequency != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Global Average',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_averageFrequency!.toStringAsFixed(2)} Hz',
                                style: const TextStyle(
                                  color: Colors.cyan,
                                  fontSize: 56,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Live',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_averageFrequency != null) const SizedBox(height: 15),
                      if (_countryFrequencies.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Monitoring Stations',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                alignment: WrapAlignment.center,
                                children: _countryNames.entries.map((entry) {
                                  final station = entry.key;
                                  final countryName = entry.value;
                                  final frequency =
                                      _countryFrequencies[station];
                                  final isActive =
                                      frequency != null && frequency > 0;

                                  return Container(
                                    width: 85,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? Colors.blue.withOpacity(0.15)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isActive
                                            ? Colors.blue.withOpacity(0.4)
                                            : Colors.grey.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 6,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          countryName,
                                          style: TextStyle(
                                            color: isActive
                                                ? Colors.white
                                                : Colors.grey,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          isActive
                                              ? '${frequency.toStringAsFixed(1)} Hz'
                                              : 'Offline',
                                          style: TextStyle(
                                            color: isActive
                                                ? Colors.cyanAccent
                                                : Colors.grey.shade600,
                                            fontSize: isActive ? 12 : 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      if (_countryFrequencies.isNotEmpty)
                        const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            color: Colors.black.withOpacity(0.7),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'GAIATRYST SYNOPSIS',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Consecutively syncing groups & couples breathing, heart beats, brain waves & Schumann planetary resonance is humanity\'s high road back to religiosity\'s origins and existential reenchantment.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Gaiatrysts are a sequential psychobiological path to evoke transpersonal solidarity, collective consciousness and revelatory epiphanies with the simple practices above.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Why this App',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    'assets/why this app.png',
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: () async {
                                    final uri = Uri.parse(
                                        'https://medium.com/@neurokinetikz/quantitative-model-of-schumann-resonant-brain-dynamics-96c130468981');
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  child: const Text(
                                    'Schumann-Resonant Brain Dynamics',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 14,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.blue,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Schumann-Resonant Brain Dynamics',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'This simple Schumann Resonance monitor is primarily an objective real time reminder that our Earth Mother\'s biosphere continuously electrifies all our species\' inner being with the same subliminal energy waves. They are ancient, ubiquitous and intriguingly identical with our own brains\' most liminal frequencies at their Alpha & Theta wave border, which are also the vibes we autonomically reach when our breath, pulse and neural rhymes sync with others.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'More about Schumann Vibes',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    'assets/More about Schumann Vibes .jpg',
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'NASA Space Lightning Array',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Like our human brain, Mother Earth enjoys an electro-magnetic peripheral halo. It is powered not by neural firings, but by the ±tens of thousands of lightning bursts discharging every second somewhere around our world. Collectively they generate a field of ±90 km standing waves between Earth\'s surface and the ionosphere that\'s called the Schumann Resonance and hovers around 7.8 Hertz (Hz) or cycles per second.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'This suggestively mirrors the borderline frequencies between our own alpha & theta waves that typically occur during meditation, interpersonal transparency, spiritual healing and improvisational creativity. The Schumann Resonance thus presents a subliminal bridge between those seeking inspiring perceptions of transpersonal and planetary solidarity. This is the target threshold of compassionate collective consciousness and feelings of immanent divinity.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'In churches these sanctified moments are attributed to Christ, in mosques to Allah, in temples to their various mythological spirits. More likely, however, they seem largely due to the conjunctive energies of congregations themselves and not some external saint, spirit or deity.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Mission',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Hastening arrivals at the borders of collective enchantment – breath sync, heart sync, neural sync',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
              child: Align(
                alignment: Alignment.topLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/applogo.png',
                      height: 36,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'GAIATRYST SYNOPSIS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StarryBackgroundPainter extends CustomPainter {
  final List<Star> _stars = [];

  StarryBackgroundPainter() {
    final random = math.Random(42);
    for (int i = 0; i < 500; i++) {
      _stars.add(
        Star(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: random.nextDouble() * 2 + 0.5,
          baseOpacity: random.nextDouble() * 0.7 + 0.3,
          twinkleSpeed: random.nextDouble() * 5 + 3,
          twinkleOffset: random.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;

    for (var star in _stars) {
      final twinkle =
          (math.sin(time * star.twinkleSpeed + star.twinkleOffset) + 1) / 2;
      final opacity = star.baseOpacity * (0.3 + twinkle * 0.7);

      paint.color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(StarryBackgroundPainter oldDelegate) => true;
}

class Star {
  final double x;
  final double y;
  final double size;
  final double baseOpacity;
  final double twinkleSpeed;
  final double twinkleOffset;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.baseOpacity,
    required this.twinkleSpeed,
    required this.twinkleOffset,
  });
}
