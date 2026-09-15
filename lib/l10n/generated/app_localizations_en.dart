// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'PDF Craft';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get switchLanguageTooltip => 'Switch language';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get gotIt => 'Got it';

  @override
  String get refresh => 'Refresh';

  @override
  String get signOut => 'Sign out';

  @override
  String get loading => 'Loading…';

  @override
  String get unknown => 'Unknown';

  @override
  String get discard => 'Discard';

  @override
  String get seeMore => 'See more';

  @override
  String get favorites => 'Favorites';

  @override
  String get recent => 'Recent';

  @override
  String get applyATool => 'Apply a tool';

  @override
  String get outputFileName => 'Output File Name';

  @override
  String get actionOpen => 'Open';

  @override
  String get actionSave => 'Save';

  @override
  String get actionShare => 'Share';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionSettings => 'Settings';

  @override
  String get errSomethingWrong => 'Something went wrong';

  @override
  String pageNumber(int number) {
    return 'Page $number';
  }

  @override
  String savedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String failedToSave(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get navFiles => 'Files';

  @override
  String get navTools => 'Tools';

  @override
  String get navScanner => 'Scanner';

  @override
  String get navCloud => 'Cloud';

  @override
  String get rateTitle => 'Enjoying PDF Craft?';

  @override
  String get rateBody =>
      'You\'ve processed several files! If you find this app useful, please take a moment to rate it — it helps a lot.';

  @override
  String get rateLater => 'Later';

  @override
  String get rateNow => 'Rate Now';

  @override
  String get filesRecentFiles => 'Recent Files';

  @override
  String get filesMyStorage => 'My Storage';

  @override
  String get storageInternal => 'Internal Storage';

  @override
  String get storageDownloads => 'Downloads';

  @override
  String get storageDocuments => 'Documents';

  @override
  String get storageProcessed => 'Processed Files';

  @override
  String get errStoragePermissionNeeded =>
      'Storage permission is needed to browse your files';

  @override
  String get noRecentFiles => 'No recent files';

  @override
  String get toolsAllTools => 'All Tools';

  @override
  String toolsCount(int count) {
    return '($count)';
  }

  @override
  String get toolsSearchHint => 'Search tools';

  @override
  String get toolsNoneFound => 'No tools found';

  @override
  String get toolsRecentlyUsed => 'Recently used';

  @override
  String toolAddedToFavorites(String name) {
    return '$name added to favorites';
  }

  @override
  String toolRemovedFromFavorites(String name) {
    return '$name removed from favorites';
  }

  @override
  String get scanTitle => 'Document Scanner';

  @override
  String get scanSubtitle =>
      'Scan physical documents with your camera or import from gallery.';

  @override
  String get scanToPdf => 'Scan to PDF';

  @override
  String get scanToPdfDesc => 'Creates a multi-page PDF from scanned pages.';

  @override
  String get scanToJpeg => 'Scan to JPEG';

  @override
  String get scanToJpegDesc => 'Saves each page as a separate JPEG image.';

  @override
  String get scanTip =>
      'Tip: You can import from your gallery as well as scan with the camera.';

  @override
  String get scanPdfDocument => 'Scanned PDF Document';

  @override
  String scanImagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scanned images',
      one: '1 scanned image',
    );
    return '$_temp0';
  }

  @override
  String get scanSavePdf => 'Save PDF';

  @override
  String get scanMergeToPdf => 'Merge to PDF';

  @override
  String get scanPdfReady => 'Scanned PDF ready';

  @override
  String get scanTapToPreview => 'Tap to preview • Press “Save PDF” to save';

  @override
  String get scanCancelledOrFailed => 'Scan cancelled or failed';

  @override
  String get scanImagesMerged => 'Images merged to PDF';

  @override
  String get scanCreatingPdf => 'Creating your PDF';

  @override
  String get googleDrive => 'Google Drive';

  @override
  String get driveSignInFailed => 'Sign-in failed';

  @override
  String get driveLoadFailed => 'Failed to load Drive files';

  @override
  String get driveUploaded => 'Uploaded to Google Drive';

  @override
  String driveUploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get driveDownloaded => 'Downloaded to processed folder';

  @override
  String driveDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String driveCouldNotOpen(String error) {
    return 'Could not open: $error';
  }

  @override
  String driveCouldNotFetch(String error) {
    return 'Could not fetch file: $error';
  }

  @override
  String get driveNoToolsForType => 'No tools available for this file type';

  @override
  String driveShareFailed(String error) {
    return 'Share failed: $error';
  }

  @override
  String get driveUploading => 'Uploading…';

  @override
  String get driveUploadFile => 'Upload File';

  @override
  String get driveConnect => 'Connect Google Drive';

  @override
  String get driveConnectBody =>
      'Sign in to upload, download and manage your Drive files.';

  @override
  String get driveSignInWithGoogle => 'Sign in with Google';

  @override
  String driveStorageUsed(String used, String total) {
    return '$used of $total used';
  }

  @override
  String get driveNoFiles => 'No files in your Drive';

  @override
  String driveNoFilesOfType(String type) {
    return 'No $type found';
  }

  @override
  String get filterAll => 'All';

  @override
  String get filterPdf => 'PDF';

  @override
  String get filterPdfs => 'PDFs';

  @override
  String get filterImages => 'Images';

  @override
  String get filterDocs => 'Docs';

  @override
  String get filterDocuments => 'Documents';

  @override
  String get filterOther => 'Other';

  @override
  String get searchFilesHint => 'Search files';

  @override
  String get searching => 'Searching…';

  @override
  String get noMatchingFiles => 'No matching files';

  @override
  String filesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files found',
      one: '1 file found',
    );
    return '$_temp0';
  }

  @override
  String get resultsTitle => 'Results';

  @override
  String get resultsClearTitle => 'Clear results';

  @override
  String resultsClearBody(int count) {
    return 'Delete all $count output files? This cannot be undone.';
  }

  @override
  String get resultsCleared => 'Results cleared';

  @override
  String get clearAll => 'Clear all';

  @override
  String get resultsEmpty => 'No results yet';

  @override
  String get resultsEmptyBody =>
      'Files you create with any tool will appear here for quick access.';
}
