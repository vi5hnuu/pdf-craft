import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/file-selection-config.dart';
import 'package:pdf_craft/models/request/image-studio.dart' show ImageStudioOp;
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/RecentToolsService.dart';
import 'package:pdf_craft/tools/reward_gate.dart';
import 'package:pdf_craft/utils/Constants.dart';

/// A tool category (used for grouping + accent colour on the Tools screen).
class ToolCategory {
  final String name;
  final IconData icon;
  final Color color;
  const ToolCategory(this.name, this.icon, this.color);
}

/// All categories, in display order.
class ToolCategories {
  ToolCategories._();
  static const pdf = ToolCategory('PDF Tools', Icons.picture_as_pdf, Color(0xFFE53935));
  static const enhance = ToolCategory('Enhance', Icons.auto_fix_high, Color(0xFF7B1FA2));
  static const convert = ToolCategory('Convert', Icons.swap_horiz, Color(0xFF0288D1));
  static const security = ToolCategory('Security', Icons.security, Color(0xFF388E3C));
  static const batch = ToolCategory('Batch', Icons.dynamic_feed, Color(0xFF6D4C41));
  static const imageStudio = ToolCategory('Image Studio', Icons.photo_filter, Color(0xFF00897B));

  static const all = [pdf, enhance, convert, security, batch, imageStudio];
}

/// Common extension groups.
const _pdf = ['.pdf'];
const _imagesIn = ['.jpg', '.png', '.jpeg'];

/// Declarative description of a single tool.
///
/// This is the **single source of truth** for the app's tools. The Tools
/// screen, tool search, "recently used tools", the file→tool intellisense menu
/// (which tools apply to the current selection) and rewarded-ad gating all read
/// from here, instead of each re-declaring the tool list.
class ToolDef {
  /// Stable identifier (used to persist recents / favourites). Never reuse.
  final String id;
  final String name;
  final IconData icon;
  final ToolCategory category;

  /// Destination route the tool opens once files are chosen.
  final AppRoute route;

  /// Allowed file extensions (lowercase, dot-prefixed). Empty = any.
  final List<String> extensions;

  /// Whether the tool accepts more than one input file.
  final bool multiSelect;

  /// Minimum files required (only meaningful for multi-select tools).
  final int minSelection;

  /// Maximum files accepted; null = unlimited. Single-select tools use 1.
  final int? maxSelection;

  /// "Heavy" = server-side / expensive operation. Candidates for the optional
  /// rewarded-ad gate (Phase 5). Never gate plain viewing.
  final bool isHeavy;

  /// Extra payload merged into the route arguments (e.g. Image Studio op).
  final Map<String, dynamic>? extra;

  const ToolDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.category,
    required this.route,
    this.extensions = const [],
    this.multiSelect = false,
    this.minSelection = 1,
    this.maxSelection = 1,
    this.isHeavy = false,
    this.extra,
  });

  /// True when this tool can run on a selection of [count] files whose
  /// extensions are [exts] (all lowercase, dot-prefixed). Drives the
  /// intellisense menu: single-file tools light up only for one file, multi-file
  /// tools light up once their minimum is met, and extension filters are honored.
  bool acceptsSelection(int count, Set<String> exts) {
    if (count < minSelection) return false;
    if (maxSelection != null && count > maxSelection!) return false;
    if (extensions.isNotEmpty && !exts.every(extensions.contains)) return false;
    return true;
  }

  /// Opens the file-picker flow for this tool (used from the Tools screen).
  /// Heavy tools first pass through the opt-in rewarded-ad gate.
  void openPicker(BuildContext context) {
    RewardGate.run(
      context,
      isHeavy: isHeavy,
      toolName: name,
      proceed: () {
        RecentToolsService().record(id);
        GoRouter.of(context).pushNamed(
          AppRoutes.fileManagement.name,
          extra: FileSelectionConfig(
            path: Constants.rootStoragePath,
            redirectPath: route.path,
            multiSelect: multiSelect,
            minSelection: multiSelect ? minSelection : null,
            limitToExtensions: extensions,
            extra: extra,
          ),
        );
      },
    );
  }

  /// Opens the tool directly with an already-chosen [files] selection (used by
  /// the file→tool intellisense menu and the incoming-files chooser), skipping
  /// the picker. Heavy tools first pass through the opt-in rewarded-ad gate.
  void openWithFiles(BuildContext context, List<File> files) {
    RewardGate.run(
      context,
      isHeavy: isHeavy,
      toolName: name,
      proceed: () {
        RecentToolsService().record(id);
        // Pass a fresh, modifiable List<File> — selections come in as
        // unmodifiable lists and some tool views reorder/mutate the list.
        GoRouter.of(context).pushNamed(
          route.name,
          extra: <String, dynamic>{'files': List<File>.from(files), ...?extra},
        );
      },
    );
  }
}

