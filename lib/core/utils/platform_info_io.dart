import 'dart:io' show Platform;

bool get isAndroid => Platform.isAndroid;
bool get isIOS => Platform.isIOS;
bool get isWeb => false;
Map<String, String> get platformEnvironment => Platform.environment;
