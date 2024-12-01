class Constants {
  static const String baseUrl = "http://localhost:8082/api/v1";
  static const String rootStoragePath = "storage/emulated/0";
  static const String downloadsStoragePath =
      '${Constants.rootStoragePath}/Download';
  static const String documentsStoragePath =
      '${Constants.rootStoragePath}/Documents';

  static const List<String> excludedPaths = [
    // System directories (restricted by OS)
    '/system',
    '/vendor',
    '/proc',
    '/sys',
    '/dev',
    '/data',
    '/cache',
    '/storage/self',
    '/storage/secure',

    // Common Android directories that are unnecessary for search
    '/storage/emulated/0/Android', // App-specific files
    '/storage/emulated/0/DCIM/.thumbnails', // Thumbnail cache
    '/storage/emulated/0/Android/data', // App private data
    '/storage/emulated/0/Android/obb', // Game data
    '/storage/emulated/0/WhatsApp', // WhatsApp data (optional)
    '/storage/emulated/0/Tencent', // Tencent app data (optional)
    '/storage/emulated/0/.Trash', // Trash or recycle bin
  ];

  static bool isHiddenFileOrDir(String path) {
    return path.split('/').any((segment) => segment.startsWith('.'));
  }
}
