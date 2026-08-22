import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget { const CameraScreen({super.key}); @override State<CameraScreen> createState() => _CameraScreenState(); }
class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller; bool _loading = true; bool _flash = false;
  @override void initState() { super.initState(); _init(); }
  Future<void> _init() async { try { final cams = await availableCameras(); final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first); _controller = CameraController(back, ResolutionPreset.high, enableAudio: false); await _controller!.initialize(); if (mounted) setState(() => _loading = false); } catch (_) { if (mounted) setState(() => _loading = false); } }
  @override void dispose() { _controller?.dispose(); super.dispose(); }
  Future<void> _capture() async { if (_controller == null || !_controller!.value.isInitialized) return; final file = await _controller!.takePicture(); if (mounted) Navigator.pop(context, file.path); }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black, body: Stack(fit: StackFit.expand, children: [if (_controller?.value.isInitialized == true) CameraPreview(_controller!) else const Center(child: CircularProgressIndicator()), SafeArea(child: Column(children: [Align(alignment: Alignment.topLeft, child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white))), const Spacer(), Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 30), color: Colors.white54), const Spacer(), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [IconButton(onPressed: () async { setState(() => _flash = !_flash); await _controller?.setFlashMode(_flash ? FlashMode.torch : FlashMode.off); }, icon: Icon(_flash ? Icons.flash_on : Icons.flash_off, color: Colors.white)), GestureDetector(onTap: _capture, child: Container(width: 78, height: 78, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5)), child: Container(margin: const EdgeInsets.all(6), decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)))), const SizedBox(width: 48)]), const SizedBox(height: 28)])), if (_loading) const SizedBox.shrink()]));
}
