import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:math' show Random;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_cube/flutter_cube.dart'; // IMPORT WAJIB UNTUK 3D

import 'api_config.dart';
import 'nik_check.dart';
import 'admin_page.dart';
import 'owner_page.dart';
import 'home_page.dart';
import 'seller_page.dart';
import 'change_password_page.dart';
import 'tools_gateway.dart';
import 'login_page.dart';
import 'bug_sender.dart';
import 'contact_page.dart';
import 'profile_page.dart';
import 'riwayat_page.dart';
import 'info_page.dart';
import 'al_quran.dart';
import 'anime_home.dart';
import 'order_page.dart';
import 'theme.dart';

// ─── FALLBACK GLOBAL STATE (Jika belum didefinisikan di file lain) ─────────────
// Hapus bagian ini jika Anda sudah punya di file lain (misal theme.dart)
final ValueNotifier<bool> is3DModeNotifier = ValueNotifier<bool>(false);
void toggle3DMode(bool value) {
  is3DModeNotifier.value = value;
}
// ──────────────────────────────────────────────────────────────────────────────

// ─── COLORS ────────────────────────────────────────────────────────────────────
const Color kBg      = Color(0xFF0B0C10);
const Color kCard    = Color(0xFF121420);
const Color kCardAlt = Color(0xFF1F1B2E);
const Color kBorder  = Color(0xFF3A2E5C);

const Color kCyan    = Color(0xFF66FCF1);
const Color kGreen   = Color(0xFF00E676);
const Color kPink    = Color(0xFFFF3366);
const Color kOrange  = Color(0xFFFF9F00);
const Color kBlue    = Color(0xFF2979FF);
const Color kPurple  = Color(0xFF9D4EDD);
const Color kYellow  = Color(0xFFFFD600);

const Color kWhite   = Colors.white;
const Color kWhite54 = Colors.white54;
const Color kWhite24 = Colors.white24;

// ─── Prayer Time Service ───────────────────────────────────────────────────────
class PrayerTimeService {
  static Future<Map<String, dynamic>> fetchPrayerTimes(String city) async {
    final now = DateTime.now();
    final uri = Uri.https('api.aladhan.com', '/v1/timingsByCity', {
      'city': city, 'country': 'ID', 'method': '11',
      'day': '${now.day}', 'month': '${now.month}', 'year': '${now.year}',
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return {};
  }
}

// ─── Role helpers ─────────────────────────────────────────────────────────────
Color _roleColor(String role) {
  switch (role.toLowerCase()) {
    case 'owner':    return const Color(0xFFF59E0B);
    case 'admin':    return const Color(0xFFEF4444);
    case 'reseller': return kGreen;
    case 'vip':      return kPurple;
    default:         return kCyan;
  }
}

IconData _roleIcon(String role) {
  switch (role.toLowerCase()) {
    case 'owner':    return Icons.workspace_premium_rounded;
    case 'admin':    return Icons.admin_panel_settings_rounded;
    case 'reseller': return Icons.storefront_rounded;
    case 'vip':      return Icons.star_rounded;
    default:         return Icons.person_rounded;
  }
}

// ─── ANIMATED DOT ──────────────────────────────────────────────────────────────
class _AnimatedDot extends StatefulWidget {
  final Color color;
  final double size;
  const _AnimatedDot({required this.color, this.size = 6});
  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _a = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _a,
    child: Container(
      width: widget.size, height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle, color: widget.color,
        boxShadow: [BoxShadow(color: widget.color.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)],
      ),
    ),
  );
}

// ─── HEXAGON PATTERN PAINTER ──────────────────────────────────────────────────
class _HexagonPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kCyan.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const double w = 72.0;
    const double h = 52.0;

    for (double row = -1; row * h < size.height + h * 2; row++) {
      for (double col = -1; col * w < size.width + w * 2; col++) {
        final double offsetX = (row.toInt() % 2 == 0) ? 0 : w * 0.5;
        final cx = col * w + offsetX;
        final cy = row * h;
        _drawDiamond(canvas, paint, Offset(cx, cy), w * 0.5, h * 0.5);
      }
    }
  }

  void _drawDiamond(Canvas canvas, Paint paint, Offset center, double hw, double hh) {
    final path = Path()
      ..moveTo(center.dx, center.dy - hh)
      ..lineTo(center.dx + hw, center.dy)
      ..lineTo(center.dx, center.dy + hh)
      ..lineTo(center.dx - hw, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── GRID PATTERN PAINTER ─────────────────────────────────────────────────────
class _GridPatternPainter extends CustomPainter {
  final Color gridColor;
  final Color lineColor;
  final double spacing;
  const _GridPatternPainter({required this.gridColor, required this.lineColor, required this.spacing});
  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()..color = gridColor..strokeWidth = 0.8..style = PaintingStyle.stroke;
    final paintLines = Paint()..color = lineColor..strokeWidth = 0.4..style = PaintingStyle.stroke;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintGrid);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }
    for (double x = -size.height; x < size.width + size.height; x += spacing * 2) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paintLines);
    }
    for (double x = -size.height; x < size.width + size.height; x += spacing * 2) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paintLines);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── INTERACTIVE 3D CUBE (WIDGET BARU) ────────────────────────────────────────
class Interactive3DCube extends StatefulWidget {
  final Color color;
  const Interactive3DCube({super.key, required this.color});

  @override
  State<Interactive3DCube> createState() => _Interactive3DCubeState();
}

