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

  @override
  String get splashTagline => 'Your complete PDF toolkit';

  @override
  String get onbTitle1 => 'All Your PDF Tools';

  @override
  String get onbBody1 =>
      'Merge, split, rotate, compress, reorder, and much more — everything you need for PDFs in one place.';

  @override
  String get onbTitle2 => 'Scan & Convert';

  @override
  String get onbBody2 =>
      'Scan physical documents with your camera and instantly convert images to PDFs.';

  @override
  String get onbTitle3 => 'Organize Your Files';

  @override
  String get onbBody3 =>
      'Browse your storage, bookmark favorites, and access recently opened files — all from one screen.';

  @override
  String get onbSkip => 'Skip';

  @override
  String get onbNext => 'Next';

  @override
  String get onbGetStarted => 'Get Started';

  @override
  String get permTitle => 'Allow file access';

  @override
  String get permBody =>
      'PDF Craft works with the PDFs and images already on your device. Grant file access so you can browse, open and save your documents.';

  @override
  String get permBenefitBrowse => 'Browse & open your PDFs and images';

  @override
  String get permBenefitSave => 'Save tool results back to your storage';

  @override
  String get permBenefitPrivate =>
      'Files stay on your device until you use a tool';

  @override
  String get permTurnedOff =>
      'Access was turned off. Enable “All files access” (or Storage) for PDF Craft in system Settings.';

  @override
  String get permRequesting => 'Requesting…';

  @override
  String get permOpenSettings => 'Open Settings';

  @override
  String get permAllow => 'Allow access';

  @override
  String get permDenied => 'Permission denied';

  @override
  String get errGenericTitle => 'Something Went Wrong';

  @override
  String get errGenericBody =>
      'An unexpected error occurred. Please try going back.';

  @override
  String get goBack => 'Go Back';

  @override
  String get close => 'Close';

  @override
  String get clear => 'Clear';

  @override
  String get update => 'Update';

  @override
  String get guest => 'Guest';

  @override
  String get actionView => 'View';

  @override
  String get openExternally => 'Open externally';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsEmailNotVerified => 'Email not verified — tap to verify';

  @override
  String get settingsManageAccount => 'Manage your account';

  @override
  String get settingsSignInPrompt =>
      'Sign in to save your credits & sync across devices';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get themeSystem => 'System Default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsSectionStorage => 'Storage';

  @override
  String get settingsProcessedFolder => 'Processed Files Folder';

  @override
  String settingsProcessedSummary(int count, String size) {
    return '$count files · $size · tap to view';
  }

  @override
  String get settingsPasswordHints => 'Password Hints';

  @override
  String get settingsPasswordHintsSub => 'Saved hints for protected PDFs';

  @override
  String get settingsSectionPrivacy => 'Privacy & Data';

  @override
  String get settingsPrivacyBody =>
      'Tools run on our secure server so results are identical on every device. Files are sent over an encrypted (HTTPS) connection, processed, and removed afterwards — we don\'t keep your documents.';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsAboutSubtitle => 'PDF & Image toolkit';

  @override
  String get settingsAppIntro => 'App Intro';

  @override
  String get settingsAppIntroSub => 'Replay the welcome walkthrough';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsClearProcessedTitle => 'Clear Processed Files';

  @override
  String settingsClearProcessedBody(int count) {
    return 'Delete all $count files in the processed folder?';
  }

  @override
  String get settingsProcessedCleared => 'Processed files cleared';

  @override
  String get settingsPasswordHintsCleared => 'Password hints cleared';

  @override
  String get authCreateTitle => 'Create your account';

  @override
  String get authSignInTitle => 'Welcome back';

  @override
  String get authCreateSubtitle =>
      'Keep your credits safe and sync across devices.';

  @override
  String get authSignInSubtitle => 'Sign in to your PDF Craft account.';

  @override
  String get authNameOptional => 'Name (optional)';

  @override
  String get authEmail => 'Email';

  @override
  String get authInvalidEmail => 'Enter a valid email';

  @override
  String get authPassword => 'Password';

  @override
  String get authPasswordMin => 'At least 8 characters';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authOr => 'or';

  @override
  String get authContinueGoogle => 'Continue with Google';

  @override
  String get authHaveAccount => 'Already have an account? ';

  @override
  String get authNoAccount => 'Don\'t have an account? ';

  @override
  String get authCreateOne => 'Create one';

  @override
  String get authGuestNote => 'You can keep using PDF Craft as a guest.';

  @override
  String get authAccountCreated =>
      'Account created — check your email to verify.';

  @override
  String get authSignedIn => 'Signed in.';

  @override
  String get authSomethingWrong => 'Something went wrong. Please try again.';

  @override
  String get authVerifyFirstTitle => 'Verify your email first';

  @override
  String authVerifyFirstBody(String email) {
    return 'Your email isn’t verified yet. We can resend the verification link to $email — open it, tap “Verify email”, then sign in again.';
  }

  @override
  String get yourEmail => 'your email';

  @override
  String get authResendLink => 'Resend link';

  @override
  String get authSignedInGoogle => 'Signed in with Google.';

  @override
  String get authGoogleFailed => 'Google sign-in failed.';

  @override
  String get authSwitchTitle => 'Switch to your account?';

  @override
  String authSwitchCredits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You have $count credits as a guest.',
      one: 'You have 1 credit as a guest.',
    );
    return '$_temp0';
  }

  @override
  String get authSwitchBody =>
      'Signing in switches to your existing account and these guest credits won\'t carry over.\n\nTip: choose “Create account” instead to keep them.';

  @override
  String get authSignInAnyway => 'Sign in anyway';

  @override
  String get authEnterEmailFirst => 'Enter your email above first.';

  @override
  String get authCheckEmailTitle => 'Check your email';

  @override
  String authResetSentBody(String email) {
    return 'If an account exists for $email, we’ve sent a password-reset link. Open it to choose a new password, then come back and sign in.';
  }

  @override
  String get authResetFailed => 'Could not send reset email. Please try again.';

  @override
  String get authLegalPrefix => 'By creating an account you agree to our ';

  @override
  String get authLegalTerms => 'Terms';

  @override
  String get authLegalAnd => ' & ';

  @override
  String get authLegalPrivacy => 'Privacy Policy';

  @override
  String get authLegalSuffix => '.';

  @override
  String get accountGuestTitle => 'You’re using PDF Craft as a guest';

  @override
  String get accountGuestBody =>
      'Create a free account to keep your credits safe and sync across devices.';

  @override
  String get accountCreateOrSignIn => 'Create account or sign in';

  @override
  String get accountYourAccount => 'Your account';

  @override
  String get accountEditProfile => 'Edit profile';

  @override
  String get accountChangeName => 'Change your name';

  @override
  String get accountChangePassword => 'Change password';

  @override
  String get accountDelete => 'Delete account';

  @override
  String get accountVerifyTitle => 'Verify your email';

  @override
  String accountVerifyBody(String email) {
    return 'We sent a link to $email. Open it, tap “Verify email”, then come back and tap “I’ve verified”. Check spam if you don’t see it.';
  }

  @override
  String get accountResend => 'Resend';

  @override
  String get accountIveVerified => 'I\'ve verified';

  @override
  String get accountEmailVerified => 'Email verified';

  @override
  String get accountFullySetUp => 'Your account is fully set up.';

  @override
  String get credits => 'Credits';

  @override
  String creditsAvailable(int count) {
    return '$count available';
  }

  @override
  String get accountGoogle => 'Google account';

  @override
  String get accountEmail => 'Email account';

  @override
  String accountVerificationSent(String email) {
    return 'Verification email sent to $email.';
  }

  @override
  String get accountVerifiedAllSet => 'Email verified — you’re all set!';

  @override
  String get accountNotVerifiedYet =>
      'Not verified yet. Open the link in your email, then try again.';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get accountProfileUpdated => 'Profile updated.';

  @override
  String get accountCurrentPassword => 'Current password';

  @override
  String get accountNewPassword => 'New password (min 8)';

  @override
  String get accountPasswordTooShort =>
      'New password must be at least 8 characters.';

  @override
  String get accountPasswordUpdated => 'Password updated.';

  @override
  String get accountSignedOut => 'Signed out.';

  @override
  String get accountDeleteTitle => 'Delete account?';

  @override
  String get accountDeleteBody =>
      'This permanently deletes your account. Your credits and profile cannot be recovered. You’ll continue as a guest.';

  @override
  String get accountDeleted => 'Account deleted.';

  @override
  String get creditsEarnFree => 'Earn free credits';

  @override
  String get creditsClaimDaily => 'Claim daily credits';

  @override
  String get creditsClaimDailySub => 'A few free credits every day';

  @override
  String get creditsWatchAd => 'Watch an ad';

  @override
  String get creditsWatchAdSub => 'Get credits for watching a short video';

  @override
  String get creditsBuy => 'Buy credits';

  @override
  String get creditsIapUnavailable =>
      'In-app purchases aren’t available on this device yet.';

  @override
  String get creditsYourBalance => 'Your balance';

  @override
  String creditsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count credits',
      one: '1 credit',
    );
    return '$_temp0';
  }

  @override
  String get creditsOneTime => 'One-time purchase';

  @override
  String get creditsAvailableSoon => 'Available soon';

  @override
  String creditsClaimed(int count) {
    return 'Claimed +$count credits!';
  }

  @override
  String get creditsAlreadyClaimed =>
      'Already claimed today. Come back tomorrow.';

  @override
  String creditsEarned(int count) {
    return 'Earned +$count credits!';
  }

  @override
  String get creditsThanksWatching =>
      'Thanks for watching — your credits will appear shortly.';

  @override
  String get creditsCouldNotConfirm =>
      'Couldn\'t confirm your credits. Pull to refresh in a moment.';

  @override
  String get creditsNoAd => 'No ad available right now. Try again shortly.';

  @override
  String get sessionExpiredTitle => 'Session expired';

  @override
  String get sessionExpiredBody =>
      'You’ve been signed out. Sign in again to get back to your account, or keep using PDF Craft as a guest.';

  @override
  String get sessionContinueGuest => 'Continue as guest';

  @override
  String get sessionSignInAgain => 'Sign in again';

  @override
  String get incomingTitle => 'Open with PDF Craft';

  @override
  String incomingReceived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files received',
      one: '1 file received',
    );
    return '$_temp0';
  }

  @override
  String get incomingNoTools => 'No in-app tools apply to these files.';
}
