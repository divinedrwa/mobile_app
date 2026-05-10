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

class _GuardQrScanScreenState extends State<GuardQrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();

  bool _handled = false;
  bool _torchOn = false;

  @override
  void dispose() {
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
    unawaited(HapticFeedback.heavyImpact());
    unawaited(SystemSound.play(SystemSoundType.click));

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
                              backgroundColor: Colors.white.withValues(alpha: 0.14),
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
                              backgroundColor: Colors.white.withValues(alpha: 0.14),
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
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(GuardTokens.radiusLg),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  width: 2,
                                ),
                              ),
                              child: Align(
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
                          backgroundColor: Colors.white.withValues(alpha: 0.94),
                          foregroundColor: GuardTokens.textPrimary,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(GuardTokens.radiusButton),
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
