import 'dart:math' as math;
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cube/flutter_cube.dart';
import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

// ============================================================================
// API CONFIGURATION - Change this URL after deploying to cloud
// ============================================================================
// For local development: 'http://localhost:5002/api/data'
// For cloud (Render.com): 'https://your-app-name.onrender.com/api/data'
const String API_URL = 'http://localhost:5002/api/data';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Perfect Earth Globe',
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

  final Map<String, String> _countryNames = {
    'GCI001': 'California, USA',
    'GCI002': 'Hofuf, Saudi Arabia',
    'GCI003': 'Lithuania',
    'GCI004': 'Alberta, Canada',
    'GCI005': 'Northland, New Zealand',
    'GCI006': 'Hluhluwe, South Africa',
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
    _startPythonScraper();

    double time = 0;
    _rotationTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      setState(() {
        time += 0.15; // Blink Speed

        // 1. Rotate Earth
        if (_earthParent != null) {
          _rotationY += 0.2;
          if (_rotationY >= 360) _rotationY = 0;
          _earthParent!.rotation.y = _rotationY;
          _earthParent!.updateTransform();
        }

        // 2. Pulse Dots (Realistic Breathing Effect - ~3 second per breath)
        final double breathPhase =
            math.cos(time * 1.0472); // Pi/3 for 3-second period (3.14159/3)
        final double pulseSize = 0.025 +
            (0.015 * breathPhase); // Varies from 0.01 to 0.04 (0.025 ± 0.015)

        // Brightness pulses in sync with breathing
        final double brightness =
            0.2 + (0.8 * (breathPhase + 1.0) / 2.0); // Range 0.2 to 1.0

        final Vector3 blinkColor = Vector3(
            1.0 * brightness, // Red
            1.0 * brightness, // Green
            1.0 * brightness // Blue
            );

        for (var dot in _locationDots) {
          // --- FIX APPLIED HERE ---
          // Instead of setting the transform matrix directly, we update the scale property.
          // This ensures that when updateTransform() is called, it uses the new size.
          dot.scale.setValues(pulseSize, pulseSize, pulseSize);

          // Update color/material for pulsing effect
          _updateDotMaterial(dot, blinkColor);

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

    _loadFrequencyData();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _loadFrequencyData();
    });
  }

  void _startPythonScraper() async {
    // Only run on desktop platforms (macOS, Windows, Linux)
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) return;

    try {
      // Find Python executable
      String pythonCmd = 'python3';
      try {
        final result = await Process.run('python3', ['--version']);
        if (result.exitCode != 0) pythonCmd = 'python';
      } catch (_) {
        pythonCmd = 'python';
      }

      // Possible paths to scraper
      final possiblePaths = [
        'python/main.py',
        '${Directory.current.path}/python/main.py',
        '../python/main.py',
      ];

      File? scriptFile;
      for (final path in possiblePaths) {
        final file = File(path);
        if (await file.exists()) {
          scriptFile = file;
          break;
        }
      }

      if (scriptFile != null) {
        debugPrint('🚀 Starting Python scraper automatically from: ${scriptFile.path}');
        // Start in detached mode so it persists and doesn't block the app.
        await Process.start(
          pythonCmd,
          [scriptFile.path],
          mode: ProcessStartMode.detached,
          workingDirectory: scriptFile.parent.parent.path, // Set to project root
        );
      } else {
        debugPrint('⚠️ Python scraper not found. Checked: $possiblePaths');
      }
    } catch (e) {
      debugPrint('❌ Error starting Python scraper: $e');
    }
  }

  // --- AGGRESSIVE MATERIAL OVERRIDE HELPER ---
  void _updateDotMaterial(Object dot, Vector3 color) {
    dot.mesh.material.diffuse = color;
    dot.mesh.material.ambient = color;
    dot.mesh.material.specular = Vector3(0.8, 0.8, 0.8);
    dot.mesh.material.shininess = 5.0;

    for (var child in dot.children) {
      _updateDotMaterial(child, color);
    }
  }

  Future<void> _applyDotTexture(Object dot) async {
    try {
      for (int i = 0; i < 60; i++) {
        if (dot.mesh.vertices.isNotEmpty && dot.mesh.texcoords.isNotEmpty) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final data = await rootBundle.load('assets/dot.jpeg');
      final bytes = data.buffer.asUint8List();
      final image = await decodeImageFromList(bytes);
      dot.mesh.texture = image;
      dot.mesh.textureRect =
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

      dot.mesh.material.ambient = Vector3(1.0, 1.0, 1.0);
      dot.mesh.material.diffuse = Vector3(1.0, 1.0, 1.0);
      dot.mesh.material.specular = Vector3(0.8, 0.8, 0.8);
      dot.mesh.material.shininess = 5.0;

      if (_currentScene != null) {
        _currentScene!.updateTexture();
      }
    } catch (e) {
      debugPrint('Failed to apply dot texture: $e');
    }
  }

Future<bool> _fetchDirectWebData() async {
  try {
    debugPrint("Attempting to fetch data directly from HeartMath...");
    
    // Fetch the HeartMath page
    final response = await http.get(
      Uri.parse("https://nocc.heartmath.org/power_levels/public/charts/power_levels.html"),
    ).timeout(const Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final htmlContent = response.body;
      
      // Look for the rawData variable in the JavaScript
      final RegExp regexp = RegExp(r"rawData\s*=\s*(\[.*?\]);", multiLine: true, dotAll: true);
      final Match? match = regexp.firstMatch(htmlContent);
      
      if (match != null) {
        String jsonData = match.group(1)!;
        
        // Clean the JavaScript-style data to make it valid JSON
        jsonData = jsonData.replaceAll(RegExp(r"/\*.*?\*/"), ""); // Remove comments
        jsonData = jsonData.replaceAll(RegExp(r"//.*"), ""); // Remove line comments
        jsonData = jsonData.replaceAllMapped(RegExp(r"\b([a-zA-Z_][a-zA-Z0-9_]*)\s*:"), (match) {
          return '"${match.group(1)}":';
        }); // Quote unquoted keys
        jsonData = jsonData.replaceAll(RegExp(r",\s*}"), "}"); // Remove trailing commas
        jsonData = jsonData.replaceAll(RegExp(r",\s*]"), "]");
        
        final List<dynamic> rawData = json.decode(jsonData);
        
        // Process the data
        final Map<String, double> newCountryFreqs = {};
        double totalValue = 0;
        int activeCount = 0;
        
        for (final series in rawData) {
          final Map<String, dynamic> seriesMap = series as Map<String, dynamic>;
          final String name = seriesMap["name"].toString().toLowerCase().trim();
          final List<dynamic> dataPointsRaw = List.from(seriesMap["data"] ?? []);
          
          if (dataPointsRaw.isNotEmpty) {
            // Convert the nested lists properly
            final List<List<num>> dataPoints = [];
            for (final point in dataPointsRaw) {
              if (point is List) {
                dataPoints.add(List<num>.from(point));
              }
            }
            
            if (dataPoints.isNotEmpty) {
              final double lastValue = dataPoints.last.last.toDouble();
              
              // Map the names to our station IDs
              String? stationId;
              if (name.contains("california") || name.contains("usa")) {
                stationId = "GCI001";
              } else if (name.contains("hofuf") || name.contains("saudi")) {
                stationId = "GCI002";
              } else if (name.contains("lithuania")) {
                stationId = "GCI003";
              } else if (name.contains("canada")) {
                stationId = "GCI004";
              } else if (name.contains("new zealand")) {
                stationId = "GCI005";
              } else if (name.contains("south africa")) {
                stationId = "GCI006";
              }
              
              if (stationId != null && lastValue > 0) {
                newCountryFreqs[stationId] = lastValue;
                totalValue += lastValue;
                activeCount++;
              }
            }
          }
        }
        
        if (newCountryFreqs.isNotEmpty) {
          final double globalAvg = activeCount > 0 ? totalValue / activeCount : 0.0;
          
          setState(() {
            _averageFrequency = globalAvg;
            _countryFrequencies = newCountryFreqs;
          });
          
          debugPrint("✅ Successfully loaded live data: ${globalAvg.toStringAsFixed(2)} Hz from ${newCountryFreqs.length} stations");
          return true; // Indicate success
        }
      }
    }
  } catch (webError) {
    debugPrint("⚠️ Web scraping failed: $webError");
  }
  return false; // Indicate failure
}

  Future<void> _loadFrequencyData() async {
    try {
      // Try Cloud/Local API first (works for all platforms)
      try {
        debugPrint('Fetching data from: $API_URL');
        final response = await http.get(
          Uri.parse(API_URL)
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final newAvg = (data['global_avg'] as num).toDouble();
          final stationsMap = data['stations'] as Map<String, dynamic>;
          
          final Map<String, double> newCountryFreqs = {};
          for (final station in _countryNames.keys) {
            final value = stationsMap[station];
            if (value != null) {
              final freq = (value is num) ? value.toDouble() : double.tryParse(value.toString());
              if (freq != null && freq > 0) {
                newCountryFreqs[station] = freq;
              }
            }
          }
          
          setState(() {
            _averageFrequency = newAvg;
            _countryFrequencies = newCountryFreqs;
          });
          debugPrint('✅ Data loaded from API: $newAvg Hz');
          return;
        }
      } catch (apiError) {
        debugPrint('⚠️ API not available, falling back to CSV: $apiError');
      }

      // Fallback to CSV (for desktop when API is not running)
      final possiblePaths = [
        'gci_hourly_log_clean.csv',
        'python/gci_hourly_log_clean.csv',
        '../gci_hourly_log_clean.csv',
        '${Directory.current.path}/gci_hourly_log_clean.csv',
        '${Directory.current.path}/python/gci_hourly_log_clean.csv',
      ];

      File? csvFile;
      for (final path in possiblePaths) {
        final file = File(path);
        if (await file.exists()) {
          csvFile = file;
          break;
        }
      }

      if (csvFile == null) return;

      final csvContent = await csvFile.readAsString();
      final rows = const CsvToListConverter().convert(csvContent);

      if (rows.length < 2) return;

      final headerRow = rows[0].map((e) => e.toString().trim()).toList();
      final avgPowerIndex = headerRow.indexOf('Global Avg Power');

      if (avgPowerIndex == -1) return;

      // Find the last non-empty row that has data
      var lastRowIndex = rows.length - 1;
      while (lastRowIndex >= 1) {
        final row = rows[lastRowIndex];
        if (row.isNotEmpty && row.any((cell) => cell != null && cell.toString().trim().isNotEmpty)) {
          break;
        }
        lastRowIndex--;
      }
      
      if (lastRowIndex < 1) return;
      final lastRow = rows[lastRowIndex];
      final avgPower = lastRow[avgPowerIndex];

      final newFrequency = (avgPower is num)
          ? avgPower.toDouble()
          : double.tryParse(avgPower.toString());

      final Map<String, double> newCountryFreqs = {};
      for (final station in _countryNames.keys) {
        final stationIndex = headerRow.indexOf(station);
        if (stationIndex != -1 && stationIndex < lastRow.length) {
          final value = lastRow[stationIndex];
          final freq = (value is num)
              ? value.toDouble()
              : double.tryParse(value.toString());
          if (freq != null && freq > 0) {
            newCountryFreqs[station] = freq;
          }
        }
      }

      if (newCountryFreqs.isNotEmpty) {
        final sum = newCountryFreqs.values.reduce((a, b) => a + b);
        final calculatedAvg = sum / newCountryFreqs.length;
        setState(() {
          _averageFrequency = calculatedAvg;
          _countryFrequencies = newCountryFreqs;
        });
      } else if (newFrequency != null) {
        setState(() {
          _averageFrequency = newFrequency;
          _countryFrequencies = newCountryFreqs;
        });
      }
    } catch (e) {
      debugPrint('Error loading frequency data: $e');
    }
  }

  Scene? _currentScene;

  void _handleSceneCreated(Scene scene) {
    _currentScene = scene;
    scene.camera.position.z = 5;
    scene.camera.position.y = 0;
    scene.camera.position.x = 0;

    scene.light
      ..position.setValues(5, 5, 5)
      ..setColor(const Color.fromARGB(255, 255, 255, 255), 0.35, 1.0, 0.6);

    try {
      // 1. Create the Earth Model
      final earthModel = Object(
        fileName: 'assets/13902_Earth_v1_l3.obj',
        scale: Vector3(3.0, 3.0, 3.0),
        rotation: Vector3(-90.0, 0, 0), // Upright Rotation
        lighting: true,
        backfaceCulling: true,
      );

      // 2. Add Location Dots
      _locationDots.clear();

      for (var loc in _locations) {
        final lat = loc['lat'] as double;
        final lon = loc['lon'] as double;

        final pos = _latLonToVector3(lat, lon);

        // Reuse sphere OBJ for the dot
        final dot = Object(
          fileName: 'assets/13902_Earth_v1_l3.obj',
          position: pos,
          // SCALE: Initial scale
          scale: Vector3(0.04, 0.04, 0.04),
          lighting: true,
        );

        // Apply the dot texture
        _applyDotTexture(dot);

        _locationDots.add(dot);
        earthModel.add(dot);
      }

      // 3. Create Parent Container
      final container = Object(name: 'container');
      container.add(earthModel);
      scene.world.add(container);

      setState(() {
        _earthParent = container;
        _isLoading = false;
      });

      _applyCustomTexture(earthModel);
    } catch (error) {
      debugPrint('Error loading OBJ model: $error');
      _createSphereFallback(scene);
    }
  }

  // --- MATH HELPER ---
  Vector3 _latLonToVector3(double lat, double lon) {
    // Radius 0.50 puts it exactly on the skin for your specific model
    const double radius = 0.50;

    final double phi = (90 - lat) * (math.pi / 180);
    final double theta = (lon + 180) * (math.pi / 180);

    final double x = -(radius * math.sin(phi) * math.cos(theta));
    final double z = radius * math.sin(phi) * math.sin(theta);
    final double y = radius * math.cos(phi);

    return Vector3(x, y, z);
  }

  Future<void> _applyCustomTexture(Object target) async {
    for (int i = 0; i < 60; i++) {
      if (target.mesh.vertices.isNotEmpty && target.mesh.texcoords.isNotEmpty) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    try {
      final data = await rootBundle.load('assets/8k_earth_daymap.jpg');
      final bytes = data.buffer.asUint8List();
      final image = await decodeImageFromList(bytes);
      target.mesh.texture = image;
      target.mesh.textureRect =
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      target.scene?.updateTexture();
    } catch (e) {
      debugPrint('Failed to apply custom texture: $e');
    }
  }

  void _createSphereFallback(Scene scene) {
    try {
      final sphereObj = Object(
        fileName: 'assets/13902_Earth_v1_l3.obj',
        scale: Vector3(3.0, 3.0, 3.0),
        lighting: true,
        backfaceCulling: true,
      );

      final container = Object(name: 'container');
      container.add(sphereObj);
      scene.world.add(container);

      _applyCustomTexture(sphereObj);

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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Average Data',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _averageFrequency != null 
                                ? '${_averageFrequency!.toStringAsFixed(2)} Hz'
                                : 'OFFLINE',
                              style: TextStyle(
                                color: _averageFrequency != null ? Colors.cyan : Colors.red,
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _averageFrequency != null ? 'Live' : 'No Connection',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
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
                                    width: 110,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? Colors.blue.withOpacity(0.15)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isActive
                                            ? Colors.blue.withOpacity(0.5)
                                            : Colors.grey.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          station,
                                          style: TextStyle(
                                            color: isActive
                                                ? Colors.blue.shade300
                                                : Colors.grey,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          countryName,
                                          style: TextStyle(
                                            color: isActive
                                                ? Colors.white
                                                : Colors.grey,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            height: 1.1,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isActive
                                              ? '${frequency.toStringAsFixed(1)} Hz'
                                              : 'Offline',
                                          style: TextStyle(
                                            color: isActive
                                                ? Colors.cyanAccent
                                                : Colors.grey.shade600,
                                            fontSize: isActive ? 13 : 10,
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
                                  'Consecutively syncing groups & couples breathing, heart beats, brain waves & Schumann planetary resonance is humanity\'s high road back to religiosity\'s origins and existential re-enchantment.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Gaiatrysts are a sequential psycbibiological path to evoke transpersonal solidarity, collective consciousness and revelatory epiphanies with the simple practices  above.',
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
                                const SizedBox(height: 20),
                                const Text(
                                  'This simple Schumann Resonance monitor is primarily an objective real time reminder that our Earth Mother\'s biosphere continuously electrifies all our species\' inner being with the same subliminal energy waves. They are ancient, ubiquitous and intriguingly identical with our own brains\' most liminal frequencies at their Alpha & Theta wave border, which are also the vibes we autonomically reach when our breath, pulse and neural rhymes sync with others.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    'assets/Picture1.png',
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Like our human brain, Mother Earth enjoys an electro-magnetic peripheral halo. It is powered not by neural firings, but by the ±tens of thousands of lightning bursts flashing every second.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
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
                                  'Brief NASA timelapse of space Lightning on just bottom of this image',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  '''Collectively they generate a field of ±90 km standing waves between Earth's surface and the ionosphere. This harmonized aura is called the Schumann Resonance, which resonates around 7.8 Hertz (Hz) or cycles per second. Tauntingly auspiciously, this is the borderline frequency range between our own Alpha & Theta wave fields which characterize periods of meditation, prayer, spiritual healing, creative absorption, etc.''',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'The Schumann Resonance thus offers a constant subconscious nudge into heightened states of receptivity, compassion and divine-adjacent sensibility. SR sync is thus the target threshold of numinous possibilities.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'When these transcendent moments are felt in churches they are gratefully attributed to Christ or kin, in mosques to Allah, in ashrams to avatars and in temples to their focal sages, saints or tutelary deities.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'These imagined benefactors all differ widely yet their ecstatic blessings curiously seem to feel quite the same. Isn\'t it vastly more likely, these epiphanous awakenings are all really generated by the synced conjunctive psychosomatic energies of the congregations themselves?',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Once this realization dawns and spreads, we may kindle organic singularities ourselves and lay aside the exorbitant prosthetic tech AI lords say is required.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  '===============',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Gaiatryst Productions',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Gaiatrysts are covenworks – eclectic DIY tech to celebrate solidarity, provoke ecosocial epiphanies and re-enchant the stricken world.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Mission: Hasten group & couple arrivals at the liminal borders of entrainment, enlightenment & empowerment.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Strategy: Evoke breath sync, heart sync, neural sync & Schumann sync to collectively evoke and embody exceptional eco-protective powers.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Concept: Big Medicine\'s Saltation team',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Development: Integrative Tech Solutions',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.6,
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
                      'assets/WhatsApp_Image_2025-12-28_at_5.00.39_PM-removebg-preview (1).png',
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