class _Interactive3DCubeState extends State<Interactive3DCube> with SingleTickerProviderStateMixin {
  late Object _cube;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Membuat objek 3D. Pastikan file 'assets/cube/cube.obj' ada di pubspec.yaml
    // Jika tidak ada file, Anda bisa menggunakan mesh prosedural (lebih kompleks).
    _cube = Object(fileName: 'assets/cube/cube.obj');
    
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _controller.addListener(() {
      // Rotasi objek secara terus menerus
      _cube.rotation.y = _controller.value * 360;
      _cube.updateTransform();
      // Memicu repaint pada scene 3D (diperlukan untuk animasi manual)
      // Di flutter_cube, perubahan pada Object biasanya ditangani oleh internal ticker jika interactive: true,
      // namun untuk rotasi manual, kita perlu memastikan update.
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBg,
      child: Cube(
        onSceneCreated: (Scene scene) {
          scene.world.add(_cube);
          scene.camera.position.z = 5; // Jarak kamera agar kubus terlihat pas
          scene.camera.zoom = 10;
          // Opsional: atur pencahayaan jika ada
          // scene.light.position.setValues(0, 10, 10);
        },
        interactive: true, // Memungkinkan user melakukan zoom/rotate dengan sentuhan
      ),
    );
  }
}

// ─── Dashboard Page ───────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final List<dynamic> news;

  const DashboardPage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.listBug,
    required this.listDoos,
    required this.sessionKey,
    required this.news,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState(); 
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  
  // ── State ────────────────────────────────────────────────────────────────
  late String sessionKey, username, password, role, expiredDate;
  late List<Map<String, dynamic>> listBug, listDoos;
  late List<dynamic> newsList;

  late WebSocketChannel channel;
  String androidId = 'unknown';
  File? _profileImage;
  VideoPlayerController? _menuVideoCtrl;

  int _navIndex   = 0;
  int onlineUsers = 0;
  int activeConns = 0;

  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Online Users polling
  Timer? _statsTimer;

  // News carousel
  late PageController _newsPageCtrl;
  int _newsPageViewKey = 0;
  double _currentNewsPage = 0.0;

  // Quick Actions carousel
  late PageController _qaPageCtrl;
  double _currentQaPage = 0.0;

  // ── Location ──
  bool _locationLoading = false;
  bool _locationGranted = false;

  // ── Prayer times ──
  String _prayerCity = 'Surabaya';
  Map<String, String> _prayerTimes = {};
  String _nextPrayerLabel = '';
  String _nextPrayerTime  = '';
  bool _prayerLoading = true;

  // ── Hadith ──
  Map<String, dynamic>? _hadith;
  bool _hadithLoading = true;
  int _lastHadithNumber = 0;

  @override
  void initState() {
    super.initState();
    sessionKey  = widget.sessionKey;
    username    = widget.username;
    password    = widget.password;
    role        = widget.role;
    expiredDate = widget.expiredDate;
    listBug     = widget.listBug;
    listDoos    = widget.listDoos;
    newsList    = widget.news;

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _newsPageCtrl = PageController(viewportFraction: 0.88, initialPage: 0);
    _newsPageCtrl.addListener(() {
      if (mounted) setState(() => _currentNewsPage = _newsPageCtrl.page ?? 0.0);
    });

    _qaPageCtrl = PageController(viewportFraction: 0.88, initialPage: 0);
    _qaPageCtrl.addListener(() {
      if (mounted) setState(() => _currentQaPage = _qaPageCtrl.page ?? 0.0);
    });

    _initAndroidId();
    _loadProfileImage();
    _initMenuVideo();
    _detectLocationAndFetchPrayer(); 
    _fetchRandomHadith();
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    channel.sink.close(status.goingAway);
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _menuVideoCtrl?.dispose();
    _newsPageCtrl.dispose();
    _qaPageCtrl.dispose();
    super.dispose();
  }

  // ── Init helpers ──────────────────────────────────────────────────────────
  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path  = prefs.getString('profile_image_$username');
    if (path != null && path.isNotEmpty && mounted) {
      setState(() => _profileImage = File(path));
    }
  }

  void _initMenuVideo() {
    _menuVideoCtrl = VideoPlayerController.asset('assets/videos/banner.mp4')
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _menuVideoCtrl?.setLooping(true);
        _menuVideoCtrl?.setVolume(0);
        _menuVideoCtrl?.play();
      });
  }

  Future<void> _initAndroidId() async {
    final info = await DeviceInfoPlugin().androidInfo;
    androidId = info.id;
    _connectWS();
  }

  void _connectWS() {
    channel = WebSocketChannel.connect(Uri.parse('$baseUrl'));

    channel.sink.add(jsonEncode({
      'type': 'validate',
      'key': sessionKey,
      'androidId': androidId,
    }));

    channel.stream.listen((event) {
      final data = jsonDecode(event);

      if (data['type'] == 'myInfo' && data['valid'] == true && mounted) {
        channel.sink.add(jsonEncode({'type': 'stats'}));
      }

      if (data['type'] == 'stats' && mounted) {
        setState(() {
          onlineUsers = data['onlineUsers'] ?? 0;
          activeConns = data['activeConnections'] ?? 0;
        });
      }

      if (data['type'] == 'myInfo' && data['valid'] == false && mounted) {
        _handleInvalidSession(data['reason'] ?? 'Session invalid');
      }

      if (data['type'] == 'forceLogout' && mounted) {
        _handleInvalidSession(data['reason'] ?? 'Logged out');
      }
    }, onError: (_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _connectWS();
      });
    });

    _statsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      try {
        channel.sink.add(jsonEncode({'type': 'stats'}));
      } catch (_) {}
    });
  }

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  // ── Fetch Prayer Times ────────────────────────────────────────────────────
  Future<void> _fetchPrayerTimes() async {
    if (!mounted) return;
    setState(() => _prayerLoading = true);
    final data = await PrayerTimeService.fetchPrayerTimes(_prayerCity);
    if (!mounted) return;
    if (data.isNotEmpty) {
      final timings = data['data']?['timings'] ?? {};
      final Map<String, String> times = {
        'Subuh'  : timings['Fajr']    ?? '--:--',
        'Dzuhur' : timings['Dhuhr']   ?? '--:--',
        'Ashar'  : timings['Asr']     ?? '--:--',
        'Maghrib': timings['Maghrib'] ?? '--:--',
        'Isya'   : timings['Isha']    ?? '--:--',
      };
      final now = TimeOfDay.now();
      String nextLabel = 'Isya';
      String nextTime  = times['Isya'] ?? '--:--';
      for (final entry in times.entries) {
        final parts = entry.value.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          if (h > now.hour || (h == now.hour && m > now.minute)) {
            nextLabel = entry.key;
            nextTime  = entry.value;
            break;
          }
        }
      }
      setState(() {
        _prayerTimes     = times;
        _nextPrayerLabel = nextLabel;
        _nextPrayerTime  = nextTime;
        _prayerLoading   = false;
      });
    } else {
      setState(() => _prayerLoading = false);
    }
  }

  // ── Detect Location ───────────────────────────────────────────────────────
  Future<void> _detectLocationAndFetchPrayer() async {
    if (!mounted) return;
    setState(() => _locationLoading = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationLoading = false;
            _prayerCity = 'Surabaya';
          });
          await _fetchPrayerTimes();
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _locationLoading = false;
              _prayerCity = 'Surabaya';
            });
            await _fetchPrayerTimes();
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationLoading = false;
            _prayerCity = 'Surabaya';
          });
          await _fetchPrayerTimes();
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final city = place.subAdministrativeArea?.isNotEmpty == true
            ? place.subAdministrativeArea!
            : place.locality?.isNotEmpty == true
                ? place.locality!
                : place.administrativeArea ?? 'Surabaya';

        setState(() {
          _prayerCity     = city;
          _locationGranted = true;
          _locationLoading = false;
        });

        await _fetchPrayerTimes();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [
                const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Lokasi terdeteksi: $city'),
              ]),
              backgroundColor: kGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationLoading = false;
          _prayerCity = 'Surabaya';
        });
        await _fetchPrayerTimes();
      }
    }
  }

  // ── Fetch Hadith ──────────────────────────────────────────────────────────
  // ── Fetch Hadith (Lanjutan dari baris 594) ────────────────────────────────
