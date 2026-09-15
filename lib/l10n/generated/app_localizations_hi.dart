// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'PDF Craft';

  @override
  String get settingsLanguage => 'भाषा';

  @override
  String get languageSystem => 'सिस्टम डिफ़ॉल्ट';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get switchLanguageTooltip => 'भाषा बदलें';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get delete => 'हटाएँ';

  @override
  String get gotIt => 'समझ गया';

  @override
  String get refresh => 'रीफ़्रेश करें';

  @override
  String get signOut => 'साइन आउट';

  @override
  String get loading => 'लोड हो रहा है…';

  @override
  String get unknown => 'अज्ञात';

  @override
  String get discard => 'छोड़ें';

  @override
  String get seeMore => 'और देखें';

  @override
  String get favorites => 'पसंदीदा';

  @override
  String get recent => 'हाल की';

  @override
  String get applyATool => 'टूल इस्तेमाल करें';

  @override
  String get outputFileName => 'आउटपुट फ़ाइल का नाम';

  @override
  String get actionOpen => 'खोलें';

  @override
  String get actionSave => 'सेव करें';

  @override
  String get actionShare => 'शेयर करें';

  @override
  String get actionSearch => 'खोजें';

  @override
  String get actionSettings => 'सेटिंग्स';

  @override
  String get errSomethingWrong => 'कुछ गलत हो गया';

  @override
  String pageNumber(int number) {
    return 'पेज $number';
  }

  @override
  String savedTo(String path) {
    return '$path में सेव किया गया';
  }

  @override
  String failedToSave(String error) {
    return 'सेव नहीं हो सका: $error';
  }

  @override
  String get navFiles => 'फ़ाइलें';

  @override
  String get navTools => 'टूल्स';

  @override
  String get navScanner => 'स्कैनर';

  @override
  String get navCloud => 'क्लाउड';

  @override
  String get rateTitle => 'PDF Craft पसंद आ रहा है?';

  @override
  String get rateBody =>
      'आपने कई फ़ाइलें प्रोसेस की हैं! अगर यह ऐप आपके काम का है, तो कृपया एक मिनट निकालकर इसे रेटिंग दें — इससे हमें बहुत मदद मिलती है।';

  @override
  String get rateLater => 'बाद में';

  @override
  String get rateNow => 'अभी रेट करें';

  @override
  String get filesRecentFiles => 'हाल की फ़ाइलें';

  @override
  String get filesMyStorage => 'मेरी स्टोरेज';

  @override
  String get storageInternal => 'इंटरनल स्टोरेज';

  @override
  String get storageDownloads => 'डाउनलोड';

  @override
  String get storageDocuments => 'दस्तावेज़';

  @override
  String get storageProcessed => 'प्रोसेस की गई फ़ाइलें';

  @override
  String get errStoragePermissionNeeded =>
      'अपनी फ़ाइलें देखने के लिए स्टोरेज की अनुमति ज़रूरी है';

  @override
  String get noRecentFiles => 'कोई हाल की फ़ाइल नहीं';

  @override
  String get toolsAllTools => 'सभी टूल्स';

  @override
  String toolsCount(int count) {
    return '($count)';
  }

  @override
  String get toolsSearchHint => 'टूल्स खोजें';

  @override
  String get toolsNoneFound => 'कोई टूल नहीं मिला';

  @override
  String get toolsRecentlyUsed => 'हाल ही में इस्तेमाल किए गए';

  @override
  String toolAddedToFavorites(String name) {
    return '$name पसंदीदा में जोड़ा गया';
  }

  @override
  String toolRemovedFromFavorites(String name) {
    return '$name पसंदीदा से हटाया गया';
  }

  @override
  String get scanTitle => 'डॉक्यूमेंट स्कैनर';

  @override
  String get scanSubtitle =>
      'कैमरे से कागज़ी दस्तावेज़ स्कैन करें या गैलरी से इम्पोर्ट करें।';

  @override
  String get scanToPdf => 'स्कैन करके PDF';

  @override
  String get scanToPdfDesc =>
      'स्कैन किए गए पेजों से एक मल्टी-पेज PDF बनाता है।';

  @override
  String get scanToJpeg => 'स्कैन करके JPEG';

  @override
  String get scanToJpegDesc =>
      'हर पेज को अलग JPEG इमेज के रूप में सेव करता है।';

  @override
  String get scanTip =>
      'टिप: आप कैमरे से स्कैन करने के साथ-साथ गैलरी से भी इम्पोर्ट कर सकते हैं।';

  @override
  String get scanPdfDocument => 'स्कैन की गई PDF';

  @override
  String scanImagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count स्कैन की गई इमेज',
      one: '1 स्कैन की गई इमेज',
    );
    return '$_temp0';
  }

  @override
  String get scanSavePdf => 'PDF सेव करें';

  @override
  String get scanMergeToPdf => 'PDF में जोड़ें';

  @override
  String get scanPdfReady => 'स्कैन की गई PDF तैयार है';

  @override
  String get scanTapToPreview =>
      'देखने के लिए टैप करें • सेव करने के लिए “PDF सेव करें” दबाएँ';

  @override
  String get scanCancelledOrFailed => 'स्कैन रद्द हुआ या विफल रहा';

  @override
  String get scanImagesMerged => 'इमेज PDF में जोड़ दी गईं';

  @override
  String get scanCreatingPdf => 'आपकी PDF बनाई जा रही है';

  @override
  String get googleDrive => 'Google Drive';

  @override
  String get driveSignInFailed => 'साइन-इन विफल रहा';

  @override
  String get driveLoadFailed => 'Drive की फ़ाइलें लोड नहीं हो सकीं';

  @override
  String get driveUploaded => 'Google Drive पर अपलोड हो गया';

  @override
  String driveUploadFailed(String error) {
    return 'अपलोड विफल: $error';
  }

  @override
  String get driveDownloaded => 'प्रोसेस्ड फ़ोल्डर में डाउनलोड हो गया';

  @override
  String driveDownloadFailed(String error) {
    return 'डाउनलोड विफल: $error';
  }

  @override
  String driveCouldNotOpen(String error) {
    return 'खोला नहीं जा सका: $error';
  }

  @override
  String driveCouldNotFetch(String error) {
    return 'फ़ाइल नहीं मिल सकी: $error';
  }

  @override
  String get driveNoToolsForType =>
      'इस तरह की फ़ाइल के लिए कोई टूल उपलब्ध नहीं है';

  @override
  String driveShareFailed(String error) {
    return 'शेयर विफल: $error';
  }

  @override
  String get driveUploading => 'अपलोड हो रहा है…';

  @override
  String get driveUploadFile => 'फ़ाइल अपलोड करें';

  @override
  String get driveConnect => 'Google Drive कनेक्ट करें';

  @override
  String get driveConnectBody =>
      'अपनी Drive फ़ाइलें अपलोड, डाउनलोड और मैनेज करने के लिए साइन इन करें।';

  @override
  String get driveSignInWithGoogle => 'Google से साइन इन करें';

  @override
  String driveStorageUsed(String used, String total) {
    return '$total में से $used इस्तेमाल';
  }

  @override
  String get driveNoFiles => 'आपकी Drive में कोई फ़ाइल नहीं है';

  @override
  String driveNoFilesOfType(String type) {
    return 'कोई $type नहीं मिली';
  }

  @override
  String get filterAll => 'सभी';

  @override
  String get filterPdf => 'PDF';

  @override
  String get filterPdfs => 'PDF';

  @override
  String get filterImages => 'इमेज';

  @override
  String get filterDocs => 'डॉक्स';

  @override
  String get filterDocuments => 'दस्तावेज़';

  @override
  String get filterOther => 'अन्य';

  @override
  String get searchFilesHint => 'फ़ाइलें खोजें';

  @override
  String get searching => 'खोज रहे हैं…';

  @override
  String get noMatchingFiles => 'कोई मिलती-जुलती फ़ाइल नहीं';

  @override
  String filesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ाइलें मिलीं',
      one: '1 फ़ाइल मिली',
    );
    return '$_temp0';
  }

  @override
  String get resultsTitle => 'परिणाम';

  @override
  String get resultsClearTitle => 'परिणाम साफ़ करें';

  @override
  String resultsClearBody(int count) {
    return 'सभी $count आउटपुट फ़ाइलें हटाएँ? इसे वापस नहीं किया जा सकता।';
  }

  @override
  String get resultsCleared => 'परिणाम साफ़ कर दिए गए';

  @override
  String get clearAll => 'सब साफ़ करें';

  @override
  String get resultsEmpty => 'अभी कोई परिणाम नहीं';

  @override
  String get resultsEmptyBody =>
      'किसी भी टूल से बनाई गई फ़ाइलें यहाँ जल्दी से मिलेंगी।';

  @override
  String get splashTagline => 'आपका पूरा PDF टूलकिट';

  @override
  String get onbTitle1 => 'आपके सारे PDF टूल्स';

  @override
  String get onbBody1 =>
      'मर्ज, स्प्लिट, रोटेट, कंप्रेस, पेजों का क्रम बदलना और बहुत कुछ — PDF के लिए ज़रूरी सब कुछ एक ही जगह।';

  @override
  String get onbTitle2 => 'स्कैन करें और बदलें';

  @override
  String get onbBody2 =>
      'कैमरे से कागज़ी दस्तावेज़ स्कैन करें और इमेज को तुरंत PDF में बदलें।';

  @override
  String get onbTitle3 => 'अपनी फ़ाइलें व्यवस्थित करें';

  @override
  String get onbBody3 =>
      'स्टोरेज ब्राउज़ करें, पसंदीदा सेव करें और हाल में खोली गई फ़ाइलें देखें — सब एक ही स्क्रीन से।';

  @override
  String get onbSkip => 'छोड़ें';

  @override
  String get onbNext => 'आगे';

  @override
  String get onbGetStarted => 'शुरू करें';

  @override
  String get permTitle => 'फ़ाइल एक्सेस की अनुमति दें';

  @override
  String get permBody =>
      'PDF Craft आपके डिवाइस में पहले से मौजूद PDF और इमेज के साथ काम करता है। अपने दस्तावेज़ ब्राउज़ करने, खोलने और सेव करने के लिए फ़ाइल एक्सेस दें।';

  @override
  String get permBenefitBrowse => 'अपनी PDF और इमेज ब्राउज़ करें और खोलें';

  @override
  String get permBenefitSave => 'टूल के परिणाम अपनी स्टोरेज में सेव करें';

  @override
  String get permBenefitPrivate =>
      'जब तक आप कोई टूल इस्तेमाल नहीं करते, फ़ाइलें आपके डिवाइस पर ही रहती हैं';

  @override
  String get permTurnedOff =>
      'एक्सेस बंद है। सिस्टम सेटिंग्स में PDF Craft के लिए “सभी फ़ाइलों का एक्सेस” (या स्टोरेज) चालू करें।';

  @override
  String get permRequesting => 'अनुरोध किया जा रहा है…';

  @override
  String get permOpenSettings => 'सेटिंग्स खोलें';

  @override
  String get permAllow => 'एक्सेस दें';

  @override
  String get permDenied => 'अनुमति नहीं मिली';

  @override
  String get errGenericTitle => 'कुछ गलत हो गया';

  @override
  String get errGenericBody =>
      'अचानक कोई त्रुटि हुई। कृपया वापस जाकर फिर कोशिश करें।';

  @override
  String get goBack => 'वापस जाएँ';

  @override
  String get close => 'बंद करें';

  @override
  String get clear => 'साफ़ करें';

  @override
  String get update => 'अपडेट करें';

  @override
  String get guest => 'गेस्ट';

  @override
  String get actionView => 'देखें';

  @override
  String get openExternally => 'दूसरे ऐप में खोलें';

  @override
  String get settingsSectionAccount => 'खाता';

  @override
  String get settingsEmailNotVerified =>
      'ईमेल वेरिफ़ाई नहीं है — वेरिफ़ाई करने के लिए टैप करें';

  @override
  String get settingsManageAccount => 'अपना खाता मैनेज करें';

  @override
  String get settingsSignInPrompt =>
      'अपने क्रेडिट सुरक्षित रखने और सभी डिवाइस पर सिंक करने के लिए साइन इन करें';

  @override
  String get settingsSectionAppearance => 'रूप-रंग';

  @override
  String get themeSystem => 'सिस्टम डिफ़ॉल्ट';

  @override
  String get themeLight => 'लाइट';

  @override
  String get themeDark => 'डार्क';

  @override
  String get settingsSectionStorage => 'स्टोरेज';

  @override
  String get settingsProcessedFolder => 'प्रोसेस की गई फ़ाइलों का फ़ोल्डर';

  @override
  String settingsProcessedSummary(int count, String size) {
    return '$count फ़ाइलें · $size · देखने के लिए टैप करें';
  }

  @override
  String get settingsPasswordHints => 'पासवर्ड संकेत';

  @override
  String get settingsPasswordHintsSub => 'सुरक्षित PDF के लिए सेव किए गए संकेत';

  @override
  String get settingsSectionPrivacy => 'गोपनीयता और डेटा';

  @override
  String get settingsPrivacyBody =>
      'टूल्स हमारे सुरक्षित सर्वर पर चलते हैं, इसलिए हर डिवाइस पर एक जैसे परिणाम मिलते हैं। फ़ाइलें एन्क्रिप्टेड (HTTPS) कनेक्शन से भेजी जाती हैं, प्रोसेस होती हैं और फिर हटा दी जाती हैं — हम आपके दस्तावेज़ नहीं रखते।';

  @override
  String get settingsSectionAbout => 'ऐप के बारे में';

  @override
  String get settingsAboutSubtitle => 'PDF और इमेज टूलकिट';

  @override
  String get settingsAppIntro => 'ऐप परिचय';

  @override
  String get settingsAppIntroSub => 'स्वागत गाइड फिर से देखें';

  @override
  String get settingsVersion => 'वर्ज़न';

  @override
  String get settingsClearProcessedTitle => 'प्रोसेस की गई फ़ाइलें हटाएँ';

  @override
  String settingsClearProcessedBody(int count) {
    return 'प्रोसेस्ड फ़ोल्डर की सभी $count फ़ाइलें हटाएँ?';
  }

  @override
  String get settingsProcessedCleared => 'प्रोसेस की गई फ़ाइलें हटा दी गईं';

  @override
  String get settingsPasswordHintsCleared => 'पासवर्ड संकेत हटा दिए गए';

  @override
  String get authCreateTitle => 'अपना खाता बनाएँ';

  @override
  String get authSignInTitle => 'फिर से स्वागत है';

  @override
  String get authCreateSubtitle =>
      'अपने क्रेडिट सुरक्षित रखें और सभी डिवाइस पर सिंक करें।';

  @override
  String get authSignInSubtitle => 'अपने PDF Craft खाते में साइन इन करें।';

  @override
  String get authNameOptional => 'नाम (वैकल्पिक)';

  @override
  String get authEmail => 'ईमेल';

  @override
  String get authInvalidEmail => 'सही ईमेल डालें';

  @override
  String get authPassword => 'पासवर्ड';

  @override
  String get authPasswordMin => 'कम से कम 8 अक्षर';

  @override
  String get authForgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get authCreateAccount => 'खाता बनाएँ';

  @override
  String get authSignIn => 'साइन इन';

  @override
  String get authOr => 'या';

  @override
  String get authContinueGoogle => 'Google से जारी रखें';

  @override
  String get authHaveAccount => 'पहले से खाता है? ';

  @override
  String get authNoAccount => 'खाता नहीं है? ';

  @override
  String get authCreateOne => 'बनाएँ';

  @override
  String get authGuestNote =>
      'आप गेस्ट के रूप में PDF Craft इस्तेमाल करते रह सकते हैं।';

  @override
  String get authAccountCreated =>
      'खाता बन गया — वेरिफ़ाई करने के लिए अपना ईमेल देखें।';

  @override
  String get authSignedIn => 'साइन इन हो गया।';

  @override
  String get authSomethingWrong => 'कुछ गलत हो गया। कृपया फिर से कोशिश करें।';

  @override
  String get authVerifyFirstTitle => 'पहले अपना ईमेल वेरिफ़ाई करें';

  @override
  String authVerifyFirstBody(String email) {
    return 'आपका ईमेल अभी वेरिफ़ाई नहीं है। हम $email पर वेरिफ़िकेशन लिंक फिर से भेज सकते हैं — उसे खोलें, “Verify email” पर टैप करें, फिर दोबारा साइन इन करें।';
  }

  @override
  String get yourEmail => 'आपके ईमेल';

  @override
  String get authResendLink => 'लिंक फिर से भेजें';

  @override
  String get authSignedInGoogle => 'Google से साइन इन हो गया।';

  @override
  String get authGoogleFailed => 'Google साइन-इन विफल रहा।';

  @override
  String get authSwitchTitle => 'अपने खाते पर जाएँ?';

  @override
  String authSwitchCredits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'गेस्ट के रूप में आपके पास $count क्रेडिट हैं।',
      one: 'गेस्ट के रूप में आपके पास 1 क्रेडिट है।',
    );
    return '$_temp0';
  }

  @override
  String get authSwitchBody =>
      'साइन इन करने पर आप अपने मौजूदा खाते पर चले जाएँगे और ये गेस्ट क्रेडिट साथ नहीं जाएँगे।\n\nटिप: इन्हें रखने के लिए “खाता बनाएँ” चुनें।';

  @override
  String get authSignInAnyway => 'फिर भी साइन इन करें';

  @override
  String get authEnterEmailFirst => 'पहले ऊपर अपना ईमेल डालें।';

  @override
  String get authCheckEmailTitle => 'अपना ईमेल देखें';

  @override
  String authResetSentBody(String email) {
    return 'अगर $email के लिए खाता मौजूद है, तो हमने पासवर्ड रीसेट लिंक भेज दिया है। नया पासवर्ड चुनने के लिए उसे खोलें, फिर वापस आकर साइन इन करें।';
  }

  @override
  String get authResetFailed =>
      'रीसेट ईमेल नहीं भेजा जा सका। कृपया फिर से कोशिश करें।';

  @override
  String get authLegalPrefix => 'खाता बनाकर आप हमारी ';

  @override
  String get authLegalTerms => 'शर्तों';

  @override
  String get authLegalAnd => ' और ';

  @override
  String get authLegalPrivacy => 'गोपनीयता नीति';

  @override
  String get authLegalSuffix => ' से सहमत होते हैं।';

  @override
  String get accountGuestTitle =>
      'आप PDF Craft गेस्ट के रूप में इस्तेमाल कर रहे हैं';

  @override
  String get accountGuestBody =>
      'अपने क्रेडिट सुरक्षित रखने और सभी डिवाइस पर सिंक करने के लिए मुफ़्त खाता बनाएँ।';

  @override
  String get accountCreateOrSignIn => 'खाता बनाएँ या साइन इन करें';

  @override
  String get accountYourAccount => 'आपका खाता';

  @override
  String get accountEditProfile => 'प्रोफ़ाइल बदलें';

  @override
  String get accountChangeName => 'अपना नाम बदलें';

  @override
  String get accountChangePassword => 'पासवर्ड बदलें';

  @override
  String get accountDelete => 'खाता हटाएँ';

  @override
  String get accountVerifyTitle => 'अपना ईमेल वेरिफ़ाई करें';

  @override
  String accountVerifyBody(String email) {
    return 'हमने $email पर लिंक भेजा है। उसे खोलें, “Verify email” पर टैप करें, फिर वापस आकर “मैंने वेरिफ़ाई कर लिया” पर टैप करें। न दिखे तो स्पैम फ़ोल्डर देखें।';
  }

  @override
  String get accountResend => 'फिर भेजें';

  @override
  String get accountIveVerified => 'मैंने वेरिफ़ाई कर लिया';

  @override
  String get accountEmailVerified => 'ईमेल वेरिफ़ाई हो गया';

  @override
  String get accountFullySetUp => 'आपका खाता पूरी तरह तैयार है।';

  @override
  String get credits => 'क्रेडिट';

  @override
  String creditsAvailable(int count) {
    return '$count उपलब्ध';
  }

  @override
  String get accountGoogle => 'Google खाता';

  @override
  String get accountEmail => 'ईमेल खाता';

  @override
  String accountVerificationSent(String email) {
    return '$email पर वेरिफ़िकेशन ईमेल भेज दिया गया।';
  }

  @override
  String get accountVerifiedAllSet => 'ईमेल वेरिफ़ाई हो गया — सब तैयार है!';

  @override
  String get accountNotVerifiedYet =>
      'अभी वेरिफ़ाई नहीं हुआ। अपने ईमेल का लिंक खोलें, फिर कोशिश करें।';

  @override
  String get firstName => 'पहला नाम';

  @override
  String get lastName => 'उपनाम';

  @override
  String get accountProfileUpdated => 'प्रोफ़ाइल अपडेट हो गई।';

  @override
  String get accountCurrentPassword => 'मौजूदा पासवर्ड';

  @override
  String get accountNewPassword => 'नया पासवर्ड (कम से कम 8)';

  @override
  String get accountPasswordTooShort =>
      'नया पासवर्ड कम से कम 8 अक्षरों का होना चाहिए।';

  @override
  String get accountPasswordUpdated => 'पासवर्ड अपडेट हो गया।';

  @override
  String get accountSignedOut => 'साइन आउट हो गया।';

  @override
  String get accountDeleteTitle => 'खाता हटाएँ?';

  @override
  String get accountDeleteBody =>
      'इससे आपका खाता हमेशा के लिए हट जाएगा। आपके क्रेडिट और प्रोफ़ाइल वापस नहीं मिलेंगे। आप गेस्ट के रूप में जारी रहेंगे।';

  @override
  String get accountDeleted => 'खाता हटा दिया गया।';

  @override
  String get creditsEarnFree => 'मुफ़्त क्रेडिट पाएँ';

  @override
  String get creditsClaimDaily => 'रोज़ के क्रेडिट लें';

  @override
  String get creditsClaimDailySub => 'हर दिन कुछ मुफ़्त क्रेडिट';

  @override
  String get creditsWatchAd => 'विज्ञापन देखें';

  @override
  String get creditsWatchAdSub => 'छोटा वीडियो देखकर क्रेडिट पाएँ';

  @override
  String get creditsBuy => 'क्रेडिट खरीदें';

  @override
  String get creditsIapUnavailable =>
      'इस डिवाइस पर अभी इन-ऐप खरीदारी उपलब्ध नहीं है।';

  @override
  String get creditsYourBalance => 'आपका बैलेंस';

  @override
  String creditsCount(int count) {
    return '$count क्रेडिट';
  }

  @override
  String get creditsOneTime => 'एक बार की खरीदारी';

  @override
  String get creditsAvailableSoon => 'जल्द उपलब्ध';

  @override
  String creditsClaimed(int count) {
    return '+$count क्रेडिट मिल गए!';
  }

  @override
  String get creditsAlreadyClaimed => 'आज के क्रेडिट ले चुके हैं। कल फिर आएँ।';

  @override
  String creditsEarned(int count) {
    return '+$count क्रेडिट कमाए!';
  }

  @override
  String get creditsThanksWatching =>
      'देखने के लिए धन्यवाद — आपके क्रेडिट जल्द ही दिखेंगे।';

  @override
  String get creditsCouldNotConfirm =>
      'क्रेडिट की पुष्टि नहीं हो सकी। थोड़ी देर में नीचे खींचकर रीफ़्रेश करें।';

  @override
  String get creditsNoAd =>
      'अभी कोई विज्ञापन उपलब्ध नहीं है। थोड़ी देर में कोशिश करें।';

  @override
  String get sessionExpiredTitle => 'सेशन खत्म हो गया';

  @override
  String get sessionExpiredBody =>
      'आप साइन आउट हो गए हैं। अपने खाते में लौटने के लिए फिर से साइन इन करें, या गेस्ट के रूप में PDF Craft इस्तेमाल करते रहें।';

  @override
  String get sessionContinueGuest => 'गेस्ट के रूप में जारी रखें';

  @override
  String get sessionSignInAgain => 'फिर से साइन इन करें';

  @override
  String get incomingTitle => 'PDF Craft से खोलें';

  @override
  String incomingReceived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ाइलें मिलीं',
      one: '1 फ़ाइल मिली',
    );
    return '$_temp0';
  }

  @override
  String get incomingNoTools => 'इन फ़ाइलों पर कोई इन-ऐप टूल लागू नहीं होता।';
}
