import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/design_haptics.dart';
import '../ui/guard_tokens.dart';
import 'guard_voice_parser.dart';

/// Takes a photo of a number plate and reads the registration number on the
/// phone (no upload). Returns null if cancelled or nothing readable was found.
Future<String?> scanVehiclePlate(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final XFile? shot;
  try {
    shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
  } catch (_) {
    messenger.showSnackBar(const SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('Camera not available. Type the number instead.'),
    ));
    return null;
  }
  if (shot == null) return null;

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(shot.path));
    // Try each line first (a plate is usually one line), then the whole text.
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final plate = vehicleFromText(_fixOcr(line.text));
        if (plate != null) {
          DesignHaptics.success();
          return plate;
        }
      }
    }
    final plate = vehicleFromText(_fixOcr(result.text));
    if (plate != null) {
      DesignHaptics.success();
      return plate;
    }
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: GuardTokens.warning,
      content: const Text("Couldn't read the plate. Move closer or type it."),
    ));
    return null;
  } catch (_) {
    messenger.showSnackBar(const SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text("Couldn't read the plate. Type the number instead."),
    ));
    return null;
  } finally {
    await recognizer.close();
  }
}

/// Common plate misreads: "IND" strip text, and O/0, I/1 confusion is left to
/// the regex (letters and digits are position-checked there).
String _fixOcr(String text) =>
    text.toUpperCase().replaceAll(RegExp(r'\bIND\b'), ' ').replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ');

/// Camera button for a vehicle-number field's suffix.
class GuardPlateScanButton extends StatelessWidget {
  const GuardPlateScanButton({super.key, required this.onPlate, this.enabled = true});

  final ValueChanged<String> onPlate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Scan number plate',
      onPressed: !enabled
          ? null
          : () async {
              final plate = await scanVehiclePlate(context);
              if (plate != null) onPlate(plate);
            },
      icon: Icon(Icons.document_scanner_outlined, color: GuardTokens.guardAccentDeep),
    );
  }
}