Future<void> _fetchRandomHadith() async {
  if (!mounted) return;
  setState(() => _hadithLoading = true);
  try {
    int randomNumber;
    do {
      randomNumber = Random().nextInt(100) + 1;
    } while (randomNumber == _lastHadithNumber);
    _lastHadithNumber = randomNumber;
    final response = await http
        .get(Uri.parse('https://api.hadith.gading.dev/books/muslim/$randomNumber'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 200 && mounted) {
      setState(() { _hadith = json.decode(response.body); _hadithLoading = false; });
    } else {
      if (mounted) setState(() => _hadithLoading = false);
    }
  } catch (_) {
    if (mounted) setState(() => _hadithLoading = false);
  }
}

// ── Change City Dialog ────────────────────────────────────────────────────
void _showChangeCityDialog() {
  final ctrl = TextEditingController(text: _prayerCity);
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Ganti Lokasi',
          style: TextStyle(color: kWhite, fontFamily: 'Orbitron', fontSize: 14)),
      content: TextField(
        controller: ctrl,
        style: const TextStyle(color: kWhite),
        decoration: InputDecoration(
          hintText: 'Nama kota (misal: Jakarta)',
          hintStyle: const TextStyle(color: kWhite54),
          filled: true, fillColor: kBg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          prefixIcon: const Icon(Icons.location_city_rounded, color: kGreen),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: kWhite54))),
        ElevatedButton(
          onPressed: () {
            if (ctrl.text.trim().isNotEmpty) {
              setState(() {
                _prayerCity = ctrl.text.trim();
                _locationGranted = false; 
              });
              _fetchPrayerTimes();
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Simpan',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

// ── Hadith Full Dialog ────────────────────────────────────────────────────
void _showHadithFullDialog(String arabic, String indo, String source, String number, String grade) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kCyan.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: kCyan.withOpacity(0.08), blurRadius: 30, spreadRadius: 2),
            BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                color: kCyan.withOpacity(0.08),
                border: Border(bottom: BorderSide(color: kBorder.withOpacity(0.5))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: kCyan.withOpacity(0.2)),
                    child: const Icon(Icons.menu_book_rounded, color: kCyan, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('HADITH LENGKAP',
                          style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Orbitron')),
                      Text(grade, style: const TextStyle(color: kCyan, fontSize: 11)),
                    ]),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: kWhite.withOpacity(0.08)),
                      child: const Icon(Icons.close_rounded, color: kWhite54, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.62),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity, padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF1A1F2E),
                        border: Border.all(color: kBorder.withOpacity(0.3)),
                      ),
                      child: Text(arabic,
                          textAlign: TextAlign.right, textDirection: TextDirection.rtl,
                          style: const TextStyle(color: kWhite, fontSize: 19, height: 2.2)),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Container(width: 3, height: 18,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: kCyan)),
                      const SizedBox(width: 8),
                      const Text('ARTINYA:', style: TextStyle(color: kCyan, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity, padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFF141824),
                        border: Border.all(color: kBorder.withOpacity(0.2)),
                      ),
                      child: Text(indo,
                          style: const TextStyle(color: kWhite, fontSize: 14, fontStyle: FontStyle.italic, height: 1.8)),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kCyan.withOpacity(0.5)),
                        color: kCyan.withOpacity(0.08),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.receipt_long_rounded, color: kCyan, size: 14),
                        const SizedBox(width: 6),
                        Text('${source.isNotEmpty ? source : "Muslim"} #$number',
                            style: const TextStyle(color: kCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _handleInvalidSession(String message) async {
  await Future.delayed(const Duration(milliseconds: 300));
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  if (!mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('⚠️ Session Expired', style: TextStyle(color: kWhite)),
      content: Text(message, style: const TextStyle(color: kWhite54)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false),
          child: const Text('OK', style: TextStyle(color: kCyan)),
        ),
      ],
    ),
  );
}

