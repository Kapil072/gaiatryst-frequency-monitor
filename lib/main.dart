import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cube/flutter_cube.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

// ============================================================================
// DATA URL - GitHub Raw URL (automatically updated twice daily)
// ============================================================================
// IMPORTANT: Replace YOUR_USERNAME and YOUR_REPO with your actual GitHub details
const String DATA_URL =
    'https://raw.githubusercontent.com/Kapil072/gaiatryst-frequency-monitor/main/data.json';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gaiatryst Schumann Sync Link',
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
  // Separated containers for tilt and spin
  Object? _tiltContainer;
  Object? _spinContainer;

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

    double time = 0;
    int frameCount = 0;
    _rotationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) return;

      frameCount++;
      // Skip every other frame on low-end devices (30 FPS for 3D)
      if (frameCount % 2 == 0) return;

      setState(() {
        time += 0.06; // Slower for smoother low-end performance

        // 1. Rotate Earth on its local axis
        if (_spinContainer != null) {
          _rotationY += 0.25; // Rotation increment
          if (_rotationY >= 360) _rotationY = 0;

          // Apply spin ONLY to the child object.
          // The parent container maintains the fixed -23.5 tilt.
          _spinContainer!.rotation.y = _rotationY;
          _spinContainer!.updateTransform();
        }

        // 2. Pulse Dots - simplified calculation
        final double breathPhase = math.cos(time * 1.0472);
        final double pulseSize = 0.025 + (0.015 * breathPhase);
        final double brightness = 0.2 + (0.8 * (breathPhase + 1.0) / 2.0);

        final Vector3 blinkColor = Vector3(brightness, brightness, brightness);

        for (var dot in _locationDots) {
          dot.scale.setValues(pulseSize, pulseSize, pulseSize);
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
      duration: const Duration(seconds: 300), // Very slow for low-end devices
    )..repeat();

    // Minimal star updates - only 5 times per second
    _starsController.addListener(() {
      if (mounted && (_starsController.value * 100).toInt() % 20 == 0) {
        setState(() {});
      }
    });

    _loadFrequencyData();
    // Refresh data every 5 minutes (data updates twice daily on server)
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _loadFrequencyData();
    });
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

  /// Loads frequency data from the GitHub raw JSON file
  Future<void> _loadFrequencyData() async {
    try {
      debugPrint('🔄 Fetching data from: $DATA_URL');
      final response = await http
          .get(Uri.parse(DATA_URL))
          .timeout(const Duration(seconds: 15));

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📦 Response body length: ${response.body.length} bytes');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ JSON decoded successfully');

        // Check if data is live (not offline/failed fetch)
        final bool isLive = data['is_live'] == true;
        final globalAvg = data['global_avg'];

        debugPrint('🔍 is_live: $isLive, global_avg: $globalAvg');

        // If data is not live or global_avg is null, show OFFLINE
        if (!isLive || globalAvg == null) {
          debugPrint('⚠️ Data not available - showing OFFLINE');
          setState(() {
            _averageFrequency = null; // This will show OFFLINE
            _countryFrequencies = {};
          });
          return;
        }

        final newAvg = (globalAvg as num).toDouble();
        final stationsMap = data['stations'] as Map<String, dynamic>;

        final Map<String, double> newCountryFreqs = {};
        for (final station in _countryNames.keys) {
          final value = stationsMap[station];
          if (value != null) {
            final freq = (value is num)
                ? value.toDouble()
                : double.tryParse(value.toString());
            if (freq != null && freq > 0) {
              newCountryFreqs[station] = freq;
            }
          }
        }

        setState(() {
          _averageFrequency = newAvg;
          _countryFrequencies = newCountryFreqs;
        });
        debugPrint(
            '✅ Data loaded: $newAvg Hz from ${newCountryFreqs.length} stations');
      } else {
        debugPrint('⚠️ Failed to load data: HTTP ${response.statusCode}');
        setState(() {
          _averageFrequency = null; // Show OFFLINE on HTTP error
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading frequency data: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      setState(() {
        _averageFrequency = null; // Show OFFLINE on error
      });
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
      // 1. Create the Earth Model (This is now our Spin Container)
      final earthModel = Object(
        fileName: 'assets/13902_Earth_v1_l3.obj',
        scale: Vector3(3.5, 3.5, 3.5),
        lighting: false, // Disable lighting for better performance
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
          scale: Vector3(0.04, 0.04, 0.04),
          lighting: false,
        );

        // Apply the dot texture
        _applyDotTexture(dot);

        _locationDots.add(dot);

        // Add dots directly to the spinning Earth so they rotate with it
        earthModel.add(dot);
      }

      // 3. Create Parent Container (This is now our Tilt Container)
      final tiltContainer = Object(name: 'tiltContainer');

      // Apply the REAL Earth axial tilt to the parent ONCE
      // Increased for more dramatic rotation effect
      tiltContainer.rotation.x = -45.0; // 45° tilt (increased from 23.5°)

      // Put the spinning Earth inside the tilted container
      tiltContainer.add(earthModel);
      scene.world.add(tiltContainer);

      setState(() {
        _tiltContainer = tiltContainer;
        _spinContainer = earthModel;
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
      final data = await rootBundle.load('assets/IMG_8725.JPG.jpeg');
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

      final tiltContainer = Object(name: 'tiltContainer');
      tiltContainer.rotation.x = -23.5; // Apply static tilt
      tiltContainer.add(sphereObj);
      scene.world.add(tiltContainer);

      _applyCustomTexture(sphereObj);

      setState(() {
        _tiltContainer = tiltContainer;
        _spinContainer = sphereObj; // Spin the sphere
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
          // Static star background - no animation for maximum performance
          CustomPaint(
            painter: StarryBackgroundPainter(),
            size: MediaQuery.of(context).size,
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
                        height: MediaQuery.of(context).size.height * 0.60,
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
                      Transform.translate(
                        offset: const Offset(0, -60),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                _averageFrequency != null
                                    ? '${_averageFrequency!.toStringAsFixed(2)} Hz'
                                    : 'OFFLINE',
                                style: TextStyle(
                                  color: _averageFrequency != null
                                      ? Colors.cyan
                                      : Colors.red,
                                  fontSize: 84,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _averageFrequency != null
                                    ? 'Live'
                                    : 'No Connection',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children: [
                                  // First Row - 3 stations
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: _countryNames.entries
                                        .take(3)
                                        .map((entry) {
                                      final station = entry.key;
                                      final countryName = entry.value;
                                      final frequency =
                                          _countryFrequencies[station];
                                      final isActive =
                                          frequency != null && frequency > 0;

                                      return Container(
                                        width: 115,
                                        height: 70,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? Colors.blue.withOpacity(0.15)
                                              : Colors.grey.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isActive
                                                ? Colors.blue.withOpacity(0.5)
                                                : Colors.grey.withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 6),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              countryName,
                                              style: TextStyle(
                                                color: isActive
                                                    ? Colors.white
                                                    : Colors.grey,
                                                fontSize: 13,
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
                                                fontSize: isActive ? 16 : 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  // Second Row - 3 stations
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: _countryNames.entries
                                        .skip(3)
                                        .map((entry) {
                                      final station = entry.key;
                                      final countryName = entry.value;
                                      final frequency =
                                          _countryFrequencies[station];
                                      final isActive =
                                          frequency != null && frequency > 0;

                                      return Container(
                                        width: 115,
                                        height: 70,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? Colors.blue.withOpacity(0.15)
                                              : Colors.grey.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isActive
                                                ? Colors.blue.withOpacity(0.5)
                                                : Colors.grey.withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 6),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              countryName,
                                              style: TextStyle(
                                                color: isActive
                                                    ? Colors.white
                                                    : Colors.grey,
                                                fontSize: 13,
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
                                                fontSize: isActive ? 16 : 13,
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
                                  'Gaiatryst Schumann Sync Link',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
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
                                    fontSize: 17,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Gaiatrysts are a sequential psycbibiological path to evoke transpersonal solidarity, collective consciousness and revelatory epiphanies with the simple practices  above.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 17,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Why this App',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
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
                                      fontSize: 17,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.blue,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const SizedBox(height: 20),
                                const Text(
                                  'This simple Schumann Resonance monitor is primarily an objective real time reminder that our Earth Mother\'s biosphere continuously electrifies all our species\' inner being with the same subliminal energy waves. They are ancient, ubiquitous and intriguingly identical with our own brains\' most liminal frequencies at their Alpha & Theta wave border, which are also the vibes we autonomically reach when our breath, pulse and neural rhymes sync with others.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 17,
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
                                    fontSize: 17,
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
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  '''Collectively they generate a field of ±90 km standing waves between Earth's surface and the ionosphere. This harmonized aura is called the Schumann Resonance, which resonates around 7.8 Hertz (Hz) or cycles per second. Tauntingly auspiciously, this is the borderline frequency range between our own Alpha & Theta wave fields which characterize periods of meditation, prayer, spiritual healing, creative absorption, etc.''',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 17,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'The Schumann Resonance thus offers a constant subconscious nudge into heightened states of receptivity, compassion and divine-adjacent sensibility. SR sync is thus the target threshold of numinous possibilities.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 17,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'When these transcendent moments are felt in churches they are gratefully attributed to Christ or kin, in mosques to Allah, in ashrams to avatars and in temples to their focal sages, saints or tutelary deities.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 17,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'These imagined benefactors all differ widely yet their ecstatic blessings curiously seem to feel quite the same. Isn\'t it vastly more likely, these epiphanous awakenings are all really generated by the synced conjunctive psychosomatic energies of the congregations themselves?',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 17,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Once this realization dawns and spreads, we may kindle organic singularities ourselves and lay aside the exorbitant prosthetic tech AI lords say is required.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 17,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  '===============',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Gaiatryst Productions',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Gaiatrysts are covenworks – eclectic DIY tech to celebrate solidarity, provoke ecosocial epiphanies and re-enchant the stricken world.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 17,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Mission: Hasten group & couple arrivals at the liminal borders of entrainment, enlightenment & empowerment.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 19,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Strategy: Evoke breath sync, heart sync, neural sync & Schumann sync to collectively evoke and embody exceptional eco-protective powers.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 19,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Concept: Big Medicine\'s Saltation team',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 19,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Development: Integrative Tech Solutions',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 19,
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
                      'Gaiatryst Schumann Sync Link',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
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
  static final List<Star> _stars = [];
  static bool _initialized = false;

  StarryBackgroundPainter() {
    if (!_initialized) {
      final random = math.Random(42);
      // Reduced to 100 stars for low-end devices
      for (int i = 0; i < 100; i++) {
        _stars.add(
          Star(
            x: random.nextDouble(),
            y: random.nextDouble(),
            size: random.nextDouble() * 1.5 + 0.5,
            baseOpacity: random.nextDouble() * 0.5 + 0.3,
            twinkleSpeed: random.nextDouble() * 3 + 2,
            twinkleOffset: random.nextDouble() * math.pi * 2,
          ),
        );
      }
      _initialized = true;
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
