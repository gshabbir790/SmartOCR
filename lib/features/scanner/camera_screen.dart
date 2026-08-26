import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _loading = true;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      _controller = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await _controller!.initialize();
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final file = await _controller!.takePicture();
    if (mounted) Navigator.pop(context, file.path);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller?.value.isInitialized == true)
              CameraPreview(_controller!)
            else
              const Center(child: CircularProgressIndicator(color: Colors.white)),
            if (_controller?.value.isInitialized == true) const _ScanFrame(),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  if (_controller?.value.isInitialized == true)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 18),
                      child: Text(
                        'Align the document within the frame',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: () async {
                          setState(() => _flash = !_flash);
                          await _controller?.setFlashMode(_flash ? FlashMode.torch : FlashMode.off);
                        },
                        icon: Icon(_flash ? Icons.flash_on : Icons.flash_off, color: Colors.white),
                      ),
                      GestureDetector(
                        onTap: _capture,
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5)),
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      );
}

/// A document-alignment guide: a dimmed area outside a centered rounded
/// rectangle with corner brackets, the way most scanner apps show where to
/// position the page. Replaces what used to be a single unexplained line
/// across the middle of the preview.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frameWidth = constraints.maxWidth * 0.86;
        final frameHeight = constraints.maxHeight * 0.6;
        return IgnorePointer(
          child: Center(
            child: Container(
              width: frameWidth,
              height: frameHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: CustomPaint(painter: _CornerBracketsPainter()),
            ),
          ),
        );
      },
    );
  }
}

class _CornerBracketsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 26.0;
    const r = 18.0;

    void corner(Offset origin, bool right, bool bottom) {
      final dx = right ? -1.0 : 1.0;
      final dy = bottom ? -1.0 : 1.0;
      final path = Path()
        ..moveTo(origin.dx, origin.dy + dy * (len + r))
        ..lineTo(origin.dx, origin.dy + dy * r)
        ..quadraticBezierTo(origin.dx, origin.dy, origin.dx + dx * r, origin.dy)
        ..moveTo(origin.dx + dx * r, origin.dy)
        ..lineTo(origin.dx + dx * (len + r), origin.dy);
      canvas.drawPath(path, paint);
    }

    corner(const Offset(0, 0), false, false);
    corner(Offset(size.width, 0), true, false);
    corner(Offset(0, size.height), false, true);
    corner(Offset(size.width, size.height), true, true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
