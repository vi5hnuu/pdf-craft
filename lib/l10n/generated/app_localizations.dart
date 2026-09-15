import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'PDF Craft'**
  String get appName;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get languageHindi;

  /// No description provided for @switchLanguageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch language'**
  String get switchLanguageTooltip;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @seeMore.
  ///
  /// In en, this message translates to:
  /// **'See more'**
  String get seeMore;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @applyATool.
  ///
  /// In en, this message translates to:
  /// **'Apply a tool'**
  String get applyATool;

  /// No description provided for @outputFileName.
  ///
  /// In en, this message translates to:
  /// **'Output File Name'**
  String get outputFileName;

  /// No description provided for @actionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get actionOpen;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// No description provided for @actionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get actionSettings;

  /// No description provided for @errSomethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errSomethingWrong;

  /// No description provided for @pageNumber.
  ///
  /// In en, this message translates to:
  /// **'Page {number}'**
  String pageNumber(int number);

  /// No description provided for @savedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String savedTo(String path);

  /// No description provided for @failedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String failedToSave(String error);

  /// No description provided for @navFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get navFiles;

  /// No description provided for @navTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get navTools;

  /// No description provided for @navScanner.
  ///
  /// In en, this message translates to:
  /// **'Scanner'**
  String get navScanner;

  /// No description provided for @navCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get navCloud;

  /// No description provided for @rateTitle.
  ///
  /// In en, this message translates to:
  /// **'Enjoying PDF Craft?'**
  String get rateTitle;

  /// No description provided for @rateBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ve processed several files! If you find this app useful, please take a moment to rate it — it helps a lot.'**
  String get rateBody;

  /// No description provided for @rateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get rateLater;

  /// No description provided for @rateNow.
  ///
  /// In en, this message translates to:
  /// **'Rate Now'**
  String get rateNow;

  /// No description provided for @filesRecentFiles.
  ///
  /// In en, this message translates to:
  /// **'Recent Files'**
  String get filesRecentFiles;

  /// No description provided for @filesMyStorage.
  ///
  /// In en, this message translates to:
  /// **'My Storage'**
  String get filesMyStorage;

  /// No description provided for @storageInternal.
  ///
  /// In en, this message translates to:
  /// **'Internal Storage'**
  String get storageInternal;

  /// No description provided for @storageDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get storageDownloads;

  /// No description provided for @storageDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get storageDocuments;

  /// No description provided for @storageProcessed.
  ///
  /// In en, this message translates to:
  /// **'Processed Files'**
  String get storageProcessed;

  /// No description provided for @errStoragePermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Storage permission is needed to browse your files'**
  String get errStoragePermissionNeeded;

  /// No description provided for @noRecentFiles.
  ///
  /// In en, this message translates to:
  /// **'No recent files'**
  String get noRecentFiles;

  /// No description provided for @toolsAllTools.
  ///
  /// In en, this message translates to:
  /// **'All Tools'**
  String get toolsAllTools;

  /// No description provided for @toolsCount.
  ///
  /// In en, this message translates to:
  /// **'({count})'**
  String toolsCount(int count);

  /// No description provided for @toolsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tools'**
  String get toolsSearchHint;

  /// No description provided for @toolsNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No tools found'**
  String get toolsNoneFound;

  /// No description provided for @toolsRecentlyUsed.
  ///
  /// In en, this message translates to:
  /// **'Recently used'**
  String get toolsRecentlyUsed;

  /// No description provided for @toolAddedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'{name} added to favorites'**
  String toolAddedToFavorites(String name);

  /// No description provided for @toolRemovedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'{name} removed from favorites'**
  String toolRemovedFromFavorites(String name);

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Document Scanner'**
  String get scanTitle;

  /// No description provided for @scanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan physical documents with your camera or import from gallery.'**
  String get scanSubtitle;

  /// No description provided for @scanToPdf.
  ///
  /// In en, this message translates to:
  /// **'Scan to PDF'**
  String get scanToPdf;

  /// No description provided for @scanToPdfDesc.
  ///
  /// In en, this message translates to:
  /// **'Creates a multi-page PDF from scanned pages.'**
  String get scanToPdfDesc;

  /// No description provided for @scanToJpeg.
  ///
  /// In en, this message translates to:
  /// **'Scan to JPEG'**
  String get scanToJpeg;

  /// No description provided for @scanToJpegDesc.
  ///
  /// In en, this message translates to:
  /// **'Saves each page as a separate JPEG image.'**
  String get scanToJpegDesc;

  /// No description provided for @scanTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: You can import from your gallery as well as scan with the camera.'**
  String get scanTip;

  /// No description provided for @scanPdfDocument.
  ///
  /// In en, this message translates to:
  /// **'Scanned PDF Document'**
  String get scanPdfDocument;

  /// No description provided for @scanImagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 scanned image} other{{count} scanned images}}'**
  String scanImagesCount(int count);

  /// No description provided for @scanSavePdf.
  ///
  /// In en, this message translates to:
  /// **'Save PDF'**
  String get scanSavePdf;

  /// No description provided for @scanMergeToPdf.
  ///
  /// In en, this message translates to:
  /// **'Merge to PDF'**
  String get scanMergeToPdf;

  /// No description provided for @scanPdfReady.
  ///
  /// In en, this message translates to:
  /// **'Scanned PDF ready'**
  String get scanPdfReady;

  /// No description provided for @scanTapToPreview.
  ///
  /// In en, this message translates to:
  /// **'Tap to preview • Press “Save PDF” to save'**
  String get scanTapToPreview;

  /// No description provided for @scanCancelledOrFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan cancelled or failed'**
  String get scanCancelledOrFailed;

  /// No description provided for @scanImagesMerged.
  ///
  /// In en, this message translates to:
  /// **'Images merged to PDF'**
  String get scanImagesMerged;

  /// No description provided for @scanCreatingPdf.
  ///
  /// In en, this message translates to:
  /// **'Creating your PDF'**
  String get scanCreatingPdf;

  /// No description provided for @googleDrive.
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get googleDrive;

  /// No description provided for @driveSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed'**
  String get driveSignInFailed;

  /// No description provided for @driveLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load Drive files'**
  String get driveLoadFailed;

  /// No description provided for @driveUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded to Google Drive'**
  String get driveUploaded;

  /// No description provided for @driveUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String driveUploadFailed(String error);

  /// No description provided for @driveDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded to processed folder'**
  String get driveDownloaded;

  /// No description provided for @driveDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String driveDownloadFailed(String error);

  /// No description provided for @driveCouldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Could not open: {error}'**
  String driveCouldNotOpen(String error);

  /// No description provided for @driveCouldNotFetch.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch file: {error}'**
  String driveCouldNotFetch(String error);

  /// No description provided for @driveNoToolsForType.
  ///
  /// In en, this message translates to:
  /// **'No tools available for this file type'**
  String get driveNoToolsForType;

  /// No description provided for @driveShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Share failed: {error}'**
  String driveShareFailed(String error);

  /// No description provided for @driveUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get driveUploading;

  /// No description provided for @driveUploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload File'**
  String get driveUploadFile;

  /// No description provided for @driveConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect Google Drive'**
  String get driveConnect;

  /// No description provided for @driveConnectBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to upload, download and manage your Drive files.'**
  String get driveConnectBody;

  /// No description provided for @driveSignInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get driveSignInWithGoogle;

  /// No description provided for @driveStorageUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total} used'**
  String driveStorageUsed(String used, String total);

  /// No description provided for @driveNoFiles.
  ///
  /// In en, this message translates to:
  /// **'No files in your Drive'**
  String get driveNoFiles;

  /// No description provided for @driveNoFilesOfType.
  ///
  /// In en, this message translates to:
  /// **'No {type} found'**
  String driveNoFilesOfType(String type);

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get filterPdf;

  /// No description provided for @filterPdfs.
  ///
  /// In en, this message translates to:
  /// **'PDFs'**
  String get filterPdfs;

  /// No description provided for @filterImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get filterImages;

  /// No description provided for @filterDocs.
  ///
  /// In en, this message translates to:
  /// **'Docs'**
  String get filterDocs;

  /// No description provided for @filterDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get filterDocuments;

  /// No description provided for @filterOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get filterOther;

  /// No description provided for @searchFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Search files'**
  String get searchFilesHint;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get searching;

  /// No description provided for @noMatchingFiles.
  ///
  /// In en, this message translates to:
  /// **'No matching files'**
  String get noMatchingFiles;

  /// No description provided for @filesFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file found} other{{count} files found}}'**
  String filesFound(int count);

  /// No description provided for @resultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get resultsTitle;

  /// No description provided for @resultsClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear results'**
  String get resultsClearTitle;

  /// No description provided for @resultsClearBody.
  ///
  /// In en, this message translates to:
  /// **'Delete all {count} output files? This cannot be undone.'**
  String resultsClearBody(int count);

  /// No description provided for @resultsCleared.
  ///
  /// In en, this message translates to:
  /// **'Results cleared'**
  String get resultsCleared;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @resultsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No results yet'**
  String get resultsEmpty;

  /// No description provided for @resultsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Files you create with any tool will appear here for quick access.'**
  String get resultsEmptyBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
