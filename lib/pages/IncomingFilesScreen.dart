import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/tools/tool_registry.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/utility.dart';

/// Shown when the app is opened with files from another app (the system
/// "Open with" / share sheet). Lets the user decide what to do with the
/// incoming file(s): view a PDF, open externally, or apply a tool — with the
/// applicable tools chosen via [ToolRegistry] intellisense (single-file tools
/// for one file, multi-file tools for several).
class IncomingFilesScreen extends StatelessWidget {
  final List<File> files;

  const IncomingFilesScreen({super.key, required this.files});

  bool get _singlePdf =>
      files.length == 1 && Utility.isPdf(files.first.path);

  void _view(BuildContext context) {
    final file = files.first;
    if (Utility.isPdf(file.path)) {
      GoRouter.of(context).pushReplacementNamed(
        AppRoutes.pdfFilePreviewRoute.name,
        pathParameters: {'pdfFilePath': file.path},
      );
    } else {
      final ext = Utility.fileExtension(file);
      OpenFile.open(file.path,
          type: Constants.extrnalOpenSupportedFiles[ext] ?? '*/*');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tools = ToolRegistry.toolsForSelection(files);

    return Scaffold(
      appBar: AppBar(title: const Text('Open with PDF Craft')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            files.length == 1
                ? '1 file received'
                : '${files.length} files received',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          // Show the incoming file names.
          ...files.map((f) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    Utility.isPdf(f.path)
                        ? Icons.picture_as_pdf
                        : Icons.insert_drive_file_outlined,
                    color: theme.colorScheme.primary),
                title: Text(f.path.split('/').last,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              )),
          const Divider(height: 24),

          // View (single file only).
          if (files.length == 1) ...[
            FilledButton.icon(
              onPressed: () => _view(context),
              icon: Icon(_singlePdf ? Icons.visibility : Icons.open_in_new),
              label: Text(_singlePdf ? 'View' : 'Open externally'),
            ),
            const SizedBox(height: 16),
          ],

          // Applicable tools (intellisense).
          if (tools.isNotEmpty) ...[
            const Text('Apply a tool',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...tools.map((tool) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: Icon(tool.icon, color: tool.category.color),
                    title: Text(tool.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => tool.openWithFiles(context, files),
                  ),
                )),
          ] else
            Text(
              'No in-app tools apply to these files.',
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
        ],
      ),
    );
  }
}
