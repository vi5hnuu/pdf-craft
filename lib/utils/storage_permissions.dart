import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class StoragePermissions {
  /// Android SDK level, cached. It cannot change while the app runs, and the router's global
  /// redirect asks for permission state on every navigation — querying DeviceInfoPlugin each
  /// time was pure overhead.
  static int? _sdkInt;

  static Future<int> _sdk() async =>
      _sdkInt ??= (await DeviceInfoPlugin().androidInfo).version.sdkInt;

  /// First Android release where public storage needs "All files access".
  ///
  /// Scoped storage and MANAGE_EXTERNAL_STORAGE both arrive in API 30, not 33. The checks below
  /// branched at 33, so Android 11 and 12 took the legacy Permission.storage path — and the
  /// manifest caps WRITE_EXTERNAL_STORAGE at maxSdkVersion 32 while requestLegacyExternalStorage
  /// is only honoured on 29. So on those two releases the app asked for a permission that grants
  /// nothing, writes to /storage/emulated/0/ilvPdf could not succeed, and every result quietly
  /// landed in app-private storage instead.
  static const int _scopedStorageSdk = 30;

  static Future<bool> requestStoragePermissions() async {
    if (await isStoragePermissionGranted()) return true;

    if (await _sdk() >= _scopedStorageSdk) {
      final re = await Permission.manageExternalStorage.request();
      return re.isGranted;
    } else {
      final res = await Permission.storage.request();
      return res.isGranted;
    }
  }

  static Future<bool> isStoragePermissionGranted() async {
    if (await _sdk() >= _scopedStorageSdk) {
      return await Permission.manageExternalStorage.isGranted;
    } else {
      return await Permission.storage.isGranted;
    }
  }

  /// True when the OS will no longer show the request dialog, so the only way to
  /// grant is via system Settings.
  static Future<bool> isPermanentlyDenied() async {
    if (await _sdk() >= _scopedStorageSdk) {
      return await Permission.manageExternalStorage.isPermanentlyDenied;
    } else {
      return await Permission.storage.isPermanentlyDenied;
    }
  }
}
