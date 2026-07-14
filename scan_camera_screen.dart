import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../../../../core/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../data/services/snap_solve_service.dart';
import '../widgets/scan_progress_dialog.dart';
import '../widgets/upgrade_dialog.dart';
import 'scan_result_screen.dart';

class ScanCameraScreen extends StatefulWidget {
  const ScanCameraScreen({super.key});

  @override
  State<ScanCameraScreen> createState() => _ScanCameraScreenState();
}

class _ScanCameraScreenState extends State<ScanCameraScreen> with WidgetsBindingObserver {
  final SnapSolveService _service = SnapSolveService();
  final ImagePicker _imagePicker = ImagePicker();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  bool _isProcessing = false;
  bool _permissionGranted = false;
  bool _isFlashOn = false;

  File? _capturedImage;
  ui.Rect? _detectedDocRect;
  bool _showCropOverlay = false;
  List<Offset>? _cornerPoints;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (!await _requestCameraPermission()) {
      _showPermissionDeniedDialog();
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showNoCameraDialog();
        return;
      }

      _selectedCameraIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

      await _setupCameraController(_selectedCameraIndex);
      _permissionGranted = true;
      if (mounted) setState(() {});
    } catch (e) {
      _showError('Failed to initialize camera: $e');
    }
  }

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<void> _setupCameraController(int index) async {
    final camera = _cameras[index];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    await _cameraController!.setFlashMode(FlashMode.off);
    if (mounted) setState(() {});
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Camera Permission Required'),
        content: const Text('Please grant camera access to use Snap & Solve.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showNoCameraDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('No Camera Found'),
        content: const Text('No camera is available on this device.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final highResController = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );

      await highResController.initialize();
      await highResController.setFlashMode(FlashMode.off);

      final XFile picture = await highResController.takePicture();
      final File imageFile = File(picture.path);

      await highResController.dispose();

      final detectedRect = await _detectDocument(imageFile);

      if (detectedRect != null) {
        setState(() {
          _detectedDocRect = detectedRect;
          _showCropOverlay = true;
          _capturedImage = imageFile;
          _cornerPoints = _rectToCorners(detectedRect);
        });
      } else {
        setState(() {
          _capturedImage = imageFile;
          _showCropOverlay = false;
        });
        await _processImage(imageFile);
      }
    } catch (e) {
      _showError('Failed to capture: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _pickFromGallery() {
    _pickImageOrUpload(source: ImageSource.gallery);
  }

  void _uploadImage() {
    _pickImageOrUpload(source: ImageSource.gallery);
  }

  Future<void> _pickImageOrUpload({required ImageSource source}) async {
    if (_isProcessing) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isFreeTier) {
      final count = await _service.getScansTodayCount();
      if (count >= 5) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => UpgradeDialog(
            title: 'Daily Limit Reached',
            description: 'Free users get 5 scans per day. Upgrade to IlmAI Pro for unlimited scans.',
            featureName: 'Snap & Solve',
            onUpgrade: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            onCancel: () => Navigator.pop(context),
          ),
        );
        return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (image != null && mounted) {
        final imageFile = File(image.path);
        final detectedRect = await _detectDocument(imageFile);

        if (detectedRect != null) {
          setState(() {
            _detectedDocRect = detectedRect;
            _showCropOverlay = true;
            _capturedImage = imageFile;
            _cornerPoints = _rectToCorners(detectedRect);
          });
        } else {
          setState(() {
            _capturedImage = imageFile;
            _showCropOverlay = false;
          });
          await _processImage(imageFile);
        }
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  List<Offset> _rectToCorners(ui.Rect rect) {
    return [
      Offset(rect.left, rect.top),
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.bottom),
      Offset(rect.left, rect.bottom),
    ];
  }

  Future<ui.Rect?> _detectDocument(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      final scale = math.min(800 / image.width, 800 / image.height);
      final resized = scale < 1 ? img.copyResize(image, width: (image.width * scale).round()) : image;

      final gray = img.grayscale(resized);
      final blurred = img.gaussianBlur(gray, radius: 3);
      final edges = _sobelEdgeDetection(blurred);
      final contours = _findContours(edges);
      if (contours.isEmpty) return null;

      for (final contour in contours) {
        final approx = _approximatePolygon(contour, 0.02 * math.max(resized.width, resized.height));
        if (approx.length == 4) {
          final rect = _boundingRect(approx);
          if (rect.width > resized.width * 0.25 && rect.height > resized.height * 0.25) {
            final scaleX = image.width / resized.width;
            final scaleY = image.height / resized.height;
            return ui.Rect.fromLTRB(
              rect.left * scaleX,
              rect.top * scaleY,
              rect.right * scaleX,
              rect.bottom * scaleY,
            );
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  List<List<math.Point<int>>> _findContours(img.Image edges) {
    final visited = <String, bool>{};
    final contours = <List<math.Point<int>>>[];
    const directions = [
      math.Point(-1, 0), math.Point(1, 0), math.Point(0, -1), math.Point(0, 1),
      math.Point(-1, -1), math.Point(-1, 1), math.Point(1, -1), math.Point(1, 1),
    ];

    for (int y = 0; y < edges.height; y++) {
      for (int x = 0; x < edges.width; x++) {
        final pixel = edges.getPixel(x, y);
        if (pixel.r > 128 && !visited.containsKey('$x,$y')) {
          final contour = <math.Point<int>>[];
          final stack = [math.Point(x, y)];

          while (stack.isNotEmpty) {
            final p = stack.removeLast();
            final key = '${p.x},${p.y}';
            if (visited[key] == true) continue;
            if (p.x < 0 || p.x >= edges.width || p.y < 0 || p.y >= edges.height) continue;

            final px = edges.getPixel(p.x, p.y);
            if (px.r <= 128) continue;

            visited[key] = true;
            contour.add(p);

            for (final d in directions) {
              stack.add(math.Point(p.x + d.x, p.y + d.y));
            }
          }

          if (contour.length > 50) {
            contours.add(contour);
          }
        }
      }
    }

    contours.sort((a, b) => b.length.compareTo(a.length));
    return contours;
  }

  List<math.Point<int>> _approximatePolygon(List<math.Point<int>> contour, double epsilon) {
    if (contour.length < 3) return contour;

    double maxDist = 0;
    int index = 0;
    final start = contour.first;
    final end = contour.last;

    for (int i = 1; i < contour.length - 1; i++) {
      final dist = _perpendicularDistance(contour[i], start, end);
      if (dist > maxDist) {
        maxDist = dist;
        index = i;
      }
    }

    if (maxDist > epsilon) {
      final left = _approximatePolygon(contour.sublist(0, index + 1), epsilon);
      final right = _approximatePolygon(contour.sublist(index), epsilon);
      return [...left, ...right.skip(1)];
    }

    return [start, end];
  }

  double _perpendicularDistance(math.Point<int> point, math.Point<int> start, math.Point<int> end) {
    final num = (end.y - start.y) * point.x - (end.x - start.x) * point.y + end.x * start.y - end.y * start.x;
    return num.abs() / _distance(start, end);
  }

  double _distance(math.Point<int> a, math.Point<int> b) {
    return math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));
  }

  ui.Rect _boundingRect(List<math.Point<int>> points) {
    int minX = points.first.x, maxX = points.first.x;
    int minY = points.first.y, maxY = points.first.y;
    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    return ui.Rect.fromLTRB(minX.toDouble(), minY.toDouble(), maxX.toDouble(), maxY.toDouble());
  }

  img.Image _sobelEdgeDetection(img.Image image) {
    final width = image.width;
    final height = image.height;
    final output = img.Image(width: width, height: height);

    const kernelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];
    const kernelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        double gx = 0, gy = 0;
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final val = (pixel.r + pixel.g + pixel.b) / 3.0;
            gx += val * kernelX[ky + 1][kx + 1];
            gy += val * kernelY[ky + 1][kx + 1];
          }
        }
        final magnitude = math.sqrt(gx * gx + gy * gy).clamp(0, 255).toInt();
        output.setPixelRgba(x, y, magnitude, magnitude, magnitude, 255);
      }
    }
    return output;
  }

  Future<void> _processCroppedImage() async {
    if (_capturedImage == null || _cornerPoints == null || _cornerPoints!.length != 4) return;

    setState(() => _isProcessing = true);

    try {
      final bytes = await _capturedImage!.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('Failed to decode image');

      final rect = _detectedDocRect!;
      final corrected = img.copyCrop(
        image,
        x: rect.left.toInt(),
        y: rect.top.toInt(),
        width: rect.width.toInt(),
        height: rect.height.toInt(),
      );

      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/scanned_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(img.encodeJpg(corrected, quality: 95));

      await _processImage(outputFile);
    } catch (e) {
      _showError('Failed to process: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _processImage(File imageFile) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (auth.isFreeTier) {
      final count = await _service.getScansTodayCount();
      if (count >= 5) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => UpgradeDialog(
            title: 'Daily Limit Reached',
            description: 'Free users get 5 scans per day. Upgrade to IlmAI Pro for unlimited scans.',
            featureName: 'Snap & Solve',
            onUpgrade: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            onCancel: () => Navigator.pop(context),
          ),
        );
        return;
      }
    }

    ScanProgressDialog.show(context, initialMessage: 'Uploading image...');

    try {
      ScanProgressDialog.updateMessage(context, 'Uploading image...');
      final imageUrl = await _service.uploadImage(imageFile);

      ScanProgressDialog.updateMessage(context, 'Analyzing with AI...');
      final result = await _service.analyzeImage(imageUrl, imageFile);

      ScanProgressDialog.updateMessage(context, 'Saving solution...');
      final solution = await _service.saveSolution(
        imageUrl: imageUrl,
        extractedText: result['extractedText'] ?? '',
        aiSolution: result['aiSolution'] ?? '',
        subject: result['subject'] ?? 'General',
      );

      if (!mounted) return;
      ScanProgressDialog.hide(context);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ScanResultScreen(solution: solution)),
      ).then((_) => _resetCamera());
    } catch (e) {
      if (mounted) {
        ScanProgressDialog.hide(context);
        _showError('Failed to process: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _resetCamera() {
    setState(() {
      _capturedImage = null;
      _detectedDocRect = null;
      _showCropOverlay = false;
      _cornerPoints = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _permissionGranted && _cameraController != null && _cameraController!.value.isInitialized
          ? _buildCameraView()
          : _buildLoadingView(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text('Initializing camera...', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    final size = MediaQuery.of(context).size;
    final cameraPreview = CameraPreview(_cameraController!);

    final children = <Widget>[
      Positioned.fill(child: cameraPreview),

      if (_showCropOverlay && _detectedDocRect != null && _cornerPoints != null)
        _buildDocOverlay(size),

      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _IconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              _IconButton(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onPressed: _uploadImage,
              ),
            ],
          ),
        ),
      ),

      if (!_isProcessing && _capturedImage == null)
        _buildBottomControls()
      else
        const SizedBox.shrink(),

      if (_isProcessing)
        const Center(child: CircularProgressIndicator(color: AppColors.primary))
      else
        const SizedBox.shrink(),

      if (_capturedImage != null && !_isProcessing)
        _buildPreviewActions(),
    ];

    return Stack(children: children);
  }

  Widget _buildDocOverlay(Size screenSize) {
    if (_detectedDocRect == null || _cornerPoints == null) return const SizedBox.shrink();

    final rect = _detectedDocRect!;
    final scaleX = screenSize.width / _cameraController!.value.previewSize!.width;
    final scaleY = screenSize.height / _cameraController!.value.previewSize!.height;

    return Stack(
      children: [
        Container(color: Colors.black.withValues(alpha: 0.3)),
        CustomPaint(
          painter: _DocOverlayPainter(
            rect: ui.Rect.fromLTRB(
              rect.left * scaleX,
              rect.top * scaleY,
              rect.right * scaleX,
              rect.bottom * scaleY,
            ),
            cornerPoints: _cornerPoints!,
          ),
        ),
        if (_cornerPoints != null)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: CustomPaint(
                painter: _CornerHandlesPainter(
                  corners: _cornerPoints!,
                  onDrag: _onCornerDrag,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _onCornerDrag(int index, Offset newPosition) {
    if (_cornerPoints == null || index >= _cornerPoints!.length) return;

    setState(() {
      _cornerPoints![index] = newPosition;
      final dx = _cornerPoints!.map((p) => p.dx).toList();
      final dy = _cornerPoints!.map((p) => p.dy).toList();
      _detectedDocRect = ui.Rect.fromLTRB(
        dx.reduce(math.min),
        dy.reduce(math.min),
        dx.reduce(math.max),
        dy.reduce(math.max),
      );
    });
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  if (auth.isFreeTier) {
                    return FutureBuilder<int>(
                      future: _service.getScansTodayCount(),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: count >= 5 ? Colors.red.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                count >= 5 ? Icons.lock_rounded : Icons.flash_on_rounded,
                                color: count >= 5 ? Colors.red : AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Scans today: $count/5',
                                style: TextStyle(
                                  color: count >= 5 ? Colors.red : AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _IconButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onPressed: _uploadImage,
                  ),

                  const SizedBox(width: 32),

                  GestureDetector(
                    onTap: _takePicture,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF0F2460)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.5),
                            blurRadius: 25,
                            spreadRadius: 3,
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 36),
                    ),
                  ),

                  const SizedBox(width: 32),
                ],
              ),

              const SizedBox(height: 16),
              Text(
                'Align document in frame',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewActions() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    _capturedImage!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.delete_rounded,
                      label: 'Retake',
                      color: Colors.red,
                      onPressed: _resetCamera,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.auto_fix_high_rounded,
                      label: _showCropOverlay ? 'Crop & Solve' : 'Solve',
                      color: AppColors.primary,
                      onPressed: _showCropOverlay ? _processCroppedImage : () => _processImage(_capturedImage!),
                      isLoading: _isProcessing,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onPressed;

  const _IconButton({required this.icon, this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: label != null ? 70 : 44,
        height: label != null ? 70 : 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: label == null ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: label != null ? BorderRadius.circular(16) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: label != null ? 28 : 24),
            if (label != null) ...[
              const SizedBox(height: 4),
              Text(label!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icon, size: 22),
      label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: color.withValues(alpha: 0.4),
      ),
    );
  }
}

class _DocOverlayPainter extends CustomPainter {
  final ui.Rect rect;
  final List<Offset>? cornerPoints;

  _DocOverlayPainter({required this.rect, this.cornerPoints});

  @override
  void paint(Canvas canvas, Size size) {
    final cornerPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cornerLength = 35.0;

    if (cornerPoints != null && cornerPoints!.length == 4) {
      for (int i = 0; i < 4; i++) {
        final corner = cornerPoints![i];
        if (i == 0) {
          canvas.drawLine(corner, corner + Offset(cornerLength, 0), cornerPaint);
          canvas.drawLine(corner, corner + Offset(0, cornerLength), cornerPaint);
        } else if (i == 1) {
          canvas.drawLine(corner, corner + Offset(-cornerLength, 0), cornerPaint);
          canvas.drawLine(corner, corner + Offset(0, cornerLength), cornerPaint);
        } else if (i == 2) {
          canvas.drawLine(corner, corner + Offset(-cornerLength, 0), cornerPaint);
          canvas.drawLine(corner, corner + Offset(0, -cornerLength), cornerPaint);
        } else if (i == 3) {
          canvas.drawLine(corner, corner + Offset(cornerLength, 0), cornerPaint);
          canvas.drawLine(corner, corner + Offset(0, -cornerLength), cornerPaint);
        }
      }
    } else {
      final corners = [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft];
      for (int i = 0; i < 4; i++) {
        final corner = corners[i];
        if (i == 0) {
          canvas.drawLine(corner, corner + Offset(cornerLength, 0), cornerPaint);
          canvas.drawLine(corner, corner + Offset(0, cornerLength), cornerPaint);
        } else if (i == 1) {
          canvas.drawLine(corner, corner + Offset(-cornerLength, 0), cornerPaint);
          canvas.drawLine(corner, corner + Offset(0, cornerLength), cornerPaint);
        } else if (i == 2) {
          canvas.drawLine(corner, corner + Offset(-cornerLength, 0), cornerPaint);
          canvas.drawLine(corner, corner + Offset(0, -cornerLength), cornerPaint);
        } else if (i == 3) {
          canvas.drawLine(corner, corner + Offset(cornerLength, 0), cornerPaint);
          canvas.drawLine(corner, corner + Offset(0, -cornerLength), cornerPaint);
        }
      }
    }

    final path = Path()
      ..addRect(ui.Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)));
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.5)..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerHandlesPainter extends CustomPainter {
  final List<Offset> corners;
  final Function(int, Offset) onDrag;

  _CornerHandlesPainter({required this.corners, required this.onDrag});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < corners.length; i++) {
      final corner = corners[i];
      final paint = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawCircle(corner, 18, paint);
      canvas.drawCircle(corner, 18, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}