import 'package:flutter/material.dart';

/// Web placeholder — camera-based QR scanning is not available on web.
class GuardQrScanScreen extends StatelessWidget {
  const GuardQrScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'QR scanning is not available on web.\nPlease use the mobile app.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
