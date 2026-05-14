import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/edit-bookmarks.dart';
import 'package:pdf_craft/models/request/get-bookmarks.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';
import 'package:pdfx/pdfx.dart';

class BookmarksEditorView extends StatefulWidget {
  final File file;
  const BookmarksEditorView({super.key, required this.file});

  @override
  State<BookmarksEditorView> createState() => _BookmarksEditorViewState();
}

class _BookmarksEditorViewState extends State<BookmarksEditorView> {
  // Flat list representation: each item has title, pageIndex, indentLevel
  List<_BookmarkItem> _bookmarks = [];
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    _loadBookmarks();
    _loadPageCount();
  }

  Future<void> _loadPageCount() async {
    try {
      final doc = await PdfDocument.openFile(widget.file.path);
      if (mounted) setState(() => _totalPages = doc.pagesCount);
      await doc.close();
    } catch (_) {}
  }

  void _loadBookmarks() {
    Future.microtask(() async {
      final file = await MultipartFile.fromFile(widget.file.path);
      if (!mounted) return;
      BlocProvider.of<PdfBloc>(context).add(GetBookmarksEvent(
        getBookmarks: GetBookmarks(file: file),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Bookmarks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Add bookmark',
            onPressed: () => _showAddDialog(),
          ),
        ],
      ),
      body: BlocConsumer<PdfBloc, PdfState>(
        listenWhen: (p, c) {
          final getChanged = p.httpStates[HttpStates.GET_BOOKMARKS] != c.httpStates[HttpStates.GET_BOOKMARKS];
          final editChanged = p.httpStates[HttpStates.EDIT_BOOKMARKS] != c.httpStates[HttpStates.EDIT_BOOKMARKS];
          return getChanged || editChanged;
        },
        buildWhen: (p, c) {
          final getChanged = p.httpStates[HttpStates.GET_BOOKMARKS] != c.httpStates[HttpStates.GET_BOOKMARKS];
          final editChanged = p.httpStates[HttpStates.EDIT_BOOKMARKS] != c.httpStates[HttpStates.EDIT_BOOKMARKS];
          return getChanged || editChanged;
        },
        listener: (context, state) {
          final getState = state.httpStates[HttpStates.GET_BOOKMARKS];
          if (getState?.done == true) {
            final raw = getState?.extras?['bookmarks'];
            if (raw is List) {
              setState(() => _bookmarks = _flattenBookmarks(raw, 0));
            }
          } else if (getState?.error != null) {
            NotificationService.showSnackbar(text: 'Could not load bookmarks', color: Colors.red);
          }

          final editState = state.httpStates[HttpStates.EDIT_BOOKMARKS];
          if (editState?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'Bookmarks saved', color: Colors.green);
            if (editState?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(
                AppRoutes.pdfFilePreviewRoute.name,
                pathParameters: {'pdfFilePath': (editState!.extras!['savedFile'] as File).path},
              );
            }
          } else if (editState?.error != null) {
            NotificationService.showSnackbar(text: editState!.error!, color: Colors.red);
          }
        },
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.GET_BOOKMARKS]?.loading == true ||
              state.httpStates[HttpStates.EDIT_BOOKMARKS]?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: loading && _bookmarks.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _bookmarks.isEmpty
                        ? _buildEmptyState(theme)
                        : _buildList(theme),
              ),
              _buildSaveBar(theme, loading),
            ]),
            LoadingOverlay(httpState: state.httpStates[HttpStates.EDIT_BOOKMARKS]),
          ]);
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bookmark_border, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        const Text('No bookmarks found'),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add first bookmark'),
          onPressed: _showAddDialog,
        ),
      ]),
    );
  }

  Widget _buildList(ThemeData theme) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _bookmarks.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _bookmarks.removeAt(oldIndex);
          _bookmarks.insert(newIndex, item);
        });
      },
      itemBuilder: (context, i) {
        final item = _bookmarks[i];
        return ListTile(
          key: ValueKey(i),
          contentPadding: EdgeInsets.only(left: 16 + item.indent * 20.0, right: 8),
          leading: Icon(Icons.bookmark_outline, color: theme.colorScheme.primary),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('Page ${item.pageIndex + 1}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            // Indent / dedent
            IconButton(
              icon: const Icon(Icons.format_indent_increase, size: 18),
              tooltip: 'Indent (make child)',
              onPressed: item.indent < 3 ? () => setState(() => _bookmarks[i] = _BookmarkItem(
                title: item.title, pageIndex: item.pageIndex, indent: item.indent + 1)) : null,
            ),
            IconButton(
              icon: const Icon(Icons.format_indent_decrease, size: 18),
              tooltip: 'Dedent (move up)',
              onPressed: item.indent > 0 ? () => setState(() => _bookmarks[i] = _BookmarkItem(
                title: item.title, pageIndex: item.pageIndex, indent: item.indent - 1)) : null,
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Rename',
              onPressed: () => _showEditDialog(i),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              tooltip: 'Delete',
              onPressed: () => setState(() => _bookmarks.removeAt(i)),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildSaveBar(ThemeData theme, bool loading) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: FilledButton.icon(
        onPressed: loading ? null : _onSave,
        icon: loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_alt),
        label: const Text('Save Bookmarks'),
      ),
    );
  }

  void _showAddDialog() {
    final titleC = TextEditingController();
    final pageC = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Bookmark'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
            controller: pageC,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Page (1–$_totalPages)', border: const OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final page = (int.tryParse(pageC.text) ?? 1).clamp(1, _totalPages) - 1;
              setState(() => _bookmarks.add(_BookmarkItem(
                title: titleC.text.trim().isEmpty ? 'Bookmark' : titleC.text.trim(),
                pageIndex: page,
                indent: 0,
              )));
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(int index) {
    final item = _bookmarks[index];
    final titleC = TextEditingController(text: item.title);
    final pageC = TextEditingController(text: '${item.pageIndex + 1}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Bookmark'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
            controller: pageC,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Page (1–$_totalPages)', border: const OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final page = (int.tryParse(pageC.text) ?? 1).clamp(1, _totalPages) - 1;
              setState(() => _bookmarks[index] = _BookmarkItem(
                title: titleC.text.trim().isEmpty ? item.title : titleC.text.trim(),
                pageIndex: page,
                indent: item.indent,
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _onSave() async {
    final tree = _buildTree(_bookmarks);
    BlocProvider.of<PdfBloc>(context).add(EditBookmarksEvent(
      editBookmarks: EditBookmarks(
        bookmarksJson: jsonEncode(tree),
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  // Converts flat list with indent levels back to a properly nested tree.
  // Uses a parent-stack: index N holds the children list for depth N-1.
  List<Map<String, dynamic>> _buildTree(List<_BookmarkItem> flat) {
    final root = <Map<String, dynamic>>[];
    // parentStack[depth] = children list to append into at that depth
    final parentStack = <List<Map<String, dynamic>>>[root];

    for (final item in flat) {
      final node = <String, dynamic>{
        'title': item.title,
        'pageIndex': item.pageIndex,
        'children': <Map<String, dynamic>>[],
      };
      // Ensure stack is tall enough (clamp to avoid orphan items from invalid indent jumps)
      final depth = item.indent.clamp(0, parentStack.length - 1);
      while (parentStack.length > depth + 1) parentStack.removeLast();
      parentStack.last.add(node);
      parentStack.add(node['children'] as List<Map<String, dynamic>>);
    }
    return root;
  }

  // Flattens nested bookmark JSON into a flat list with indent levels
  List<_BookmarkItem> _flattenBookmarks(List<dynamic> raw, int indent) {
    final result = <_BookmarkItem>[];
    for (final item in raw) {
      if (item is! Map) continue;
      result.add(_BookmarkItem(
        title: item['title'] as String? ?? '',
        pageIndex: (item['pageIndex'] as num?)?.toInt() ?? 0,
        indent: indent,
      ));
      final children = item['children'];
      if (children is List && children.isNotEmpty) {
        result.addAll(_flattenBookmarks(children, indent + 1));
      }
    }
    return result;
  }
}

class _BookmarkItem {
  String title;
  int pageIndex;
  int indent;
  _BookmarkItem({required this.title, required this.pageIndex, required this.indent});
}
