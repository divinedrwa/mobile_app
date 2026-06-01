import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../ui/guard_tokens.dart';

/// Full-screen QR / barcode scanner — vibration + sound on decode.
///
/// Pops with decoded string (`Navigator.pop(raw)`), else null if closed without scan.
class GuardQrScanScreen extends StatefulWidget {
  const GuardQrScanScreen({super.key});

  @override
  State<GuardQrScanScreen> createState() => _GuardQrScanScreenState();
}

class _GuardQrScanScreenState extends State<GuardQrScanScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();

  bool _handled = false;
  bool _torchOn = false;
  bool _showSuccess = false;
  late AnimationController _scanLineCtrl;
  late Animation<double> _scanLineAnim;

  @override
  void initState() {
    super.initState();
    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _scanLineAnim = CurvedAnimation(
      parent: _scanLineCtrl,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final bars = capture.barcodes;
    if (bars.isEmpty) return;
    final raw = bars.first.rawValue;
    if (raw == null || raw.trim().isEmpty) return;

    _handled = true;
    await _controller.stop();
    _scanLineCtrl.stop();
    unawaited(HapticFeedback.heavyImpact());
    unawaited(SystemSound.play(SystemSoundType.click));

    if (!mounted) return;
    setState(() => _showSuccess = true);

    // Brief success flash before popping
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.62),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.82),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(GuardTokens.padScreen),
              child: LayoutBuilder(
                builder: (context, box) {
                  final side = min(
                    box.maxWidth - 48,
                    box.maxHeight * 0.45,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Close',
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.14),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                          const Expanded(
                            child: Text(
                              'Scan QR',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.14),
                              foregroundColor: Colors.white,
                            ),
                            tooltip: 'Toggle flashlight',
                            onPressed: () async {
                              await _controller.toggleTorch();
                              setState(() => _torchOn = !_torchOn);
                            },
                            icon: Icon(
                              _torchOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            width: side,
                            height: side,
                            child: _showSuccess
                                ? _SuccessOverlay(side: side)
                                : _ScanFrame(
                                    side: side,
                                    scanLineAnim: _scanLineAnim,
                                  ),
                          ),
                        ),
                      ),
                      Text(
                        'Good lighting scans faster.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: GuardTokens.caption,
                        ),
                      ),
                      const SizedBox(height: GuardTokens.g2),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.94),
                          foregroundColor: GuardTokens.textPrimary,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              GuardTokens.radiusButton,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Close scanner'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated scan frame with a moving scan line.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame({required this.side, required this.scanLineAnim});

  final double side;
  final Animation<double> scanLineAnim;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Corner brackets
        Positioned.fill(
          child: CustomPaint(
            painter: _CornerBracketPainter(
              color: Colors.white.withValues(alpha: 0.92),
              strokeWidth: 3,
              cornerLength: 28,
              radius: GuardTokens.radiusLg,
            ),
          ),
        ),
        // Animated scan line
        AnimatedBuilder(
          animation: scanLineAnim,
          builder: (context, child) {
            return Positioned(
              left: 12,
              right: 12,
              top: 12 + (side - 24) * scanLineAnim.value,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      GuardTokens.success.withValues(alpha: 0.85),
                      GuardTokens.success.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.2, 0.8, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: GuardTokens.success.withValues(alpha: 0.35),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Center hint text
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Hold steady\ninside frame',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: GuardTokens.body,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Success flash overlay on decode.
class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay({required this.side});

  final double side;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GuardTokens.radiusLg),
        border: Border.all(
          color: GuardTokens.success,
          width: 3,
        ),
        color: GuardTokens.success.withValues(alpha: 0.12),
      ),
      child: const Center(
        child: Icon(
          Icons.check_circle_rounded,
          size: 64,
          color: GuardTokens.success,
        ),
      ),
    );
  }
}

/// Paints corner brackets (L-shapes) at the four corners of the scan frame.
class _CornerBracketPainter extends CustomPainter {
  _CornerBracketPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double cornerLength;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final cl = cornerLength;

    // Top-left
    canvas.drawLine(Offset(0, cl), Offset(0, radius), paint);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, radius * 2, radius * 2),
      3.14159, // pi
      1.5708, // pi/2
      false,
      paint,
    );
    canvas.drawLine(Offset(radius, 0), Offset(cl, 0), paint);

    // Top-right
    canvas.drawLine(Offset(w - cl, 0), Offset(w - radius, 0), paint);
    canvas.drawArc(
      Rect.fromLTWH(w - radius * 2, 0, radius * 2, radius * 2),
      -1.5708, // -pi/2
      1.5708,
      false,
      paint,
    );
    canvas.drawLine(Offset(w, radius), Offset(w, cl), paint);

    // Bottom-right
    canvas.drawLine(Offset(w, h - cl), Offset(w, h - radius), paint);
    canvas.drawArc(
      Rect.fromLTWH(w - radius * 2, h - radius * 2, radius * 2, radius * 2),
      0,
      1.5708,
      false,
      paint,
    );
    canvas.drawLine(Offset(w - radius, h), Offset(w - cl, h), paint);

    // Bottom-left
    canvas.drawLine(Offset(cl, h), Offset(radius, h), paint);
    canvas.drawArc(
      Rect.fromLTWH(0, h - radius * 2, radius * 2, radius * 2),
      1.5708,
      1.5708,
      false,
      paint,
    );
    canvas.drawLine(Offset(0, h - radius), Offset(0, h - cl), paint);
  }

  @override
  bool shouldRepaint(_CornerBracketPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      cornerLength != oldDelegate.cornerLength;
}
