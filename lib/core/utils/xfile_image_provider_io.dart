import 'dart:io' show File;

import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';

/// Mobile: XFile.path is a filesystem path — use FileImage.
ImageProvider xfileImageProvider(XFile file) => FileImage(File(file.path));
