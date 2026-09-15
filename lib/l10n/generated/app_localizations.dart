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

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Your complete PDF toolkit'**
  String get splashTagline;

  /// No description provided for @onbTitle1.
  ///
  /// In en, this message translates to:
  /// **'All Your PDF Tools'**
  String get onbTitle1;

  /// No description provided for @onbBody1.
  ///
  /// In en, this message translates to:
  /// **'Merge, split, rotate, compress, reorder, and much more — everything you need for PDFs in one place.'**
  String get onbBody1;

  /// No description provided for @onbTitle2.
  ///
  /// In en, this message translates to:
  /// **'Scan & Convert'**
  String get onbTitle2;

  /// No description provided for @onbBody2.
  ///
  /// In en, this message translates to:
  /// **'Scan physical documents with your camera and instantly convert images to PDFs.'**
  String get onbBody2;

  /// No description provided for @onbTitle3.
  ///
  /// In en, this message translates to:
  /// **'Organize Your Files'**
  String get onbTitle3;

  /// No description provided for @onbBody3.
  ///
  /// In en, this message translates to:
  /// **'Browse your storage, bookmark favorites, and access recently opened files — all from one screen.'**
  String get onbBody3;

  /// No description provided for @onbSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onbSkip;

  /// No description provided for @onbNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onbNext;

  /// No description provided for @onbGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onbGetStarted;

  /// No description provided for @permTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow file access'**
  String get permTitle;

  /// No description provided for @permBody.
  ///
  /// In en, this message translates to:
  /// **'PDF Craft works with the PDFs and images already on your device. Grant file access so you can browse, open and save your documents.'**
  String get permBody;

  /// No description provided for @permBenefitBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse & open your PDFs and images'**
  String get permBenefitBrowse;

  /// No description provided for @permBenefitSave.
  ///
  /// In en, this message translates to:
  /// **'Save tool results back to your storage'**
  String get permBenefitSave;

  /// No description provided for @permBenefitPrivate.
  ///
  /// In en, this message translates to:
  /// **'Files stay on your device until you use a tool'**
  String get permBenefitPrivate;

  /// No description provided for @permTurnedOff.
  ///
  /// In en, this message translates to:
  /// **'Access was turned off. Enable “All files access” (or Storage) for PDF Craft in system Settings.'**
  String get permTurnedOff;

  /// No description provided for @permRequesting.
  ///
  /// In en, this message translates to:
  /// **'Requesting…'**
  String get permRequesting;

  /// No description provided for @permOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get permOpenSettings;

  /// No description provided for @permAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow access'**
  String get permAllow;

  /// No description provided for @permDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get permDenied;

  /// No description provided for @errGenericTitle.
  ///
  /// In en, this message translates to:
  /// **'Something Went Wrong'**
  String get errGenericTitle;

  /// No description provided for @errGenericBody.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try going back.'**
  String get errGenericBody;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @actionView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get actionView;

  /// No description provided for @openExternally.
  ///
  /// In en, this message translates to:
  /// **'Open externally'**
  String get openExternally;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsEmailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Email not verified — tap to verify'**
  String get settingsEmailNotVerified;

  /// No description provided for @settingsManageAccount.
  ///
  /// In en, this message translates to:
  /// **'Manage your account'**
  String get settingsManageAccount;

  /// No description provided for @settingsSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save your credits & sync across devices'**
  String get settingsSignInPrompt;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsSectionStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsSectionStorage;

  /// No description provided for @settingsProcessedFolder.
  ///
  /// In en, this message translates to:
  /// **'Processed Files Folder'**
  String get settingsProcessedFolder;

  /// No description provided for @settingsProcessedSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} files · {size} · tap to view'**
  String settingsProcessedSummary(int count, String size);

  /// No description provided for @settingsPasswordHints.
  ///
  /// In en, this message translates to:
  /// **'Password Hints'**
  String get settingsPasswordHints;

  /// No description provided for @settingsPasswordHintsSub.
  ///
  /// In en, this message translates to:
  /// **'Saved hints for protected PDFs'**
  String get settingsPasswordHintsSub;

  /// No description provided for @settingsSectionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Data'**
  String get settingsSectionPrivacy;

  /// No description provided for @settingsPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Tools run on our secure server so results are identical on every device. Files are sent over an encrypted (HTTPS) connection, processed, and removed afterwards — we don\'t keep your documents.'**
  String get settingsPrivacyBody;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'PDF & Image toolkit'**
  String get settingsAboutSubtitle;

  /// No description provided for @settingsAppIntro.
  ///
  /// In en, this message translates to:
  /// **'App Intro'**
  String get settingsAppIntro;

  /// No description provided for @settingsAppIntroSub.
  ///
  /// In en, this message translates to:
  /// **'Replay the welcome walkthrough'**
  String get settingsAppIntroSub;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsClearProcessedTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Processed Files'**
  String get settingsClearProcessedTitle;

  /// No description provided for @settingsClearProcessedBody.
  ///
  /// In en, this message translates to:
  /// **'Delete all {count} files in the processed folder?'**
  String settingsClearProcessedBody(int count);

  /// No description provided for @settingsProcessedCleared.
  ///
  /// In en, this message translates to:
  /// **'Processed files cleared'**
  String get settingsProcessedCleared;

  /// No description provided for @settingsPasswordHintsCleared.
  ///
  /// In en, this message translates to:
  /// **'Password hints cleared'**
  String get settingsPasswordHintsCleared;

  /// No description provided for @authCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authCreateTitle;

  /// No description provided for @authSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authSignInTitle;

  /// No description provided for @authCreateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your credits safe and sync across devices.'**
  String get authCreateSubtitle;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your PDF Craft account.'**
  String get authSignInSubtitle;

  /// No description provided for @authNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get authNameOptional;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get authInvalidEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authPasswordMin.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get authPasswordMin;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOr;

  /// No description provided for @authContinueGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueGoogle;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get authHaveAccount;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get authNoAccount;

  /// No description provided for @authCreateOne.
  ///
  /// In en, this message translates to:
  /// **'Create one'**
  String get authCreateOne;

  /// No description provided for @authGuestNote.
  ///
  /// In en, this message translates to:
  /// **'You can keep using PDF Craft as a guest.'**
  String get authGuestNote;

  /// No description provided for @authAccountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created — check your email to verify.'**
  String get authAccountCreated;

  /// No description provided for @authSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in.'**
  String get authSignedIn;

  /// No description provided for @authSomethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authSomethingWrong;

  /// No description provided for @authVerifyFirstTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email first'**
  String get authVerifyFirstTitle;

  /// No description provided for @authVerifyFirstBody.
  ///
  /// In en, this message translates to:
  /// **'Your email isn’t verified yet. We can resend the verification link to {email} — open it, tap “Verify email”, then sign in again.'**
  String authVerifyFirstBody(String email);

  /// No description provided for @yourEmail.
  ///
  /// In en, this message translates to:
  /// **'your email'**
  String get yourEmail;

  /// No description provided for @authResendLink.
  ///
  /// In en, this message translates to:
  /// **'Resend link'**
  String get authResendLink;

  /// No description provided for @authSignedInGoogle.
  ///
  /// In en, this message translates to:
  /// **'Signed in with Google.'**
  String get authSignedInGoogle;

  /// No description provided for @authGoogleFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed.'**
  String get authGoogleFailed;

  /// No description provided for @authSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to your account?'**
  String get authSwitchTitle;

  /// No description provided for @authSwitchCredits.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You have 1 credit as a guest.} other{You have {count} credits as a guest.}}'**
  String authSwitchCredits(int count);

  /// No description provided for @authSwitchBody.
  ///
  /// In en, this message translates to:
  /// **'Signing in switches to your existing account and these guest credits won\'t carry over.\n\nTip: choose “Create account” instead to keep them.'**
  String get authSwitchBody;

  /// No description provided for @authSignInAnyway.
  ///
  /// In en, this message translates to:
  /// **'Sign in anyway'**
  String get authSignInAnyway;

  /// No description provided for @authEnterEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter your email above first.'**
  String get authEnterEmailFirst;

  /// No description provided for @authCheckEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get authCheckEmailTitle;

  /// No description provided for @authResetSentBody.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for {email}, we’ve sent a password-reset link. Open it to choose a new password, then come back and sign in.'**
  String authResetSentBody(String email);

  /// No description provided for @authResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send reset email. Please try again.'**
  String get authResetFailed;

  /// No description provided for @authLegalPrefix.
  ///
  /// In en, this message translates to:
  /// **'By creating an account you agree to our '**
  String get authLegalPrefix;

  /// No description provided for @authLegalTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get authLegalTerms;

  /// No description provided for @authLegalAnd.
  ///
  /// In en, this message translates to:
  /// **' & '**
  String get authLegalAnd;

  /// No description provided for @authLegalPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authLegalPrivacy;

  /// No description provided for @authLegalSuffix.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get authLegalSuffix;

  /// No description provided for @accountGuestTitle.
  ///
  /// In en, this message translates to:
  /// **'You’re using PDF Craft as a guest'**
  String get accountGuestTitle;

  /// No description provided for @accountGuestBody.
  ///
  /// In en, this message translates to:
  /// **'Create a free account to keep your credits safe and sync across devices.'**
  String get accountGuestBody;

  /// No description provided for @accountCreateOrSignIn.
  ///
  /// In en, this message translates to:
  /// **'Create account or sign in'**
  String get accountCreateOrSignIn;

  /// No description provided for @accountYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get accountYourAccount;

  /// No description provided for @accountEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get accountEditProfile;

  /// No description provided for @accountChangeName.
  ///
  /// In en, this message translates to:
  /// **'Change your name'**
  String get accountChangeName;

  /// No description provided for @accountChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get accountChangePassword;

  /// No description provided for @accountDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDelete;

  /// No description provided for @accountVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get accountVerifyTitle;

  /// No description provided for @accountVerifyBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a link to {email}. Open it, tap “Verify email”, then come back and tap “I’ve verified”. Check spam if you don’t see it.'**
  String accountVerifyBody(String email);

  /// No description provided for @accountResend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get accountResend;

  /// No description provided for @accountIveVerified.
  ///
  /// In en, this message translates to:
  /// **'I\'ve verified'**
  String get accountIveVerified;

  /// No description provided for @accountEmailVerified.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get accountEmailVerified;

  /// No description provided for @accountFullySetUp.
  ///
  /// In en, this message translates to:
  /// **'Your account is fully set up.'**
  String get accountFullySetUp;

  /// No description provided for @credits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get credits;

  /// No description provided for @creditsAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} available'**
  String creditsAvailable(int count);

  /// No description provided for @accountGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google account'**
  String get accountGoogle;

  /// No description provided for @accountEmail.
  ///
  /// In en, this message translates to:
  /// **'Email account'**
  String get accountEmail;

  /// No description provided for @accountVerificationSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent to {email}.'**
  String accountVerificationSent(String email);

  /// No description provided for @accountVerifiedAllSet.
  ///
  /// In en, this message translates to:
  /// **'Email verified — you’re all set!'**
  String get accountVerifiedAllSet;

  /// No description provided for @accountNotVerifiedYet.
  ///
  /// In en, this message translates to:
  /// **'Not verified yet. Open the link in your email, then try again.'**
  String get accountNotVerifiedYet;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @accountProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get accountProfileUpdated;

  /// No description provided for @accountCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get accountCurrentPassword;

  /// No description provided for @accountNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password (min 8)'**
  String get accountNewPassword;

  /// No description provided for @accountPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'New password must be at least 8 characters.'**
  String get accountPasswordTooShort;

  /// No description provided for @accountPasswordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated.'**
  String get accountPasswordUpdated;

  /// No description provided for @accountSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out.'**
  String get accountSignedOut;

  /// No description provided for @accountDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account. Your credits and profile cannot be recovered. You’ll continue as a guest.'**
  String get accountDeleteBody;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted.'**
  String get accountDeleted;

  /// No description provided for @creditsEarnFree.
  ///
  /// In en, this message translates to:
  /// **'Earn free credits'**
  String get creditsEarnFree;

  /// No description provided for @creditsClaimDaily.
  ///
  /// In en, this message translates to:
  /// **'Claim daily credits'**
  String get creditsClaimDaily;

  /// No description provided for @creditsClaimDailySub.
  ///
  /// In en, this message translates to:
  /// **'A few free credits every day'**
  String get creditsClaimDailySub;

  /// No description provided for @creditsWatchAd.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad'**
  String get creditsWatchAd;

  /// No description provided for @creditsWatchAdSub.
  ///
  /// In en, this message translates to:
  /// **'Get credits for watching a short video'**
  String get creditsWatchAdSub;

  /// No description provided for @creditsBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy credits'**
  String get creditsBuy;

  /// No description provided for @creditsIapUnavailable.
  ///
  /// In en, this message translates to:
  /// **'In-app purchases aren’t available on this device yet.'**
  String get creditsIapUnavailable;

  /// No description provided for @creditsYourBalance.
  ///
  /// In en, this message translates to:
  /// **'Your balance'**
  String get creditsYourBalance;

  /// No description provided for @creditsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 credit} other{{count} credits}}'**
  String creditsCount(int count);

  /// No description provided for @creditsOneTime.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase'**
  String get creditsOneTime;

  /// No description provided for @creditsAvailableSoon.
  ///
  /// In en, this message translates to:
  /// **'Available soon'**
  String get creditsAvailableSoon;

  /// No description provided for @creditsClaimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed +{count} credits!'**
  String creditsClaimed(int count);

  /// No description provided for @creditsAlreadyClaimed.
  ///
  /// In en, this message translates to:
  /// **'Already claimed today. Come back tomorrow.'**
  String get creditsAlreadyClaimed;

  /// No description provided for @creditsEarned.
  ///
  /// In en, this message translates to:
  /// **'Earned +{count} credits!'**
  String creditsEarned(int count);

  /// No description provided for @creditsThanksWatching.
  ///
  /// In en, this message translates to:
  /// **'Thanks for watching — your credits will appear shortly.'**
  String get creditsThanksWatching;

  /// No description provided for @creditsCouldNotConfirm.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm your credits. Pull to refresh in a moment.'**
  String get creditsCouldNotConfirm;

  /// No description provided for @creditsNoAd.
  ///
  /// In en, this message translates to:
  /// **'No ad available right now. Try again shortly.'**
  String get creditsNoAd;

  /// No description provided for @sessionExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get sessionExpiredTitle;

  /// No description provided for @sessionExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'You’ve been signed out. Sign in again to get back to your account, or keep using PDF Craft as a guest.'**
  String get sessionExpiredBody;

  /// No description provided for @sessionContinueGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get sessionContinueGuest;

  /// No description provided for @sessionSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get sessionSignInAgain;

  /// No description provided for @incomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Open with PDF Craft'**
  String get incomingTitle;

  /// No description provided for @incomingReceived.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file received} other{{count} files received}}'**
  String incomingReceived(int count);

  /// No description provided for @incomingNoTools.
  ///
  /// In en, this message translates to:
  /// **'No in-app tools apply to these files.'**
  String get incomingNoTools;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @dontAskAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t ask me again'**
  String get dontAskAgain;

  /// No description provided for @chooseFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose files'**
  String get chooseFiles;

  /// No description provided for @selManage.
  ///
  /// In en, this message translates to:
  /// **'Manage selection'**
  String get selManage;

  /// No description provided for @selNoToolsApply.
  ///
  /// In en, this message translates to:
  /// **'No tools apply to this selection'**
  String get selNoToolsApply;

  /// No description provided for @selApplyTo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Apply to 1 file} other{Apply to {count} files}}'**
  String selApplyTo(int count);

  /// No description provided for @selNoFiles.
  ///
  /// In en, this message translates to:
  /// **'No files selected'**
  String get selNoFiles;

  /// No description provided for @selCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selCount(int count);

  /// No description provided for @nextToolTitle.
  ///
  /// In en, this message translates to:
  /// **'Use this file in another tool'**
  String get nextToolTitle;

  /// No description provided for @nextToolNone.
  ///
  /// In en, this message translates to:
  /// **'No other tool accepts this kind of file.'**
  String get nextToolNone;

  /// No description provided for @procUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading {percent}%'**
  String procUploading(int percent);

  /// No description provided for @procProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing on our servers…'**
  String get procProcessing;

  /// No description provided for @procWorking.
  ///
  /// In en, this message translates to:
  /// **'Working on it'**
  String get procWorking;

  /// No description provided for @procSecure.
  ///
  /// In en, this message translates to:
  /// **'Sent securely · removed after processing'**
  String get procSecure;

  /// No description provided for @fileSelectForTools.
  ///
  /// In en, this message translates to:
  /// **'Select for tools'**
  String get fileSelectForTools;

  /// No description provided for @fileDeselect.
  ///
  /// In en, this message translates to:
  /// **'Deselect'**
  String get fileDeselect;

  /// No description provided for @favAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get favAdd;

  /// No description provided for @favRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get favRemove;

  /// No description provided for @openInExternalViewer.
  ///
  /// In en, this message translates to:
  /// **'Open in external viewer'**
  String get openInExternalViewer;
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