// ── Navigation ────────────────────────────────────────────────────────────
void _onNavTap(int index) {
  setState(() => _navIndex = index);
  if (index == 0) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_newsPageCtrl.hasClients) {
        setState(() { _currentNewsPage = 0.0; _newsPageViewKey++; });
        _newsPageCtrl.jumpToPage(0);
      }
    });
  }
}

void _onDrawerNav(int index) {
  Widget page;
  switch (index) {
    case 1: page = SellerPage(keyToken: sessionKey); break;
    case 2: page = AdminPage(sessionKey: sessionKey); break;
    case 3: page = OwnerPage(sessionKey: sessionKey, username: username); break;
    default: return;
  }
  Navigator.pop(context);
  Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) {
    if (mounted) {
      setState(() => _navIndex = 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_newsPageCtrl.hasClients) {
          setState(() { _currentNewsPage = 0.0; _newsPageViewKey++; });
          _newsPageCtrl.jumpToPage(0);
        }
      });
    }
  });
}

// ── Current Page ──────────────────────────────────────────────────────────
Widget _buildCurrentPage() {
  switch (_navIndex) {
    case 1:
      return HomePage(
        username: username, password: password,
        listBug: listBug, role: role,
        expiredDate: expiredDate, sessionKey: sessionKey,
      );
    case 2:
      return InfoPage(sessionKey: sessionKey);
    case 3:
      return ToolsPage(sessionKey: sessionKey, userRole: role, listDoos: listDoos);
    case 0:
    default:
      return _buildHomePage();
  }
}

