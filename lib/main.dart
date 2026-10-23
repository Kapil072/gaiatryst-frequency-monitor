import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:vector_math/vector_math_64.dart' hide Colors;

const String _kDataUrl =
    'https://raw.githubusercontent.com/Kapil072/gaiatryst-frequency-monitor/main/data.json';
const String _kFallbackUrl =
    'https://cdn.jsdelivr.net/gh/Kapil072/gaiatryst-frequency-monitor@main/data.json';
const double _kTilt = -23.5;

const Color _kGold = Color(0xFFFFD700);

const Map<String, String> _kLinks = {
  'gaiatryst': 'https://gaiatryst.com/',
  'dev': 'https://www.integrativetechsolutions.com',
  'heartmath': 'https://www.heartmath.org/gci/',
  'sacred': 'https://sacredanimalsparty.net',
  'youtube': 'https://www.youtube.com/watch?v=k8xynWgxQ1U',
  'medium':
      'https://medium.com/@neurokinetikz/quantitative-model-of-schumann-resonant-brain-dynamics-96c130468981',
};

const List<Map<String, dynamic>> _kStations = [
  {'id': 'GCI001', 'name': 'USA', 'lat': 33.0, 'lon': 162.05},
  {'id': 'GCI002', 'name': 'Saudi Arabia', 'lat': 26.8, 'lon': -45.16},
  {'id': 'GCI003', 'name': 'Lithuania', 'lat': 55.83, 'lon': -75.72},
  {'id': 'GCI004', 'name': 'Canada', 'lat': 47.6, 'lon': 165.57},
  {'id': 'GCI005', 'name': 'New Zealand', 'lat': -39.73, 'lon': 84.32},
  {'id': 'GCI006', 'name': 'South Africa', 'lat': -28.02, 'lon': -62.28},
];

Map<String, dynamic> _parseJson(String body) =>
    json.decode(body) as Map<String, dynamic>;

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  bool ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {}
  }
  if (!ok) {
    try {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (e) {
      debugPrint('URL: $e');
    }
  }
}

Future<bool> _hasInternet() async {
  if (kIsWeb) return true;
  try {
    final result = await InternetAddress.lookup('google.com')
        .timeout(const Duration(seconds: 5));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

// ============================================================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Gaiatryst Globe',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          colorScheme: const ColorScheme.dark(
              primary: Colors.blue, secondary: Colors.cyan),
        ),
        home: const EarthViewPage(),
      );
}

// ============================================================================
// GLOBE WIDGET
// ============================================================================
// The Earth is a textured UV sphere drawn with one Canvas.drawVertices call
// per frame. Only front-facing triangles are emitted, so a convex sphere needs
// no depth sorting, and every buffer is allocated once. The vertices carry no
// colors, which keeps rendering identical on Skia, Impeller and the web.
class _GlobeWidget extends StatefulWidget {
  const _GlobeWidget();
  @override
  State<_GlobeWidget> createState() => _GlobeState();
}

class _GlobeState extends State<_GlobeWidget>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _seconds = ValueNotifier(0.0);
  double _lastElapsed = 0.0;
  ui.Image? _earthImage;
  ScrollPosition? _scrollPosition;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _loadEarthTexture();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Stop animating while the globe is scrolled out of view.
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scrollPosition) {
      _scrollPosition?.removeListener(_onScroll);
      _scrollPosition = position?..addListener(_onScroll);
    }
  }

  void _onScroll() {
    final double height = context.size?.height ?? double.infinity;
    _ticker.muted = _scrollPosition!.pixels > height;
  }

  void _onTick(Duration elapsed) {
    final double ms = elapsed.inMilliseconds.toDouble();
    final double delta = (ms - _lastElapsed).clamp(0.0, 50.0);
    _lastElapsed = ms;
    if (_earthImage != null) _seconds.value += delta / 1000.0;
  }

  Future<void> _loadEarthTexture() async {
    try {
      final data = await rootBundle.load('assets/IMG_8725.JPG.jpeg');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 1024,
      );
      final image = (await codec.getNextFrame()).image;
      if (mounted) setState(() => _earthImage = image);
    } catch (e) {
      debugPrint('Earth texture failed: $e');
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_onScroll);
    _ticker.dispose();
    _seconds.dispose();
    _earthImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _earthImage;
    if (image == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return SizedBox.expand(
      child: CustomPaint(painter: _GlobePainter(image, _seconds)),
    );
  }
}

