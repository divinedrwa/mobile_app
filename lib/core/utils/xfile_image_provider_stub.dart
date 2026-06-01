import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';

/// Web: XFile.path is a blob URL — use NetworkImage.
ImageProvider xfileImageProvider(XFile file) => NetworkImage(file.path);