// ── HOME PAGE (Dirombak Total) ─────────────────────────────────────────────
Widget _buildHomePage() {
  return ValueListenableBuilder<bool>(
    valueListenable: is3DModeNotifier,
    builder: (context, is3D, _) {
      // JIKA 3D AKTIF
      if (is3D) {
        return Column(
          children: [
            const Expanded(
              child: Interactive3DCube(color: kCyan), // Memenuhi sisa layar
            ),
            _buildToggle3D(), // Tombol toggle di bawah
            const SizedBox(height: 8),
          ],
        );
      }

      // JIKA 3D TIDAK AKTIF (Dashboard Biasa)
      return FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBannerVideo(),
              const SizedBox(height: 16),
              _buildWelcomeCard(),
              const SizedBox(height: 20),
              _buildQuickActionsSection(),
              const SizedBox(height: 20),
              _buildLatestUpdates(),
              const SizedBox(height: 20),
              _buildPrayerSection(),
              const SizedBox(height: 20),
              _buildHadithSection(),
              const SizedBox(height: 24),
              _buildToggle3D(), // Toggle juga muncul di bawah dashboard
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );
}

// ── Toggle 3D (HANYA SATU FUNGSI) ─────────────────────────────────────────
Widget _buildToggle3D() {
  return ValueListenableBuilder<bool>(
    valueListenable: is3DModeNotifier,
    builder: (context, is3D, _) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: is3D ? kCyan.withOpacity(0.1) : kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: is3D ? kCyan : kBorder.withOpacity(0.4),
              width: is3D ? 1.5 : 1.0,
            ),
            boxShadow: is3D 
                ? [BoxShadow(color: kCyan.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    is3D ? Icons.view_in_ar : Icons.grid_view_rounded,
                    color: is3D ? kCyan : kWhite54,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    is3D ? "TAMPILAN 3D AKTIF" : "TAMPILAN BASIC",
                    style: TextStyle(
                      color: is3D ? kCyan : kWhite,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Orbitron',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Switch(
                value: is3D,
                activeColor: kCyan,
                inactiveThumbColor: kWhite54,
                onChanged: (value) {
                  toggle3DMode(value);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ── Banner Video ──────────────────────────────────────────────────────────
Widget _buildBannerVideo() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 190, width: double.infinity,
        color: const Color(0xFF080C12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_menuVideoCtrl != null && _menuVideoCtrl!.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _menuVideoCtrl!.value.size.width,
                  height: _menuVideoCtrl!.value.size.height,
                  child: VideoPlayer(_menuVideoCtrl!),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0A0F1E), Color(0xFF1A1A2E)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                  ],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
              ),
            ),
            const Positioned(
              left: 16, bottom: 14,
              child: Text('X-DARK CRASHER',
                style: TextStyle(
                  color: kWhite, fontSize: 22, fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron', letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Welcome Card ──────────────────────────────────────────────────────────
Widget _buildWelcomeCard() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 24, offset: const Offset(0, 10))
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CustomPaint(painter: _HexagonPatternPainter()),
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: Container(
                      width: 58, height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [Colors.red, Colors.redAccent]),
                        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 16, spreadRadius: 2)],
                      ),
                      child: const Center(child: Icon(Icons.security_rounded, color: kWhite, size: 28)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Welcome Back,',
                            style: TextStyle(color: kWhite54, fontSize: 12, fontFamily: 'Orbitron')),
                        Text(username,
                            style: const TextStyle(
                              color: kWhite, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kCyan.withOpacity(0.5)),
                            color: kCyan.withOpacity(0.08),
                          ),
                          child: Text(role.toUpperCase(),
                              style: const TextStyle(
                                color: kCyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kGreen.withOpacity(0.12),
                      border: Border.all(color: kGreen.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.timer_outlined, color: kGreen, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: kCyan.withOpacity(0.4)),
                  color: kCyan.withOpacity(0.04),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AnimatedDot(color: kCyan),
                    const SizedBox(width: 10),
                    const Text('X-DARK DASHBOARD',
                        style: TextStyle(
                          color: kCyan, fontSize: 11, fontWeight: FontWeight.bold,
                          fontFamily: 'Orbitron', letterSpacing: 1.5)),
                    const SizedBox(width: 10),
                    _AnimatedDot(color: kCyan),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildCircleStatItem(
                      icon: Icons.people_alt_rounded,
                      value: '$onlineUsers',
                      label: 'Online Users',
                      color: kGreen),
                  _buildStatDivider(),
                  _buildCircleStatItem(
                      icon: Icons.link_rounded,
                      value: '$activeConns',
                      label: 'Active Connections',
                      color: kBlue),
                  _buildStatDivider(),
                  _buildCircleStatItem(
                      icon: Icons.calendar_month_rounded,
                      value: expiredDate.length > 10 ? expiredDate.substring(0, 10) : expiredDate,
                      label: 'Expiration',
                      color: kOrange),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kGreen.withOpacity(0.5)),
                      color: kGreen.withOpacity(0.08),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AnimatedDot(color: kGreen),
                        const SizedBox(width: 6),
                        const Text('LIVE',
                            style: TextStyle(
                                color: kGreen, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildCircleStatItem({
  required IconData icon,
  required String value,
  required String label,
  required Color color,
}) {
  return Expanded(
    child: Column(
      children: [
        Container(
          width: 62, height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.18),
            border: Border.all(color: color.withOpacity(0.6), width: 2),
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 14, spreadRadius: 2)],
          ),
          child: Center(child: Icon(icon, color: color, size: 28)),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                color: kWhite, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Orbitron')),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: kWhite54, fontSize: 9), textAlign: TextAlign.center),
      ],
    ),
  );
}

Widget _buildStatDivider() =>
    Container(width: 1, height: 60, color: kBorder.withOpacity(0.5));

// ── Quick Actions ─────────────────────────────────────────────────────────
Widget _buildQuickActionsSection() {
  final actions = [
    _QuickActionData(
      icon: FontAwesomeIcons.whatsapp,
      bgIcon: FontAwesomeIcons.whatsapp,
      title: 'Manage Sender',
      subtitle: 'Manage your active sender',
      gradient: [const Color(0xFFE91E8C), const Color(0xFFAD1457)],
      onTap: () => Navigator.push(
        context,
        _slideRoute(BugSenderPage(sessionKey: sessionKey, username: username, role: role)),
      ).then((_) {
        if (mounted && _newsPageCtrl.hasClients) {
          setState(() { _currentNewsPage = 0.0; _newsPageViewKey++; });
          _newsPageCtrl.jumpToPage(0);
        }
      }),
    ),
    _QuickActionData(
      icon: FontAwesomeIcons.telegram,
      bgIcon: FontAwesomeIcons.telegram,
      title: 'Join Channel',
      subtitle: 'X-Dark Info Channel',
      gradient: [const Color(0xFF00B4D8), const Color(0xFF0077B6)],
      onTap: () => _openUrl('https://t.me/+JZrrQHaB-645OWM1'),
    ),
    _QuickActionData(
      icon: FontAwesomeIcons.bookQuran,
      bgIcon: FontAwesomeIcons.bookQuran,
      title: 'Al Quran',
      subtitle: 'Baca Al-Quran',
      gradient: [const Color(0xFF7C4DFF), const Color(0xFF4A148C)],
      onTap: () => Navigator.push(context, _slideRoute(AlQuranPage())),
    ),
    _QuickActionData(
      icon: FontAwesomeIcons.tv,
      bgIcon: FontAwesomeIcons.tv,
      title: 'Anime',
      subtitle: 'Discover & Watch Anime',
      gradient: [const Color(0xFFFF6D00), const Color(0xFFE65100)],
      onTap: () => Navigator.push(context, _slideRoute(HomeAnimePage())),
    ),
    _QuickActionData(
      icon: FontAwesomeIcons.cartShopping,
      bgIcon: FontAwesomeIcons.cartShopping,
      title: 'Beli Role',
      subtitle: 'Upgrade akun via QRIS',
      gradient: [const Color(0xFF00C853), const Color(0xFF2E7D32)],
      onTap: () => Navigator.push(
        context,
        _slideRoute(BuyRolePage(sessionKey: sessionKey)),
      ).then((_) {
        if (mounted && _newsPageCtrl.hasClients) {
          setState(() { _currentNewsPage = 0.0; _newsPageViewKey++; });
          _newsPageCtrl.jumpToPage(0);
        }
      }),
    ),
  ];

  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: kYellow.withOpacity(0.18),
                border: Border.all(color: kYellow.withOpacity(0.3)),
              ),
              child: const Icon(Icons.bolt_rounded, color: kYellow, size: 22),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('QUICK ACTIONS',
                    style: TextStyle(
                      color: kWhite, fontWeight: FontWeight.bold, fontSize: 15,
                      fontFamily: 'Orbitron', letterSpacing: 1)),
                Text('Beberapa Menu Tambahan',
                    style: TextStyle(color: kWhite54, fontSize: 12)),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: kYellow.withOpacity(0.15),
                border: Border.all(color: kYellow.withOpacity(0.4)),
              ),
              child: Row(children: [
                Container(
                    width: 7, height: 7,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: kYellow)),
                const SizedBox(width: 5),
                const Text('X-DARK',
                    style: TextStyle(color: kYellow, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 180,
        child: PageView.builder(
          controller: _qaPageCtrl,
          itemCount: actions.length,
          onPageChanged: (index) {
            if (mounted) setState(() => _currentQaPage = index.toDouble());
          },
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildQuickActionCard(actions[index]),
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(actions.length, (index) {
          final bool isActive = _currentQaPage.round() == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isActive ? kYellow : Colors.white24,
            ),
          );
        }),
      ),
    ],
  );
}

