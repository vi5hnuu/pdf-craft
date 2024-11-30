import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class StoragePermissions {
  static Future<bool> requestPermissions() async {
    if(await Permission.storage.isGranted) return true;

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo build=await deviceInfo.androidInfo;

    if(build.version.sdkInt>=33){
      var re=await Permission.manageExternalStorage.request();
      return re.isGranted;
    }else{
      var res=await Permission.storage.request();
      return res.isGranted;
    }


    // Check if storage permission is already granted (for Android 9 and below)
    if (await Permission.storage.isGranted) {
      return true;
    }

    // If storage permission is permanently denied, ask user to enable it manually
    if (await Permission.storage.isPermanentlyDenied) {
      openAppSettings(); // Direct user to enable manually
      return false;
    }

    // Request storage permission (for Android 9 and below)
    var status = await Permission.storage.request();
    if (status.isGranted) {
      return true;
    }

    // For Android 11+ (API 30 and above), request MANAGE_EXTERNAL_STORAGE permission
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    // For Android 11+, check if the user needs to be prompted for MANAGE_EXTERNAL_STORAGE
    if (await Permission.manageExternalStorage.isDenied) {
      var manageStorageStatus = await Permission.manageExternalStorage.request();
      if (manageStorageStatus.isGranted) {
        return true;
      }
    }

    return false; // Permissions not granted
  }
}
