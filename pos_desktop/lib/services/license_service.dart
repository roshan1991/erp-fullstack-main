import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class LicenseService {
  // Use a 32-character key for AES-256. Keep this secret!
  static const String _keyString = 'sathu_sys_erp_secure_key_32bytes'; 
  static const String _licensePrefKey = 'app_license_key';

  /// Retrieves the unique Device ID for the current machine.
  static Future<String> getDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isWindows) {
        WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
        // deviceId is a reasonably unique identifier on Windows.
        return windowsInfo.deviceId.replaceAll('{', '').replaceAll('}', '');
      }
    } catch (e) {
      print("Error getting device ID: $e");
    }
    return 'UNKNOWN_DEVICE';
  }

  /// Attempts to activate the app with a provided license key.
  static Future<bool> activateLicense(String licenseKey) async {
    final isValid = await verifyLicense(licenseKey);
    if (isValid) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_licensePrefKey, licenseKey);
      return true;
    }
    return false;
  }

  /// Checks if the stored license is still valid.
  static Future<bool> isLicenseValid() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_licensePrefKey);
    if (key == null) return false;
    return await verifyLicense(key);
  }

  /// Verifies a license key's signature, expiry, and device binding.
  static Future<bool> verifyLicense(String encryptedKey) async {
    try {
      final key = encrypt.Key.fromUtf8(_keyString);
      // For fixed-IV decryption (not recommended for true security, but standard for simple license keys)
      // We use a fixed IV here so the same payload results in the same key.
      final iv = encrypt.IV.fromUtf8('sathu_sys_iv_vec'); 
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      final decrypted = encrypter.decrypt64(encryptedKey, iv: iv);
      final Map<String, dynamic> data = jsonDecode(decrypted);

      final String expiryStr = data['expiry'];
      final String targetDeviceId = data['deviceId'];
      
      // Check device ID binding
      final currentDeviceId = await getDeviceId();
      if (targetDeviceId != 'ANY' && targetDeviceId != currentDeviceId) {
        return false;
      }

      // Check expiry date
      final expiry = DateTime.parse(expiryStr);
      if (DateTime.now().isAfter(expiry)) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Gets the decrypted details from the stored license.
  static Future<Map<String, dynamic>?> getLicenseDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedKey = prefs.getString(_licensePrefKey);
    if (encryptedKey == null) return null;
    
    try {
      final key = encrypt.Key.fromUtf8(_keyString);
      final iv = encrypt.IV.fromUtf8('sathu_sys_iv_vec');
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final decrypted = encrypter.decrypt64(encryptedKey, iv: iv);
      return jsonDecode(decrypted);
    } catch (_) {
      return null;
    }
  }

  /// Helper to clear license (e.g., for logout or re-activation)
  static Future<void> logoutLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licensePrefKey);
  }
}
