import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/file-selection-config.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/widgets/BannerAdd.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    const pdf = ['.pdf'];
    const images = ['.jpg', '.png', '.jpeg'];

    final categories = [
      _ToolCategory(
        name: 'PDF Tools',
        icon: Icons.picture_as_pdf,
        color: const Color(0xFFE53935),
        tools: [
          _ToolItem(name: 'Merge PDF', icon: Icons.merge, onTap: () => router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(path: Constants.rootStoragePath, redirectPath: AppRoutes.mergePdfRoute.path, multiSelect: true, minSelection: 2, limitToExtensions: pdf))),
          _ToolItem(name: 'Split PDF', icon: Icons.call_split, onTap: () => router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(path: Constants.rootStoragePath, redirectPath: AppRoutes.splitPdfRoute.path, multiSelect: false, limitToExtensions: pdf))),
          _ToolItem(name: 'Reorder Pages', icon: Icons.swap_vert, onTap: () => router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(path: Constants.rootStoragePath, redirectPath: AppRoutes.reorderPdfPagesRoute.path, multiSelect: false, limitToExtensions: pdf))),
          _ToolItem(name: 'Rotate PDF', icon: Icons.rotate_right, onTap: () => router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(path: Constants.rootStoragePath, redirectPath: AppRoutes.rotatePdfRoute.path, multiSelect: false, limitToExtensions: pdf))),
          _ToolItem(name: 'Page Numbers', icon: Icons.format_list_numbered, onTap: () => router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(path: Constants.rootStoragePath, redirectPath: AppRoutes.pageNumbersRoute.path, multiSelect: false, limitToExtensions: pdf))),
          _ToolItem(name: 'Crop PDF', icon: Icons.crop, onTap: () => router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(path: Constants.rootStoragePath, redirectPath: AppRoutes.cropPdfRoute.path, multiSelect: false, limitToExtensions: pdf))),
        ],
      ),
      _ToolCategory(
        name: 'Enhance',
        icon: Icons.auto_fix_high,
        color: const Color(0xFF7B1FA2),
        tools: [
          _ToolItem(name: 'Compress PDF', icon: Icons.compress, onTap: () => router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(path: Constants.rootStoragePath, redirectPath: AppRoutes.compressPdfRoute.path, multiSelect: false, limitToExtensions: pdf))),
          _ToolItem(name: 'Watermark', icon: Icons.branding_watermark, onTap: () => router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(path: Constants.rootStoragePath, redirectPath: AppRoutes.watermarkPdfRoute.path, multiSelect: false, limitToExtensions: pdf))),
          _ToolItem(name: 'Grayscale', icon: Icons.invert_colors, onTap: () => router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(path: Constants.rootStoragePath, redirectPath: AppRoutes.grayscalePdfRoute.path, multiSelect: false, limitToExtensions: pdf))),
          _ToolItem(name: 'Extract Text', icon: Icons.text_snippet, onTap: () => router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(path: Constants.rootStoragePath, redirectPath: AppRoutes.extractTextRoute.path, multiSelect: false, limitToExtensions: pdf))),
        ],
      ),
      _ToolCategory(
        name: 'Convert',
        icon: Icons.swap_horiz,
        color: const Color(0xFF0288D1),
        tools: [
          _ToolItem(name: 'PDF to JPG', icon: Icons.image, onTap: () => router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(path: Constants.rootStoragePath, redirectPath: AppRoutes.pdfToJpgRoute.path, multiSelect: false, limitToExtensions: pdf))),
          _ToolItem(name: 'Image to PDF', icon: Icons.picture_as_pdf_outlined, onTap: () => router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(path: Constants.rootStoragePath, redirectPath: AppRoutes.imageToPdfRoute.path, multiSelect: true, limitToExtensions: images))),
        ],
      ),
      _ToolCategory(
        name: 'Security',
        icon: Icons.security,
        color: const Color(0xFF388E3C),
        tools: [
          _ToolItem(name: 'Protect PDF', icon: Icons.lock, onTap: () => router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(path: Constants.rootStoragePath, redirectPath: AppRoutes.protectPdfRoute.path, multiSelect: false, limitToExtensions: pdf))),
          _ToolItem(name: 'Unprotect PDF', icon: Icons.lock_open, onTap: () => router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(path: Constants.rootStoragePath, redirectPath: AppRoutes.unprotectPdfRoute.path, multiSelect: false, limitToExtensions: pdf))),
        ],
      ),
    ];

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text('All Tools', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
            ),
          ),
          for (int i = 0; i < categories.length; i++) ...[
            SliverToBoxAdapter(child: _CategorySection(category: categories[i])),
            // Banner ad after every 2nd category
            if ((i + 1) % 2 == 0)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: BannerAdd(),
                ),
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _ToolCategory {
  final String name;
  final IconData icon;
  final Color color;
  final List<_ToolItem> tools;

  const _ToolCategory({required this.name, required this.icon, required this.color, required this.tools});
}

class _ToolItem {
  final String name;
  final IconData icon;
  final VoidCallback onTap;

  const _ToolItem({required this.name, required this.icon, required this.onTap});
}

class _CategorySection extends StatelessWidget {
  final _ToolCategory category;

  const _CategorySection({required this.category});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(category.icon, color: category.color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                category.name,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: category.color, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: category.tools.map((tool) => _ToolCard(tool: tool, accentColor: category.color)).toList(),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final _ToolItem tool;
  final Color accentColor;

  const _ToolCard({required this.tool, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: tool.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(tool.icon, color: accentColor, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              tool.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
