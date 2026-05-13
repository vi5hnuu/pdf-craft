class AppRoute{
  final String name;
  final String path;//relative
  AppRoute({required this.name,required this.path});
}

class AppRoutes{
  static AppRoute splashRoute=AppRoute(name: 'splash', path: '/splash');
  static AppRoute onboardingRoute=AppRoute(name: 'onboarding', path: '/onboarding');
  static AppRoute batchProcessRoute=AppRoute(name: 'batch-process', path: '/batch-process');

  static AppRoute errorRoute=AppRoute(name: 'error', path: '/error');

  static AppRoute searchRoute=AppRoute(name: 'search', path: '/search');

  static AppRoute fileManagement=AppRoute(name: 'file-management', path: '/file-management');

  static AppRoute mergePdfRoute=AppRoute(name: 'merge-pdf-tool', path: '/merge-pdf-tool');
  static AppRoute reorderPdfPagesRoute=AppRoute(name: 'reorder-pages-pdf-tool', path: '/reorder-pages-pdf-tool');
  static AppRoute pdfToJpgRoute=AppRoute(name: 'pdf-to-jpg-tool', path: '/pdf-to-jpg-tool');
  static AppRoute imageToPdfRoute=AppRoute(name: 'image-to-pdf-tool', path: '/image-to-pdf-tool');
  static AppRoute pageNumbersRoute=AppRoute(name: 'page-numbers-tool', path: '/page-numbers-tool');
  static AppRoute splitPdfRoute=AppRoute(name: 'split-pdf-tool', path: '/split-pdf-tool');
  static AppRoute unprotectPdfRoute=AppRoute(name: 'unprotect-pdf-tool', path: '/unprotect-pdf-tool');
  static AppRoute protectPdfRoute=AppRoute(name: 'protect-pdf-tool', path: '/protect-pdf-tool');
  static AppRoute rotatePdfRoute=AppRoute(name: 'rotate-pdf-tool', path: '/rotate-pdf-tool');
  static AppRoute compressPdfRoute=AppRoute(name: 'compress-pdf-tool', path: '/compress-pdf-tool');
  static AppRoute watermarkPdfRoute=AppRoute(name: 'watermark-pdf-tool', path: '/watermark-pdf-tool');
  static AppRoute extractTextRoute=AppRoute(name: 'extract-text-tool', path: '/extract-text-tool');
  static AppRoute grayscalePdfRoute=AppRoute(name: 'grayscale-pdf-tool', path: '/grayscale-pdf-tool');
  static AppRoute cropPdfRoute=AppRoute(name: 'crop-pdf-tool', path: '/crop-pdf-tool');
  static AppRoute pdfInfoRoute=AppRoute(name: 'pdf-info-tool', path: '/pdf-info-tool');
  static AppRoute editMetadataRoute=AppRoute(name: 'edit-metadata-tool', path: '/edit-metadata-tool');
  static AppRoute headerFooterRoute=AppRoute(name: 'header-footer-tool', path: '/header-footer-tool');
  static AppRoute repairPdfRoute=AppRoute(name: 'repair-pdf-tool', path: '/repair-pdf-tool');
  static AppRoute flattenPdfRoute=AppRoute(name: 'flatten-pdf-tool', path: '/flatten-pdf-tool');
  static AppRoute addBlankPagesRoute=AppRoute(name: 'add-blank-pages-tool', path: '/add-blank-pages-tool');
  static AppRoute stampPdfRoute=AppRoute(name: 'stamp-pdf-tool', path: '/stamp-pdf-tool');
  static AppRoute qrStampPdfRoute=AppRoute(name: 'qr-stamp-pdf-tool', path: '/qr-stamp-pdf-tool');
  static AppRoute annotatePdfRoute=AppRoute(name: 'annotate-pdf-tool', path: '/annotate-pdf-tool');
  static AppRoute formPdfRoute=AppRoute(name: 'form-pdf-tool', path: '/form-pdf-tool');
  static AppRoute placeImageRoute=AppRoute(name: 'place-image-tool', path: '/place-image-tool');
  static AppRoute imageOverlayRoute=AppRoute(name: 'image-overlay-tool', path: '/image-overlay-tool');
  static AppRoute imageStudioRoute=AppRoute(name: 'image-studio', path: '/image-studio');
  static AppRoute pdfToWordRoute=AppRoute(name: 'pdf-to-word-tool', path: '/pdf-to-word-tool');
  static AppRoute pdfToExcelRoute=AppRoute(name: 'pdf-to-excel-tool', path: '/pdf-to-excel-tool');
  static AppRoute pdfToPptxRoute=AppRoute(name: 'pdf-to-pptx-tool', path: '/pdf-to-pptx-tool');
  static AppRoute driveRoute=AppRoute(name: 'google-drive', path: '/google-drive');
  static AppRoute pdfFilePreviewRoute=AppRoute(name: 'pdf-file-preview', path: '/pdf-file-preview/:pdfFilePath');


  static AppRoute homeRoute=AppRoute(name: 'home', path: '/');

  static AppRoute filesRoute=AppRoute(name: 'files', path: '/files');
  static AppRoute filesListingRoute=AppRoute(name: 'list', path: 'list');

  static AppRoute toolsRoute=AppRoute(name: 'tools', path: '/tools');

  static AppRoute scannerRoute=AppRoute(name: 'scanner', path: '/scanner');

  static AppRoute settingsRoute=AppRoute(name: 'setting', path: '/setting');


}