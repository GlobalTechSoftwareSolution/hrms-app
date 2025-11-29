import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../../services/api_service.dart';
import '../../utils/location_utils.dart';

class FaceScanAttendanceScreen extends StatefulWidget {
  final String attendanceType; // 'office' or 'work'

  const FaceScanAttendanceScreen({super.key, required this.attendanceType});

  @override
  State<FaceScanAttendanceScreen> createState() =>
      _FaceScanAttendanceScreenState();
}

class _FaceScanAttendanceScreenState extends State<FaceScanAttendanceScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isScanning = false;
  bool _isLoading = false;
  double _scanProgress = 0.0;
  Position? _position;
  String? _message;
  String? _messageType; // 'success', 'error', 'warning'
  late AnimationController _animationController;
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Initialize with safe values
    _scanProgress = 0.0;

    // Start animation only when the widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.repeat();
      }
    });

    _initializeCamera();
    _getLocation();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userEmail = prefs.getString('user_email') ?? '';
    });
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showMessage('No camera found', 'error');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Camera initialization error: $e');
      _showMessage('Cannot access camera', 'error');
    }
  }

  Future<void> _getLocation() async {
    try {
      final position = await LocationUtils.getCurrentLocation(context);

      if (position != null) {
        setState(() {
          _position = position;
        });
        _showMessage('Location acquired successfully', 'success');
      } else {
        _showMessage(
          'Unable to get location. Please check permissions and GPS.',
          'error',
        );
      }
    } catch (e) {
      print('Location error: $e');
      _showMessage('Unable to get location', 'error');
    }
  }

  void _showMessage(String text, String type) {
    setState(() {
      _message = text;
      _messageType = type;
    });
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _message = null;
          _messageType = null;
        });
      }
    });
  }

  Future<void> _captureAndUpload() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showMessage('Camera not ready', 'error');
      return;
    }

    // Ensure we have location before proceeding
    if (_position == null) {
      _showMessage('Getting location...', 'warning');
      // Try to get location again
      await _getLocation();

      // Check again
      if (_position == null) {
        return;
      }
    }

    // Reset state safely
    if (mounted) {
      setState(() {
        _isScanning = true;
        _scanProgress = 0.0;
      });
    }

    // Use a more efficient animation approach
    const totalDuration = 2000; // 2 seconds
    const interval = 50; // 50ms
    final totalSteps = totalDuration ~/ interval;
    final progressIncrement = 1.0 / totalSteps;

    // Use a single timer with counter instead of setState in each tick
    int step = 0;
    Timer.periodic(const Duration(milliseconds: interval), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      step++;
      final newProgress = (progressIncrement * step).clamp(0.0, 1.0);

      setState(() {
        _scanProgress = newProgress;
      });

      if (newProgress >= 1.0) {
        timer.cancel();
        _uploadAttendance();
      }
    });
  }

  Future<void> _uploadAttendance() async {
    try {
      setState(() => _isLoading = true);

      await _cameraController!.takePicture();

      // Fetch employee profile picture
      final apiService = ApiService();
      Map<String, dynamic>? empData;
      try {
        final empResponse = await apiService.get(
          '/accounts/employees/${Uri.encodeComponent(_userEmail)}/',
        );
        if (empResponse['success']) {
          empData = empResponse['data'];
        }
      } catch (e) {
        print('Could not fetch employee info: $e');
      }

      // Create multipart request
      final endpoint = widget.attendanceType == 'office'
          ? '/accounts/office_attendance/'
          : '/accounts/work_attendance/';

      final uri = Uri.parse('${ApiService.baseUrl}$endpoint');
      final request = http.MultipartRequest('POST', uri);

      request.fields['email'] = _userEmail;
      request.fields['latitude'] = _position!.latitude.toString();
      request.fields['longitude'] = _position!.longitude.toString();

      // Attach profile image if available
      if (empData != null && empData['profile_picture'] != null) {
        final profilePicUrl = empData['profile_picture'].toString();
        if (profilePicUrl.isNotEmpty &&
            (profilePicUrl.startsWith('http://') ||
                profilePicUrl.startsWith('https://'))) {
          try {
            final imgResponse = await http.get(Uri.parse(profilePicUrl));
            if (imgResponse.statusCode == 200) {
              request.files.add(
                http.MultipartFile.fromBytes(
                  'image',
                  imgResponse.bodyBytes,
                  filename: 'profile.jpeg',
                ),
              );
            }
          } catch (e) {
            print('Could not attach profile picture: $e');
          }
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage('✅ Attendance marked successfully!', 'success');
        // Wait 2 seconds then go back
        Timer(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context, true);
        });
      } else {
        _showMessage('Failed to mark attendance', 'error');
      }
    } catch (e) {
      print('Upload error: $e');
      _showMessage('Error: ${e.toString()}', 'error');
    } finally {
      setState(() {
        _isScanning = false;
        _isLoading = false;
        _scanProgress = 0.0;
      });
    }
  }

  @override
  void dispose() {
    // Stop all animations and clean up resources
    _isScanning = false;
    _animationController.stop();
    _animationController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Face Recognition Attendance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.attendanceType == 'office'
                              ? 'Office Attendance'
                              : 'Workplace Attendance',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Camera Feed
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Camera preview
                      if (_isCameraInitialized && _cameraController != null)
                        CameraPreview(_cameraController!)
                      else
                        const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),

                      // Face detection circle (when not scanning)
                      if (!_isScanning && _isCameraInitialized)
                        Center(
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.25),
                                  blurRadius: 60,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Scanning overlay
                      if (_isScanning) _buildScanningOverlay(),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Location info
            if (_position != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '📍 ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Message
            if (_message != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _messageType == 'success'
                      ? Colors.green.shade700
                      : _messageType == 'error'
                      ? Colors.red.shade700
                      : Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _message!,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 16),

            // Mark Attendance Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isScanning || _isLoading)
                      ? null
                      : _captureAndUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    disabledBackgroundColor: Colors.grey.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                  ),
                  child: Text(
                    _isScanning
                        ? 'Scanning Face... ${(_scanProgress * 100).toInt()}%'
                        : _isLoading
                        ? 'Processing...'
                        : 'Mark Attendance',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return RepaintBoundary(
      child: Stack(
        children: [
          // Radial gradient background - simplified for performance
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Colors.blue.withOpacity(0.15), Colors.transparent],
                stops: const [0.0, 0.7],
              ),
            ),
          ),

          // Hexagonal wireframe - simplified for performance
          Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final opacity = 0.3 + (_animationController.value * 0.3);
                return Opacity(
                  opacity: opacity.isNaN ? 0.3 : opacity.clamp(0.0, 1.0),
                  child: CustomPaint(
                    size: const Size(200, 200),
                    willChange: true,
                    isComplex: true,
                    painter: HexagonPainter(),
                  ),
                );
              },
            ),
          ),

          // Rotating ring - simplified for performance
          Center(
            child: RotationTransition(
              turns: _animationController,
              child: CustomPaint(
                size: const Size(240, 240),
                willChange: true,
                isComplex: true,
                painter: RingPainter(),
              ),
            ),
          ),

          // Scanning lines
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: ScanLinePainter(_scanProgress),
          ),

          // Corner brackets
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                children: [
                  _buildCornerBracket(Alignment.topLeft),
                  _buildCornerBracket(Alignment.topRight),
                  _buildCornerBracket(Alignment.bottomLeft),
                  _buildCornerBracket(Alignment.bottomRight),
                ],
              ),
            ),
          ),

          // Progress indicator
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.5)),
              ),
              child: Text(
                '${(_scanProgress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerBracket(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: 0.8 - (_animationController.value * 0.4),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border(
                  top: alignment.y < 0
                      ? const BorderSide(color: Colors.white, width: 3)
                      : BorderSide.none,
                  bottom: alignment.y > 0
                      ? const BorderSide(color: Colors.white, width: 3)
                      : BorderSide.none,
                  left: alignment.x < 0
                      ? const BorderSide(color: Colors.white, width: 3)
                      : BorderSide.none,
                  right: alignment.x > 0
                      ? const BorderSide(color: Colors.white, width: 3)
                      : BorderSide.none,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Custom painters
class HexagonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Validate size to prevent NaN errors
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5; // Slightly thinner for better performance

    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius =
        (size.width / 2) * 0.9; // Slightly smaller to prevent overflow

    // Pre-calculate points for better performance
    final points = List<Offset>.generate(7, (i) {
      final angle = (i * 60) * (3.14159 / 180);
      return Offset(
        centerX + radius * cos(angle),
        centerY + radius * sin(angle),
      );
    });

    // Draw the hexagon
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Optimize drawing
    canvas.save();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Validate size to prevent NaN errors
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = Colors.blue
          .withOpacity(0.7) // Slightly more transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          1.5 // Slightly thinner for better performance
      ..isAntiAlias = true; // Smoother edges

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw dashed circle
    const dashWidth = 6.0;
    const dashSpace = 10.0;
    double startAngle = 0;

    while (startAngle < 360) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle * 3.14159 / 180,
        dashWidth * 3.14159 / 180,
        false,
        paint,
      );
      startAngle += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ScanLinePainter extends CustomPainter {
  final double progress;

  ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..strokeWidth = 2;

    // Horizontal scan line
    final y = size.height * progress;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);

    // Vertical scan line
    final x = size.width * progress;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
  }

  @override
  bool shouldRepaint(ScanLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

double cos(double angle) => (angle == 0)
    ? 1
    : (angle == 90 || angle == 270)
    ? 0
    : (angle == 180)
    ? -1
    : 0;
double sin(double angle) => (angle == 0 || angle == 180)
    ? 0
    : (angle == 90)
    ? 1
    : (angle == 270)
    ? -1
    : 0;