Widget _buildQuickActionCard(_QuickActionData action) {
  return GestureDetector(
    onTap: action.onTap,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
            colors: action.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(
              color: action.gradient.first.withOpacity(0.4),
              blurRadius: 20, offset: const Offset(0, 8))
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12, bottom: -12,
            child: Icon(action.bgIcon, color: Colors.white.withOpacity(0.08), size: 110),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: Colors.white.withOpacity(0.22)),
                  child: Icon(action.icon, color: kWhite, size: 24),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withOpacity(0.22)),
                    child: const Text('Tap →',
                        style: TextStyle(color: kWhite, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(action.title,
                    style: const TextStyle(
                      color: kWhite, fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'Orbitron')),
                const SizedBox(height: 4),
                Text(action.subtitle,
                    style: TextStyle(color: kWhite.withOpacity(0.8), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Latest Updates ────────────────────────────────────────────────────────
Widget _buildLatestUpdates() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Icon(Icons.dashboard_customize_rounded, color: kOrange, size: 22),
            const SizedBox(width: 8),
            const Text('LATEST UPDATES',
                style: TextStyle(
                  color: kWhite, fontWeight: FontWeight.bold, fontSize: 15,
                  fontFamily: 'Orbitron', letterSpacing: 1)),
            const Spacer(),
            if (newsList.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: kOrange.withOpacity(0.15),
                  border: Border.all(color: kOrange.withOpacity(0.4)),
                ),
                child: Text('${newsList.length} Updates',
                    style: const TextStyle(
                        color: kOrange, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (newsList.isNotEmpty)
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: newsList.length,
            itemBuilder: (ctx, i) => _buildNewsCardHorizontal(newsList[i]),
          ),
        ),
      if (newsList.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: kCard,
                border: Border.all(color: kBorder.withOpacity(0.4))),
            child: const Center(
                child: Text('No updates available', style: TextStyle(color: kWhite54))),
          ),
        ),
    ],
  );
}