/// Unit-free sphere geometry shared by every painter instance.
class _SphereMesh {
  _SphereMesh(this.lonSegments, this.latSegments) {
    final int cols = lonSegments + 1;
    final int count = cols * (latSegments + 1);
    positions = Float64List(count * 3);
    uvs = Float64List(count * 2);
    for (int j = 0; j <= latSegments; j++) {
      final double lat = (j / latSegments * 180.0 - 90.0) * math.pi / 180.0;
      for (int i = 0; i <= lonSegments; i++) {
        // Same orientation and UV layout as the original Earth model:
        // u = (lon + 270) / 360, v = lat / 180 + 0.5.
        final double lon = (i / lonSegments * 360.0 - 270.0) * math.pi / 180.0;
        final int k = j * cols + i;
        positions[k * 3] = 0.5 * math.cos(lat) * math.cos(lon);
        positions[k * 3 + 1] = 0.5 * math.cos(lat) * math.sin(lon);
        positions[k * 3 + 2] = 0.5 * math.sin(lat);
        uvs[k * 2] = i / lonSegments;
        uvs[k * 2 + 1] = j / latSegments;
      }
    }

    // Triangles wound counter-clockwise when seen from outside.
    final List<int> tris = [];
    for (int j = 0; j < latSegments; j++) {
      for (int i = 0; i < lonSegments; i++) {
        final int a = j * cols + i, b = a + 1, c = b + cols, d = a + cols;
        if (j != 0) tris.addAll([a, b, c]);
        if (j != latSegments - 1) tris.addAll([a, c, d]);
      }
    }
    triangles = Uint16List.fromList(tris);
  }

  final int lonSegments;
  final int latSegments;
  late final Float64List positions;
  late final Float64List uvs;
  late final Uint16List triangles;

  int get vertexCount => positions.length ~/ 3;
}

class _GlobePainter extends CustomPainter {
  _GlobePainter(this.texture, this.seconds)
      : _texcoords = Float32List(_mesh.vertexCount * 2),
        _screen = Float32List(_mesh.vertexCount * 2),
        _visible = Uint16List(_mesh.triangles.length),
        super(repaint: seconds) {
    final double w = texture.width.toDouble();
    final double h = texture.height.toDouble();
    for (int i = 0; i < _mesh.vertexCount; i++) {
      _texcoords[i * 2] = _mesh.uvs[i * 2] * w;
      _texcoords[i * 2 + 1] = (1.0 - _mesh.uvs[i * 2 + 1]) * h;
    }
    _earthPaint.shader = ImageShader(
        texture, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage,
        filterQuality: FilterQuality.medium);
  }

  final ui.Image texture;
  final ValueNotifier<double> seconds;
  final Float32List _texcoords;
  final Float32List _screen;
  final Uint16List _visible;
  final Paint _earthPaint = Paint();
  final Paint _dotPaint = Paint();

  static final _SphereMesh _mesh = _SphereMesh(48, 24);

  static const double _kFov = 60.0;
  static const double _kRotSpeed = 9.375; // degrees per second
  static const double _kDotRadius = 0.05; // world units
  static const double _kDotPulseAmp = 0.018;
  static const double _kDotPulsePeriod = 1.2; // seconds