/// The full, ordered tool catalogue.
class ToolRegistry {
  ToolRegistry._();

  static final List<ToolDef> tools = [
    // ---- PDF Tools ----
    ToolDef(id: 'merge', name: 'Merge PDF', icon: Icons.merge, category: ToolCategories.pdf, route: AppRoutes.mergePdfRoute, extensions: _pdf, multiSelect: true, minSelection: 2, maxSelection: null),
    ToolDef(id: 'split', name: 'Split PDF', icon: Icons.call_split, category: ToolCategories.pdf, route: AppRoutes.splitPdfRoute, extensions: _pdf),
    ToolDef(id: 'reorder', name: 'Reorder Pages', icon: Icons.swap_vert, category: ToolCategories.pdf, route: AppRoutes.reorderPdfPagesRoute, extensions: _pdf),
    ToolDef(id: 'organize', name: 'Organize Pages', icon: Icons.dashboard_customize_outlined, category: ToolCategories.pdf, route: AppRoutes.organizePagesRoute, extensions: _pdf),
    ToolDef(id: 'rotate', name: 'Rotate PDF', icon: Icons.rotate_right, category: ToolCategories.pdf, route: AppRoutes.rotatePdfRoute, extensions: _pdf),
    ToolDef(id: 'page-numbers', name: 'Page Numbers', icon: Icons.format_list_numbered, category: ToolCategories.pdf, route: AppRoutes.pageNumbersRoute, extensions: _pdf),
    ToolDef(id: 'crop', name: 'Crop PDF', icon: Icons.crop, category: ToolCategories.pdf, route: AppRoutes.cropPdfRoute, extensions: _pdf),
    ToolDef(id: 'add-blank', name: 'Add Blank Pages', icon: Icons.add_box_outlined, category: ToolCategories.pdf, route: AppRoutes.addBlankPagesRoute, extensions: _pdf),
    ToolDef(id: 'stamp', name: 'Stamp PDF', icon: Icons.photo_filter, category: ToolCategories.pdf, route: AppRoutes.stampPdfRoute, extensions: _pdf),
    ToolDef(id: 'qr-stamp', name: 'QR Stamp', icon: Icons.qr_code_2, category: ToolCategories.pdf, route: AppRoutes.qrStampPdfRoute, extensions: _pdf),
    ToolDef(id: 'image-overlay', name: 'Image Overlay', icon: Icons.image_outlined, category: ToolCategories.pdf, route: AppRoutes.imageOverlayRoute, extensions: _pdf),
    ToolDef(id: 'annotate', name: 'Annotate PDF', icon: Icons.draw_outlined, category: ToolCategories.pdf, route: AppRoutes.annotatePdfRoute, extensions: _pdf),
    ToolDef(id: 'fill-form', name: 'Form Editor', icon: Icons.ballot_outlined, category: ToolCategories.pdf, route: AppRoutes.formPdfRoute, extensions: _pdf, isHeavy: true),
    ToolDef(id: 'pdf-info', name: 'PDF Info', icon: Icons.info_outline, category: ToolCategories.pdf, route: AppRoutes.pdfInfoRoute, extensions: _pdf),
    ToolDef(id: 'sign', name: 'Sign PDF', icon: Icons.draw, category: ToolCategories.pdf, route: AppRoutes.signPdfRoute, extensions: _pdf),
    ToolDef(id: 'redact', name: 'Redact PDF', icon: Icons.hide_source, category: ToolCategories.pdf, route: AppRoutes.redactPdfRoute, extensions: _pdf),
    ToolDef(id: 'duplicate-pages', name: 'Duplicate Pages', icon: Icons.copy_all, category: ToolCategories.pdf, route: AppRoutes.duplicatePagesRoute, extensions: _pdf),
    ToolDef(id: 'bookmarks', name: 'Bookmarks', icon: Icons.bookmark_outline, category: ToolCategories.pdf, route: AppRoutes.bookmarksEditorRoute, extensions: _pdf),
    ToolDef(id: 'compare', name: 'Compare PDF', icon: Icons.compare, category: ToolCategories.pdf, route: AppRoutes.pdfCompareRoute, extensions: _pdf, multiSelect: true, minSelection: 2, maxSelection: 2),

    // ---- Enhance ----
    ToolDef(id: 'compress', name: 'Compress PDF', icon: Icons.compress, category: ToolCategories.enhance, route: AppRoutes.compressPdfRoute, extensions: _pdf, isHeavy: true),
    ToolDef(id: 'optimize', name: 'Optimize PDF', icon: Icons.auto_fix_high, category: ToolCategories.enhance, route: AppRoutes.optimizePdfRoute, extensions: _pdf, isHeavy: true),
    ToolDef(id: 'remove-blanks', name: 'Remove Blanks', icon: Icons.delete_sweep_outlined, category: ToolCategories.enhance, route: AppRoutes.removeBlankPagesRoute, extensions: _pdf),
    ToolDef(id: 'n-up', name: 'N-Up Layout', icon: Icons.view_module_outlined, category: ToolCategories.enhance, route: AppRoutes.nUpPdfRoute, extensions: _pdf),
    ToolDef(id: 'watermark', name: 'Watermark', icon: Icons.branding_watermark, category: ToolCategories.enhance, route: AppRoutes.watermarkPdfRoute, extensions: _pdf),
    ToolDef(id: 'grayscale', name: 'Grayscale', icon: Icons.invert_colors, category: ToolCategories.enhance, route: AppRoutes.grayscalePdfRoute, extensions: _pdf),
    ToolDef(id: 'extract-text', name: 'Extract Text', icon: Icons.text_snippet, category: ToolCategories.enhance, route: AppRoutes.extractTextRoute, extensions: _pdf, isHeavy: true),
    ToolDef(id: 'header-footer', name: 'Header/Footer', icon: Icons.view_headline, category: ToolCategories.enhance, route: AppRoutes.headerFooterRoute, extensions: _pdf),
    ToolDef(id: 'edit-metadata', name: 'Edit Metadata', icon: Icons.edit_note, category: ToolCategories.enhance, route: AppRoutes.editMetadataRoute, extensions: _pdf),

    // ---- Convert (all server-side / heavy) ----
    ToolDef(id: 'pdf-to-jpg', name: 'PDF to JPG', icon: Icons.image, category: ToolCategories.convert, route: AppRoutes.pdfToJpgRoute, extensions: _pdf, isHeavy: true),
    ToolDef(id: 'image-to-pdf', name: 'Image to PDF', icon: Icons.picture_as_pdf_outlined, category: ToolCategories.convert, route: AppRoutes.imageToPdfRoute, extensions: _imagesIn, multiSelect: true, minSelection: 1, maxSelection: null, isHeavy: true),
    ToolDef(id: 'pdf-to-word', name: 'PDF to Word', icon: Icons.description_outlined, category: ToolCategories.convert, route: AppRoutes.pdfToWordRoute, extensions: _pdf, isHeavy: true),
    ToolDef(id: 'pdf-to-excel', name: 'PDF to Excel', icon: Icons.table_chart_outlined, category: ToolCategories.convert, route: AppRoutes.pdfToExcelRoute, extensions: _pdf, isHeavy: true),
    ToolDef(id: 'pdf-to-pptx', name: 'PDF to PowerPoint', icon: Icons.slideshow_outlined, category: ToolCategories.convert, route: AppRoutes.pdfToPptxRoute, extensions: _pdf, isHeavy: true),

    // ---- Security ----
    ToolDef(id: 'protect', name: 'Protect PDF', icon: Icons.lock, category: ToolCategories.security, route: AppRoutes.protectPdfRoute, extensions: _pdf),
    ToolDef(id: 'unprotect', name: 'Unprotect PDF', icon: Icons.lock_open, category: ToolCategories.security, route: AppRoutes.unprotectPdfRoute, extensions: _pdf),
    ToolDef(id: 'repair', name: 'Repair PDF', icon: Icons.build_circle_outlined, category: ToolCategories.security, route: AppRoutes.repairPdfRoute, extensions: _pdf, isHeavy: true),
    ToolDef(id: 'flatten', name: 'Flatten PDF', icon: Icons.layers_clear, category: ToolCategories.security, route: AppRoutes.flattenPdfRoute, extensions: _pdf),

    // ---- Batch ----
    ToolDef(id: 'batch', name: 'Batch Process', icon: Icons.layers, category: ToolCategories.batch, route: AppRoutes.batchProcessRoute, extensions: _pdf, multiSelect: true, minSelection: 2, maxSelection: null, isHeavy: true),

    // ---- Image Studio (extra carries the op) ----
    ToolDef(id: 'img-compress', name: 'Compress Image', icon: Icons.compress, category: ToolCategories.imageStudio, route: AppRoutes.imageStudioRoute, extensions: ['.jpg', '.jpeg', '.png', '.bmp', '.gif'], extra: {'op': ImageStudioOp.compress}),
    ToolDef(id: 'img-to-jpg', name: 'Convert to JPG', icon: Icons.image, category: ToolCategories.imageStudio, route: AppRoutes.imageStudioRoute, extensions: ['.png', '.bmp', '.gif', '.webp'], extra: {'op': ImageStudioOp.convertToJpg}),
    ToolDef(id: 'img-from-jpg', name: 'Convert from JPG', icon: Icons.swap_horiz, category: ToolCategories.imageStudio, route: AppRoutes.imageStudioRoute, extensions: ['.jpg', '.jpeg'], extra: {'op': ImageStudioOp.convertFromJpg}),
    ToolDef(id: 'img-resize', name: 'Resize Image', icon: Icons.photo_size_select_large, category: ToolCategories.imageStudio, route: AppRoutes.imageStudioRoute, extensions: ['.jpg', '.jpeg', '.png', '.bmp'], extra: {'op': ImageStudioOp.resize}),
    ToolDef(id: 'img-filter', name: 'Image Filters', icon: Icons.auto_fix_high, category: ToolCategories.imageStudio, route: AppRoutes.imageStudioRoute, extensions: ['.jpg', '.jpeg', '.png', '.bmp'], extra: {'op': ImageStudioOp.filter}),
  ];

  /// Lookup by stable id (for recents). Returns null if not found.
  static ToolDef? byId(String id) {
    for (final t in tools) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Tools in a category, preserving declaration order.
  static List<ToolDef> byCategory(ToolCategory category) =>
      tools.where((t) => t.category == category).toList();

  /// Case-insensitive name search (for the Tools-screen search box).
  static List<ToolDef> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return tools;
    return tools.where((t) => t.name.toLowerCase().contains(q)).toList();
  }

  /// All tools that apply to a selection of [files] (by count + extensions).
  /// Powers the file→tool intellisense menu.
  static List<ToolDef> toolsForSelection(List<File> files) {
    if (files.isEmpty) return const [];
    final exts = files
        .map((f) {
          final dot = f.path.lastIndexOf('.');
          return dot == -1 ? '' : f.path.substring(dot).toLowerCase();
        })
        .toSet();
    return tools.where((t) => t.acceptsSelection(files.length, exts)).toList();
  }
}
