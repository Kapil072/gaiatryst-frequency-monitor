import 'dart:math' as math;
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cube/flutter_cube.dart';
import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';

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
  Object? _earthObject;
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _starsController;
  double _rotationY = 0.0;
  bool _isPanning = false;
  Timer? _rotationTimer;

  // Frequency data
  double? _averageFrequency;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    // Use Timer for continuous smooth rotation (Earth rotates once every 60 seconds for visibility)
    const rotationDurationSeconds = 60.0; // Full rotation time
    const frameIntervalSeconds = 0.016; // ~60fps (16ms per frame)
    const rotationSpeed =
        (2 * math.pi) / rotationDurationSeconds; // Radians per second

    _rotationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!_isPanning && _earthObject != null) {
        // Calculate rotation increment per frame
        final rotationIncrement = rotationSpeed * frameIntervalSeconds;

        setState(() {
          _rotationY += rotationIncrement;
          // Normalize to 0-2π range to prevent overflow
          while (_rotationY >= 2 * math.pi) {
            _rotationY -= 2 * math.pi;
          }

          // Apply rotation to the 3D object (around Y-axis for Earth's axis)
          _earthObject!.rotation.x = 0;
          _earthObject!.rotation.y = _rotationY;
          _earthObject!.rotation.z = 0;
          _earthObject!.updateTransform();

          // Force scene to render the updated rotation
          if (_currentScene != null) {
            _currentScene!.update();
          }
        });
      }
    });

    // Animation controller for twinkling stars
    _starsController = AnimationController(
      vsync: this,
      duration:
          const Duration(seconds: 60), // 60 second loop for star twinkling
    )..repeat();
    _starsController.addListener(() {
      setState(() {}); // Trigger rebuild to repaint stars
    });

    // Load frequency data immediately and set up hourly refresh
    _loadFrequencyData();
    _refreshTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _loadFrequencyData();
    });
  }

  Future<void> _loadFrequencyData() async {
    try {
      // Try multiple possible paths for the CSV file
      final possiblePaths = [
        'python/gci_hourly_log_clean.csv',
        '../python/gci_hourly_log_clean.csv',
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

      if (csvFile == null) {
        debugPrint('CSV file not found. Tried paths: $possiblePaths');
        return;
      }

      final csvContent = await csvFile.readAsString();
      final rows = const CsvToListConverter().convert(csvContent);

      if (rows.length < 2) {
        debugPrint('CSV file is empty or has no data rows');
        return;
      }

      // Find the index of "Global Avg Power" column
      final headerRow = rows[0];
      final avgPowerIndex = headerRow.indexOf('Global Avg Power');

      if (avgPowerIndex == -1) {
        debugPrint('Global Avg Power column not found');
        return;
      }

      // Get the last row (most recent data)
      final lastRow = rows[rows.length - 1];
      final avgPower = lastRow[avgPowerIndex];

      setState(() {
        _averageFrequency = (avgPower is num)
            ? avgPower.toDouble()
            : double.tryParse(avgPower.toString());
      });
    } catch (e) {
      debugPrint('Error loading frequency data: $e');
    }
  }

  Scene? _currentScene;

  void _handleSceneCreated(Scene scene) {
    _currentScene = scene;
    // Store reference to scene for rotation updates
    // Position camera to view Earth with poles at top/bottom (vertical axis)
    scene.camera.position.z = 5;
    scene.camera.position.y = 0;
    scene.camera.position.x = 0;

    // Ensure camera looks at center (0,0,0) to keep poles aligned
    // Camera defaults to looking at origin, so this ensures proper alignment

    // Debug: Verify scene is created
    debugPrint('Scene created for Earth rotation');

    // Enhanced lighting for realistic Earth rendering
    scene.light
      ..position.setValues(5, 5, 5)
      ..setColor(Colors.white, 0.35, 1.0, 0.6);

    // Load the OBJ model with high-quality texture
    // Ensure initial rotation is only on Y-axis (vertical) to keep poles fixed
    try {
      final earthObject = Object(
        fileName: 'assets/13902_Earth_v1_l3.obj',
        scale: Vector3(3.0, 3.0, 3.0),
        position: Vector3(0, 0, 0), // Center at origin
        rotation:
            Vector3(0, _rotationY, 0), // Only Y-axis rotation (vertical axis)
        lighting: true,
        backfaceCulling: true,
      );

      scene.world.add(earthObject);

      setState(() {
        _earthObject = earthObject;
        _isLoading = false;
      });

      // Ensure texture is applied
      _applyCustomTexture(earthObject);
    } catch (error) {
      debugPrint('Error loading OBJ model: $error');
      // Fallback: Create a sphere with texture
      _createSphereFallback(scene);
    }
  }

  Future<void> _applyCustomTexture(Object target) async {
    // Wait until the OBJ finishes loading its mesh (async inside flutter_cube)
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
      target.mesh.textureRect = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      // Ensure the scene repacks textures and re-renders with the new map
      target.scene?.updateTexture();
      setState(() {
        _earthObject = target;
      });
    } catch (e) {
      debugPrint('Failed to apply custom texture: $e');
    }
  }

  void _createSphereFallback(Scene scene) {
    // Create a high-quality sphere as fallback with 8K texture
    try {
      final sphereObj = Object(
        fileName: 'assets/13902_Earth_v1_l3.obj',
        scale: Vector3(3.0, 3.0, 3.0),
        position: Vector3(0, 0, 0), // Center at origin
        rotation: Vector3(0, _rotationY, 0), // Only Y-axis rotation
        lighting: true,
        backfaceCulling: true,
      );
      scene.world.add(sphereObj);
      _applyCustomTexture(sphereObj);
      setState(() {
        _earthObject = sphereObj;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Error creating sphere fallback: $error');
      // Try with the original texture as last resort
      try {
        final sphere = Object(
          fileName: 'assets/Earth_diff.jpg',
          scale: Vector3(3.0, 3.0, 3.0),
          position: Vector3(0, 0, 0), // Center at origin
          rotation: Vector3(0, _rotationY, 0), // Only Y-axis rotation
        );
        scene.world.add(sphere);
        setState(() {
          _earthObject = sphere;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to load Earth model: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _handlePanStart(DragStartDetails details) {
    _isPanning = true;
    // Rotation will be paused automatically since _isPanning check in timer
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isPanning || _earthObject == null) return;

    const sensitivity = 0.01;
    _rotationY += details.delta.dx * sensitivity;
    // Normalize rotation to 0-2π range
    if (_rotationY > 2 * math.pi) {
      _rotationY -= 2 * math.pi;
    } else if (_rotationY < 0) {
      _rotationY += 2 * math.pi;
    }
    // Keep rotation only on Y-axis to preserve pole alignment
    _earthObject!.rotation.x = 0;
    _earthObject!.rotation.y = _rotationY;
    _earthObject!.rotation.z = 0;
    _earthObject!.updateTransform();
    _earthObject!.scene?.update();
    setState(() {});
  }

  void _handlePanEnd(DragEndDetails details) {
    _isPanning = false;
    // Automatic rotation will resume via the timer
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
          // Twinkling stars background
          AnimatedBuilder(
            animation: _starsController,
            builder: (context, child) {
              return CustomPaint(
                painter: StarryBackgroundPainter(),
                size: MediaQuery.of(context).size,
              );
            },
          ),
          // Scrollable content (globe + about section), like a feed
          Positioned.fill(
            child: Padding(
              // Leave space at top for logo row
              padding: const EdgeInsets.only(top: 64.0),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false, // Hide scrollbar
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Globe section
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              GestureDetector(
                                onPanStart: _handlePanStart,
                                onPanUpdate: _handlePanUpdate,
                                onPanEnd: _handlePanEnd,
                                child: Cube(
                                  key: const ValueKey(
                                      'earth_cube'), // Stable key
                                  onSceneCreated: _handleSceneCreated,
                                  interactive: true,
                                ),
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
                      // Average Frequency Display
                      if (_averageFrequency != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '${_averageFrequency!.toStringAsFixed(2)} Hz',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),
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
                      if (_averageFrequency != null) const SizedBox(height: 24),
                      // About section
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
                                // Image after "Why this App"
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    'assets/why this app.png',
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Link after image
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
                                // Image after "More about Schumann Vibes"
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    'assets/More about Schumann Vibes .jpg',
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // "NASA Space Lightning Array" in small text after image
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
          // Top title with logo
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
                      'suchaman app',
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

// Custom painter for twinkling stars background
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