  static final Vector3 _cameraPos = Vector3(0.0, 0.0, 5.0);
  static final Matrix4 _view =
      makeViewMatrix(_cameraPos, Vector3.zero(), Vector3(0.0, 1.0, 0.0));
  static final Matrix4 _tilt = Matrix4.compose(Vector3.zero(),
      Quaternion.euler(0.0, 0.0, radians(_kTilt)), Vector3.all(1.0));
  static final Matrix4 _base = Matrix4.compose(Vector3.zero(),
      Quaternion.euler(0.0, radians(-90.0), 0.0), Vector3.all(3.0));

  // Station positions on the model's sphere (radius 0.5), slightly raised.
  static final List<Vector3> _dotPositions = [
    for (final s in _kStations)
      _latLonToVec3((s['lat'] as num).toDouble(), (s['lon'] as num).toDouble()),
  ];

  static Vector3 _latLonToVec3(double lat, double lon) {
    const double r = 0.505;
    final double latR = lat * (math.pi / 180.0);
    final double lonR = lon * (math.pi / 180.0);
    return Vector3(
      r * math.cos(latR) * math.cos(lonR),
      r * math.cos(latR) * math.sin(lonR),
      r * math.sin(latR),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double t = seconds.value;
    final double spin = (t * _kRotSpeed) % 360.0;
    final Matrix4 model = _tilt.multiplied(Matrix4.compose(Vector3.zero(),
        Quaternion.euler(radians(spin), 0.0, 0.0), Vector3.all(1.0)))
      ..multiply(_base);
    final Matrix4 mvp = makePerspectiveMatrix(
        radians(_kFov), size.width / size.height, 0.1, 1000.0)
      ..multiply(_view)
      ..multiply(model);

    _paintEarth(canvas, size, mvp);
    _paintDots(canvas, size, model, mvp, t);
  }

  void _paintEarth(Canvas canvas, Size size, Matrix4 mvp) {
    final Float64List m = mvp.storage;
    final Float64List p = _mesh.positions;
    final double halfW = size.width / 2.0;
    final double halfH = size.height / 2.0;
    for (int i = 0; i < _mesh.vertexCount; i++) {
      final double x = p[i * 3], y = p[i * 3 + 1], z = p[i * 3 + 2];
      final double w = m[3] * x + m[7] * y + m[11] * z + m[15];
      _screen[i * 2] =
          halfW * (1.0 + (m[0] * x + m[4] * y + m[8] * z + m[12]) / w);
      _screen[i * 2 + 1] =
          halfH * (1.0 - (m[1] * x + m[5] * y + m[9] * z + m[13]) / w);
    }

    // Keep triangles that are counter-clockwise on screen (y points down).
    final Uint16List tris = _mesh.triangles;
    int count = 0;
    for (int i = 0; i < tris.length; i += 3) {
      final int a = tris[i] * 2, b = tris[i + 1] * 2, c = tris[i + 2] * 2;
      final double area =
          (_screen[b] - _screen[a]) * (_screen[c + 1] - _screen[a + 1]) -
              (_screen[c] - _screen[a]) * (_screen[b + 1] - _screen[a + 1]);
      if (area < 0) {
        _visible[count++] = tris[i];
        _visible[count++] = tris[i + 1];
        _visible[count++] = tris[i + 2];
      }
    }

    final vertices = ui.Vertices.raw(
      VertexMode.triangles,
      _screen,
      textureCoordinates: _texcoords,
      indices: Uint16List.sublistView(_visible, 0, count),
    );
    canvas.drawVertices(vertices, BlendMode.srcOver, _earthPaint);
    vertices.dispose();
  }

  void _paintDots(
      Canvas canvas, Size size, Matrix4 model, Matrix4 mvp, double t) {
    final double unitsToPx =
        size.height / (2.0 * math.tan(radians(_kFov) / 2.0));
    final double pulse =
        (math.sin(t * math.pi * 2.0 / _kDotPulsePeriod) + 1.0) / 2.0;
    final double worldRadius = _kDotRadius + _kDotPulseAmp * pulse;

    for (final local in _dotPositions) {
      final Vector3 world = model.transform3(local.clone());
      // Fade out dots as they rotate behind the globe's limb.
      final double facing =
          world.normalized().dot((_cameraPos - world).normalized());
      final double alpha = (facing / 0.15).clamp(0.0, 1.0);
      if (alpha <= 0.0) continue;

      final Vector4 clip =
          mvp.transform(Vector4(local.x, local.y, local.z, 1.0));
      final Offset center = Offset(
        (1.0 + clip.x / clip.w) * size.width / 2.0,
        (1.0 - clip.y / clip.w) * size.height / 2.0,
      );
      final double r = worldRadius * unitsToPx / clip.w;

      _dotPaint.shader = ui.Gradient.radial(center, r * 2.4, [
        _kGold.withValues(alpha: 0.55 * alpha),
        _kGold.withValues(alpha: 0.0),
      ]);
      canvas.drawCircle(center, r * 2.4, _dotPaint);
      _dotPaint
        ..shader = null
        ..color = _kGold.withValues(alpha: alpha);
      canvas.drawCircle(center, r, _dotPaint);
    }
  }

  @override
  bool shouldRepaint(_GlobePainter old) =>
      old.texture != texture || old.seconds != seconds;
}

// ============================================================================
// STAR FIELD
// ============================================================================
class _StarField extends StatefulWidget {
  const _StarField();
  @override
  State<_StarField> createState() => _StarFieldState();
}

class _StarFieldState extends State<_StarField>
    with SingleTickerProviderStateMixin {
  static final List<_Star> _stars = _buildStars();
  late final Ticker _ticker;
  final ValueNotifier<double> _seconds = ValueNotifier(0.0);

  static List<_Star> _buildStars() {
    final r = math.Random(42);
    return List.generate(
      120,
      (_) => _Star(
        x: r.nextDouble(),
        y: r.nextDouble(),
        radius: r.nextDouble() * 1.3 + 0.4,
        base: r.nextDouble() * 0.5 + 0.25,
        speed: r.nextDouble() * 2.0 + 1.0,
        offset: r.nextDouble() * math.pi * 2,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _seconds.value = elapsed.inMilliseconds / 1000.0;
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: _StarPainter(_stars, _seconds),
          size: MediaQuery.of(context).size,
          child: const SizedBox.expand(),
        ),
      );
}

class _Star {
  final double x, y, radius, base, speed, offset;
  const _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.base,
    required this.speed,
    required this.offset,
  });
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final ValueNotifier<double> seconds;
  _StarPainter(this.stars, this.seconds) : super(repaint: seconds);

