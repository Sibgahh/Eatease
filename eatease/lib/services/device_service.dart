import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static const String _deviceIdKey = 'device_id';
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  // Get a unique device ID
  Future<String> getDeviceId() async {
    // Try to get the device ID from SharedPreferences first
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);
    
    // If no device ID is stored, generate a new one and store it
    if (deviceId == null) {
      deviceId = const Uuid().v4(); // Generate a UUID v4
      await prefs.setString(_deviceIdKey, deviceId);
    }
    
    return deviceId;
  }
  
  // Get device name information
  Future<String> getDeviceName() async {
    try {
      if (kIsWeb) {
        return "Web Browser";
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return '${iosInfo.name} ${iosInfo.model}';
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        return 'Windows ${windowsInfo.computerName}';
      } else if (Platform.isMacOS) {
        final macOsInfo = await _deviceInfo.macOsInfo;
        return 'macOS ${macOsInfo.computerName}';
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfo.linuxInfo;
        return 'Linux ${linuxInfo.name}';
      } else {
        return 'Unknown Device';
      }
    } catch (e) {
      print('Error getting device info: $e');
      return 'Unknown Device';
    }
  }
  
  // Get both ID and name as a map
  Future<Map<String, String>> getDeviceInfo() async {
    final String deviceId = await getDeviceId();
    final String deviceName = await getDeviceName();
    
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
    };
  }
} 