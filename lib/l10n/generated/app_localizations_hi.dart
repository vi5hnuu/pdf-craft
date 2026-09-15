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
}