Widget _buildNewsCardHorizontal(dynamic item) {
  final imgUrl   = item['image']?.toString() ?? '';
  final title    = item['title']?.toString() ?? 'No Title';
  final date     = item['date']?.toString() ?? item['created_at']?.toString() ?? '';
  final cardWidth = (MediaQuery.of(context).size.width / 2) - 22;

  return Container(
    width: cardWidth,
    margin: const EdgeInsets.only(right: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: kCard,
      border: Border.all(color: kBorder.withOpacity(0.4)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: Stack(
            children: [
              Container(
                height: 110, width: double.infinity, color: kCardAlt,
                child: imgUrl.isNotEmpty
                    ? Image.network(imgUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.image_not_supported, color: kWhite54, size: 30)))
                    : const Center(
                        child: Icon(Icons.article_rounded, color: kWhite54, size: 30)),
              ),
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.black.withOpacity(0.65),
                    border: Border.all(color: kOrange.withOpacity(0.7)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle_notifications_rounded, color: kOrange, size: 10),
                      SizedBox(width: 3),
                      Text('NEW',
                          style: TextStyle(
                              color: kOrange, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: Text(title,
              style: const TextStyle(
                color: kWhite, fontSize: 16, fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron', height: 1.3),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: Row(
            children: [
              const Icon(Icons.access_time_rounded, color: kWhite54, size: 11),
              const SizedBox(width: 4),
              if (date.isNotEmpty)
                Expanded(
                  child: Text(
                      date.length > 10 ? date.substring(0, 10) : date,
                      style: const TextStyle(color: kWhite54, fontSize: 10)),
                ),
                              Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: kOrange.withOpacity(0.18)),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: kOrange, size: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Prayer Section ────────────────────────────────────────────────────────
  Widget _buildPrayerSection() {
    final prayerColors = [
      const Color(0xFF5B4FD4),
      const Color(0xFFFF9800),
      const Color(0xFFFF5722),
      const Color(0xFF1E88E5),
      const Color(0xFF1565C0),
    ];
    final prayerIcons = [
      Icons.nights_stay_rounded,
      Icons.wb_sunny_rounded,
      Icons.cloud_rounded,
      Icons.wb_twilight_rounded,
      Icons.nightlight_round,
    ];
    final prayerKeys = ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: kGreen.withOpacity(0.2),
                    border: Border.all(color: kGreen.withOpacity(0.4)),
                  ),
                  child: const Center(child: Icon(Icons.mosque, color: kGreen, size: 26)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('JADWAL SHOLAT',
                          style: TextStyle(
                            color: kWhite, fontWeight: FontWeight.bold, fontSize: 15,
                            fontFamily: 'Orbitron', letterSpacing: 1)),
                      Text(_prayerCity,
                          style: const TextStyle(color: kWhite54, fontSize: 12)),
                    ],
                  ),
                ),
                // Tombol auto-detect lokasi
                GestureDetector(
                  onTap: _locationLoading ? null : _detectLocationAndFetchPrayer,
                  child: Container(
                    width: 38, height: 38,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _locationGranted
                          ? kGreen.withOpacity(0.2)
                          : kWhite24.withOpacity(0.1),
                      border: Border.all(
                        color: _locationGranted
                            ? kGreen.withOpacity(0.6)
                            : kWhite54.withOpacity(0.3),
                      ),
                    ),
                    child: _locationLoading
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(color: kGreen, strokeWidth: 2),
                          )
                        : Icon(
                            _locationGranted
                                ? Icons.my_location_rounded
                                : Icons.location_searching_rounded,
                            color: _locationGranted ? kGreen : kWhite54,
                            size: 18,
                          ),
                  ),
                ),
                // Tombol ganti manual
                GestureDetector(
                  onTap: _showChangeCityDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: kGreen,
                    ),
                    child: const Row(children: [
                      Icon(Icons.edit_location_alt_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 5),
                      Text('GANTI',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Next prayer badge ──
            if (_nextPrayerLabel.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: kGreen.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    ScaleTransition(
                      scale: _pulseAnim,
                      child: _AnimatedDot(color: kOrange, size: 10),
                    ),
                    const SizedBox(width: 10),
                    Text('Menuju $_nextPrayerLabel : $_nextPrayerTime',
                        style: const TextStyle(
                          color: kWhite, fontSize: 13, fontWeight: FontWeight.w600,
                          fontFamily: 'Orbitron')),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kGreen.withOpacity(0.5)),
                      ),
                      child: const Text('X-DARK',
                          style: TextStyle(color: kGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),

            // ── Prayer time cards ──
            if (_prayerLoading)
              const Center(child: CircularProgressIndicator(color: kGreen, strokeWidth: 2))
            else
              SizedBox(
                height: 118,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: prayerKeys.length,
                  itemBuilder: (ctx, i) {
                    final key   = prayerKeys[i];
                    final time  = _prayerTimes[key] ?? '--:--';
                    final color = prayerColors[i];
                    final icon  = prayerIcons[i];
                    final isNext = key == _nextPrayerLabel;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      margin: EdgeInsets.only(right: 10, bottom: isNext ? 0 : 6, top: isNext ? 0 : 6),
                      width: 105,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: color,
                        boxShadow: [
                          BoxShadow(
                              color: color.withOpacity(isNext ? 0.65 : 0.3),
                              blurRadius: isNext ? 18 : 8, offset: const Offset(0, 4))
                        ],
                        border: isNext
                            ? Border.all(color: Colors.white.withOpacity(0.5), width: 1.5)
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, color: Colors.white, size: 24),
                            const SizedBox(height: 5),
                            Text(key.toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 9,
                                    fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                            const SizedBox(height: 5),
                            Text(time,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 19,
                                    fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Hadith Section ────────────────────────────────────────────────────────
  Widget _buildHadithSection() {
    if (_hadithLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: kCard, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorder.withOpacity(0.5)),
          ),
          child: const Center(child: CircularProgressIndicator(color: kCyan, strokeWidth: 2)),
        ),
      );
    }

    final arabic = _hadith?['data']?['text']?['ar'] ??
        'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى';
    final indo   = _hadith?['data']?['text']?['id'] ??
        'Sesungguhnya setiap amalan tergantung pada niatnya.';
    final number = _hadith?['data']?['id']?.toString() ?? '1';
    final source = _hadith?['data']?['source']?.toString() ?? 'Muslim';
    final grade  = _hadith?['data']?['grade']?.toString() ?? 'Sahih Muslim';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: kCyan.withOpacity(0.18)),
                  child: const Center(child: Icon(Icons.menu_book_rounded, color: kCyan, size: 26)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('HADITH OF THE DAY',
                        style: TextStyle(
                          color: kWhite, fontWeight: FontWeight.bold, fontSize: 15,
                          fontFamily: 'Orbitron', letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text('$grade · Tap card to read full',
                        style: const TextStyle(color: kWhite54, fontSize: 11)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => _showHadithFullDialog(arabic, indo, source, number, grade),
              child: Column(
                children: [
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFF1A1F2E),
                      border: Border.all(color: kBorder.withOpacity(0.3)),
                    ),
                    child: Text(arabic,
                        textAlign: TextAlign.right, textDirection: TextDirection.rtl,
                        style: const TextStyle(color: kWhite, fontSize: 17, height: 2.0)),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14), color: const Color(0xFF141824)),
                    child: Text(indo,
                        style: const TextStyle(
                          color: kWhite54, fontSize: 12, fontStyle: FontStyle.italic, height: 1.7),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kCyan.withOpacity(0.45)),
                    color: kCyan.withOpacity(0.07),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.receipt_long_rounded, color: kCyan, size: 13),
                    const SizedBox(width: 5),
                    Text('${source.isNotEmpty ? source : "Muslim"} #$number',
                        style: const TextStyle(
                            color: kCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                  ]),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _fetchRandomHadith,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kWhite54.withOpacity(0.3)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.touch_app_rounded, color: kWhite54, size: 14),
                      SizedBox(width: 4),
                      Text('Tap card', style: TextStyle(color: kWhite54, fontSize: 11)),
                    ]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      extendBodyBehindAppBar: false,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          _buildBackgroundGrid(),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D1117), Color(0xFF0A0D14)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: KeyedSubtree(
              key: ValueKey(_navIndex),
              child: _buildCurrentPage(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBackgroundGrid() {
    return CustomPaint(
      size: Size.infinite,
      painter: _GridPatternPainter(
        gridColor: kCyan.withOpacity(0.04),
        lineColor: kPink.withOpacity(0.02),
        spacing: 35,
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kBg.withOpacity(0.95),
      elevation: 0,
      iconTheme: const IconThemeData(color: kWhite),
      titleSpacing: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder.withOpacity(0.4))),
        ),
      ),
      title: Row(
        children: [
          const SizedBox(width: 8),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kCyan.withOpacity(0.4)),
              color: kCyan.withOpacity(0.1),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            _slideRoute(ProfilePage(
              username: username, password: password,
              role: role, expiredDate: expiredDate, sessionKey: sessionKey,
            )),
          ).then((_) {
            if (mounted && _newsPageCtrl.hasClients) {
              setState(() { _currentNewsPage = 0.0; _newsPageViewKey++; });
              _newsPageCtrl.jumpToPage(0);
            }
          }),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(username,
                  style: const TextStyle(
                      color: kWhite, fontSize: 13, fontWeight: FontWeight.bold)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(role.toUpperCase(),
                      style: const TextStyle(
                          color: kWhite54, fontSize: 10, fontFamily: 'Orbitron')),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.red.withOpacity(0.2),
                        border: Border.all(color: Colors.red.withOpacity(0.4))),
                    child: Text('Exp: $expiredDate',
                        style: const TextStyle(
                            color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            _slideRoute(ProfilePage(
              username: username, password: password,
              role: role, expiredDate: expiredDate, sessionKey: sessionKey,
            )),
          ),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
              color: Colors.red.withOpacity(0.2),
            ),
            child: ClipOval(
              child: _profileImage != null
                  ? Image.file(_profileImage!, fit: BoxFit.cover)
                  : const Icon(FontAwesomeIcons.userAstronaut, color: Colors.redAccent, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => Navigator.push(context, _slideRoute(const ContactPage())),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.headset_mic_outlined, color: kWhite, size: 24),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Bottom Nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final items = [
      _NavItem(icon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: FontAwesomeIcons.whatsapp, label: 'Bug'),
      _NavItem(icon: Icons.info_outline_rounded, label: 'Info'),
      _NavItem(icon: Icons.build_circle_outlined, label: 'Tools'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: SizedBox(
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final isActive = _navIndex == i;
            return GestureDetector(
              onTap: () => _onNavTap(i),
              child: SizedBox(
                width: 72,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isActive)
                      Container(
                        width: 28, height: 3,
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    Icon(items[i].icon,
                        color: isActive ? Colors.blue : kWhite54, size: 22),
                    const SizedBox(height: 4),
                    Text(items[i].label,
                        style: TextStyle(
                          color: isActive ? Colors.blue : kWhite54,
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        )),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: kBg,
      width: MediaQuery.of(context).size.width * 0.8,
      child: Column(
        children: [
          Container(
            height: 240,
            color: Colors.black,
            child: Stack(
              children: [
                if (_menuVideoCtrl != null && _menuVideoCtrl!.value.isInitialized)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _menuVideoCtrl!.value.size.width,
                        height: _menuVideoCtrl!.value.size.height,
                        child: VideoPlayer(_menuVideoCtrl!),
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.85)],
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: kCyan.withOpacity(0.6), width: 2.5),
                            boxShadow: [BoxShadow(color: kCyan.withOpacity(0.3), blurRadius: 14, spreadRadius: 2)],
                          ),
                          child: ClipOval(
                            child: _profileImage != null
                                ? Image.file(_profileImage!, fit: BoxFit.cover)
                                : const Icon(FontAwesomeIcons.userAstronaut, size: 38, color: kWhite),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(username,
                            style: const TextStyle(
                                color: kWhite, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                        Text(role.toUpperCase(),
                            style: const TextStyle(color: kCyan, fontSize: 12, letterSpacing: 2)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: kBg,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  if (role == 'reseller')
                    _buildDrawerItem(
                        icon: Icons.storefront_rounded,
                        label: 'Seller Page',
                        onTap: () => _onDrawerNav(1)),
                  if (role == 'admin')
                    _buildDrawerItem(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Admin Page',
                        onTap: () => _onDrawerNav(2)),
                  if (role == 'owner')
                    _buildDrawerItem(
                        icon: Icons.workspace_premium_rounded,
                        label: 'Owner Page',
                        onTap: () => _onDrawerNav(3)),
                  _buildDrawerItem(
                    icon: Icons.history_rounded,
                    label: 'Riwayat Aktivitas',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          _slideRoute(RiwayatPage(sessionKey: sessionKey, role: role))).then((_) {
                        if (mounted && _newsPageCtrl.hasClients) {
                          setState(() { _currentNewsPage = 0.0; _newsPageViewKey++; });
                          _newsPageCtrl.jumpToPage(0);
                        }
                      });
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.lock_outline_rounded,
                    label: 'Ganti Password',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        _slideRoute(ChangePasswordPage(username: username, sessionKey: sessionKey)),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildDrawerItem(
                    icon: Icons.logout_rounded,
                    label: 'Keluar',
                    isLogout: true,
                    onTap: () async {
                      Navigator.pop(context);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: isLogout ? Colors.red.withOpacity(0.08) : kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isLogout ? Colors.red.withOpacity(0.3) : kBorder.withOpacity(0.4)),
      ),
      child: ListTile(
        leading: Icon(icon, color: isLogout ? Colors.redAccent : kCyan, size: 20),
        title: Text(label,
            style: TextStyle(
                color: isLogout ? Colors.redAccent : kWhite,
                fontWeight: FontWeight.w600, fontSize: 14)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: kWhite24, size: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: onTap,
      ),
    );
  }
}

// ─── Quick Action Data ─────────────────────────────────────────────────────────
class _QuickActionData {
  final IconData icon;
  final IconData bgIcon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _QuickActionData({
    required this.icon,
    required this.bgIcon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });
}

// ─── Nav Item ─────────────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ─── Slide Route ──────────────────────────────────────────────────────────────
PageRoute _slideRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionDuration: const Duration(milliseconds: 350),
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: FadeTransition(opacity: anim, child: child),
  ),
);

// ─── NewsMedia ────────────────────────────────────────────────────────────────
class NewsMedia extends StatefulWidget {
  final String url;
  const NewsMedia({super.key, required this.url});
  @override
  State<NewsMedia> createState() => _NewsMediaState();
}

class _NewsMediaState extends State<NewsMedia> {
  VideoPlayerController? _ctrl;
  bool _isVideo(String url) =>
      url.endsWith('.mp4') || url.endsWith('.webm') ||
      url.endsWith('.mov') || url.endsWith('.mkv');
  @override
  void initState() {
    super.initState();
    if (_isVideo(widget.url)) {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _ctrl?.setLooping(true);
          _ctrl?.setVolume(0.0);
          _ctrl?.play();
        });
    }
  }
  @override
  void dispose() { _ctrl?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (_isVideo(widget.url)) {
      if (_ctrl != null && _ctrl!.value.isInitialized) {
        return AspectRatio(aspectRatio: _ctrl!.value.aspectRatio, child: VideoPlayer(_ctrl!));
      }
      return const Center(child: CircularProgressIndicator(color: kCyan, strokeWidth: 2));
    }
    return Image.network(
      widget.url, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Container(color: kCard, child: const Icon(Icons.error_rounded, color: kWhite24)),
    );
  }
}