  @override
  void paint(Canvas c, Size sz) {
    final p = Paint()..style = PaintingStyle.fill;
    final t = seconds.value;
    for (final s in stars) {
      final tw = (math.sin(t * s.speed + s.offset) + 1.0) * 0.5;
      final op = (s.base * (0.3 + tw * 0.7)).clamp(0.0, 1.0);
      p.color = Color.fromRGBO(255, 255, 255, op);
      c.drawCircle(Offset(s.x * sz.width, s.y * sz.height), s.radius, p);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}

// ============================================================================
// MAIN PAGE
// ============================================================================
class EarthViewPage extends StatefulWidget {
  const EarthViewPage({super.key});
  @override
  State<EarthViewPage> createState() => _EarthViewPageState();
}

class _EarthViewPageState extends State<EarthViewPage> {
  double? _avgFreq;
  Map<String, double> _stationFreqs = {};
  Timer? _refreshTimer;
  bool _fetching = false;
  bool _noInternet = false;
  late final http.Client _httpClient;

  @override
  void initState() {
    super.initState();
    _httpClient = http.Client();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _loadFrequencyData();
    });
    _refreshTimer =
        Timer.periodic(const Duration(minutes: 3), (_) => _loadFrequencyData());
  }

  Future<void> _loadFrequencyData({int retry = 0}) async {
    if (_fetching) return;
    _fetching = true;

    final bool online = await _hasInternet();
    if (!online) {
      _fetching = false;
      if (mounted) setState(() => _noInternet = true);
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted) _loadFrequencyData();
      });
      return;
    }
    if (mounted && _noInternet) setState(() => _noInternet = false);

    final String url = (retry % 2 == 0) ? _kDataUrl : _kFallbackUrl;

    try {
      final res = await _httpClient
          .get(
            Uri.parse(url),
            // Browsers preflight custom headers and GitHub rejects the preflight.
            headers: kIsWeb
                ? null
                : {
                    'Accept': 'application/json, text/plain, */*',
                    'User-Agent': 'GaiatrystApp/1.0',
                    'Cache-Control': 'no-cache, no-store, must-revalidate',
                    'Pragma': 'no-cache',
                    'Connection': 'keep-alive',
                  },
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final Map<String, dynamic> data = await compute(_parseJson, res.body);
      final bool isLive = data['is_live'] == true;
      final dynamic globalAvg = data['global_avg'];

      if (!isLive || globalAvg == null) {
        if (mounted) {
          setState(() {
            _avgFreq = null;
            _stationFreqs = {};
          });
        }
        return;
      }

      final double avg = (globalAvg as num).toDouble();
      final dynamic stRaw = data['stations'];
      final Map<String, double> freqs = {};

      if (stRaw is Map) {
        for (final station in _kStations) {
          final String id = station['id'] as String;
          final v = stRaw[id];
          if (v == null) continue;
          final double? f = v is num ? v.toDouble() : double.tryParse('$v');
          if (f != null && f > 0) freqs[id] = f;
        }
      }

      if (mounted) {
        setState(() {
          _avgFreq = avg;
          _stationFreqs = freqs;
        });
      }
    } catch (e) {
      await _scheduleRetry(retry);
    } finally {
      _fetching = false;
    }
  }

  Future<void> _scheduleRetry(int retry) async {
    if (retry >= 5) {
      if (mounted) setState(() => _avgFreq = null);
      return;
    }
    final int delaySecs = math.min(5 * math.pow(2, retry).toInt(), 60);
    _fetching = false;
    await Future.delayed(Duration(seconds: delaySecs));
    if (mounted) await _loadFrequencyData(retry: retry + 1);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _httpClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double globeH = MediaQuery.of(context).size.height * 0.6;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const RepaintBoundary(child: _StarField()),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(top: 64),
              child: ScrollConfiguration(
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: globeH,
                        child: const RepaintBoundary(child: _GlobeWidget()),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Transform.translate(
                        offset: const Offset(0, -60),
                        child: Column(
                          children: [
                            RepaintBoundary(
                              child: _FreqDisplay(
                                avgFreq: _avgFreq,
                                noInternet: _noInternet,
                              ),
                            ),
                            if (_noInternet)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color:
                                            Colors.red.withValues(alpha: 0.5)),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.wifi_off,
                                          color: Colors.redAccent, size: 16),
                                      SizedBox(width: 8),
                                      Text(
                                        'No internet connection. Retrying…',
                                        style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (_stationFreqs.isNotEmpty)
                              const SizedBox(height: 16),
                            if (_stationFreqs.isNotEmpty)
                              RepaintBoundary(
                                child:
                                    _StationGrid(stationFreqs: _stationFreqs),
                              ),
                            if (_stationFreqs.isNotEmpty)
                              const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          child: ColoredBox(
                            color: Color(0xB3000000),
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: _InfoPanel(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              ),
            ),
          ),
          const SafeArea(child: _Header()),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPONENTS
// ============================================================================
class _FreqDisplay extends StatelessWidget {
  final double? avgFreq;
  final bool noInternet;
  const _FreqDisplay({required this.avgFreq, this.noInternet = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(children: [
          const Text('Average Data',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(
            avgFreq != null
                ? '${avgFreq!.toStringAsFixed(2)} Hz'
                : noInternet
                    ? 'NO SIGNAL'
                    : 'OFFLINE',
            style: TextStyle(
              color: avgFreq != null
                  ? Colors.cyan
                  : noInternet
                      ? Colors.orange
                      : Colors.red,
              fontSize: 56,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            avgFreq != null
                ? 'Live'
                : noInternet
                    ? 'No Internet'
                    : 'No Connection',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
        ]),
      );
}

class _StationGrid extends StatelessWidget {
  final Map<String, double> stationFreqs;
  const _StationGrid({required this.stationFreqs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        const Text('Monitoring Stations',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: _kStations.map((station) {
            final String id = station['id'] as String;
            final String name = station['name'] as String;
            final double? freq = stationFreqs[id];
            final bool on = freq != null && freq > 0;
            return Container(
              width: 110,
              height: 80,
              decoration: BoxDecoration(
                color: on
                    ? Colors.blue.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: on
                      ? Colors.blue.withValues(alpha: 0.5)
                      : Colors.grey.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name,
                        style: TextStyle(
                            color: on ? Colors.white : Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Text(
                      on ? '${freq.toStringAsFixed(2)} Hz' : 'Offline',
                      style: TextStyle(
                          color: on ? Colors.cyanAccent : Colors.grey.shade600,
                          fontSize: on ? 13 : 10,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ]),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/WhatsApp_Image_2025-12-28_at_5.00.39_PM-removebg-preview (1).png',
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.error, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'GAIATRYST SYNOPSIS SCHUMANN RESONANCE LINK',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel();

  static Widget _h(String t, double sz) => Text(t,
      textAlign: TextAlign.center,
      style: TextStyle(
          color: Colors.white,
          fontSize: sz + 1,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5));

  static Widget _b(String t) => Text(t,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white70, fontSize: 17, height: 1.6));

  static Widget _img(String a, {double r = 8}) => ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: Image.asset(a,
          fit: BoxFit.contain,
          width: double.infinity,
          cacheWidth: 800,
          errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey.shade800,
              height: 100,
              child: const Center(
                  child: Text('Image missing',
                      style: TextStyle(color: Colors.white))))));

  static Widget _lnk(String label, String key) =>
      _Lnk(label: label, url: _kLinks[key]!);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      _h('GAIATRYST SYNOPSIS', 22),
      const SizedBox(height: 16),
      _b('Consecutively syncing groups & couples breathing, heart beats, brain waves & Schumann planetary resonance is humanity\'s high road back to religiosity\'s origins and existential re-enchantment.'),
      const SizedBox(height: 12),
      _b('Gaiatrysts are a sequential psycbibiological path to evoke transpersonal solidarity, collective consciousness and revelatory epiphanies with the simple practices above.'),
      const SizedBox(height: 24),
      _h('Why this App', 18),
      const SizedBox(height: 12),
      _img('assets/why this app.png'),
      const SizedBox(height: 12),
      _lnk('Schumann-Resonant Brain Dynamics', 'medium'),
      const SizedBox(height: 20),
      _b('This simple Schumann Resonance monitor is primarily an objective real time reminder that our Earth Mother\'s biosphere continuously electrifies all our species\' inner being with the same subliminal energy waves. They are ancient, ubiquitous and intriguingly identical with our own brains\' most liminal frequencies at their Alpha & Theta wave border, which are also the vibes we autonomically reach when our breath, pulse and neural rhymes sync with others.'),
      const SizedBox(height: 12),
      _img('assets/Picture1.png'),
      const SizedBox(height: 8),
      _b('Like our human brain, Mother Earth enjoys an electro-magnetic peripheral halo. It is powered not by neural firings, but by the ±tens of thousands of lightning bursts flashing every second.'),
      const SizedBox(height: 12),
      _img('assets/More about Schumann Vibes .jpg'),
      const SizedBox(height: 8),
      const Text(
          'Brief NASA timelapse of space Lightning on just bottom of this image',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.4)),
      const SizedBox(height: 12),
      _b('Collectively they generate a field of ±90 km standing waves between Earth\'s surface and the ionosphere. This harmonized aura is called the Schumann Resonance, which resonates around 7.8 Hertz (Hz) or cycles per second. Tauntingly auspiciously, this is the borderline frequency range between our own Alpha & Theta wave fields which characterize periods of meditation, prayer, spiritual healing, creative absorption, etc.'),
      const SizedBox(height: 12),
      _b('The Schumann Resonance thus offers a constant subconscious nudge into heightened states of receptivity, compassion and divine-adjacent sensibility. SR sync is thus the target threshold of numinous possibilities.'),
      const SizedBox(height: 12),
      _b('When these transcendent moments are felt in churches they are gratefully attributed to Christ or kin, in mosques to Allah, in ashrams to avatars and in temples to their focal sages, saints or tutelary deities.'),
      const SizedBox(height: 12),
      _b('These imagined benefactors all differ widely yet their ecstatic blessings curiously seem to feel quite the same. Isn\'t it vastly more likely, these epiphanous awakenings are all really generated by the synced conjunctive psychosomatic energies of the congregations themselves?'),
      const SizedBox(height: 12),
      _b('Once this realization dawns and spreads, we may kindle organic singularities ourselves and lay aside the exorbitant prosthetic tech AI lords say is required.'),
      const SizedBox(height: 20),
      const Text('===============',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('Gaiatryst Origins',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5)),
      const SizedBox(height: 12),
      _b('Gaiatrysts are covenworks – eclectic DIY tech to celebrate solidarity, provoke ecosocial epiphanies and re-enchant the stricken world.'),
      const SizedBox(height: 12),
      _b('Mission: Hasten group & couple arrivals at the liminal borders of entrainment, enlightenment & empowerment.'),
      const SizedBox(height: 12),
      _b('Strategy: Evoke breath sync, heart sync, neural sync & Schumann sync to collectively evoke and embody exceptional eco-protective powers.'),
      const SizedBox(height: 24),
      const Divider(color: Colors.white30, thickness: 1.5),
      const SizedBox(height: 16),
      const Text('══════════════════════════════',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 13)),
      const SizedBox(height: 10),
      const Text('VITAL CONTRIBUTORS',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white)),
      const SizedBox(height: 16),
      const Text('CONCEPT:',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
      const SizedBox(height: 4),
      _lnk("Big Medicine's Gaiatryst team", 'gaiatryst'),
      const SizedBox(height: 12),
      const Text('DEVELOPMENT:',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
      const SizedBox(height: 4),
      _lnk('Integrative Tech Solutions', 'dev'),
      const SizedBox(height: 8),
      _CreditsRow(
          label: 'DATA SOURCE:',
          child: _lnk("HeartMath Institute's trailblazing sensor network",
              'heartmath')),
      const SizedBox(height: 8),
      _CreditsRow(
          label: 'PROJECT NURSERY:',
          child: _lnk('Sacred Animals Party Productions', 'sacred')),
      const SizedBox(height: 16),
      const Text('════════════════════════',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 13)),
      const SizedBox(height: 16),
      const Text('SR FINAL FULL MONTE',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white)),
      const SizedBox(height: 20),
      _lnk("Stefan Burb's amazing cosmic evolution tracking", 'youtube'),
      const SizedBox(height: 16),
      _img('assets/IMG_9429.jpeg', r: 12),
      const SizedBox(height: 12),
      _lnk(
          'Everything We Know About Schumann Resonances\n— The Most Important Thing You\'ve NEVER Heard Of',
          'youtube'),
      const SizedBox(height: 20),
      _h('Racing the AI Machines to Humane Singularity', 18),
      const SizedBox(height: 32),
    ]);
  }
}

class _CreditsRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _CreditsRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          child,
        ],
      ),
    );
  }
}

class _Lnk extends StatelessWidget {
  final String label, url;
  const _Lnk({required this.label, required this.url});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _openUrl(url),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.blue,
                  height: 1.6)),
        ),
      );
}
