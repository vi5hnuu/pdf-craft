import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/edit_bookmarks.dart';
import 'package:pdf_craft/models/request/get_bookmarks.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pdf_craft/utils/reorder_utils.dart';

class BookmarksEditorView extends StatefulWidget {
  final File file;
  const BookmarksEditorView({super.key, required this.file});

  @override
  State<BookmarksEditorView> createState() => _BookmarksEditorViewState();
}

class _BookmarksEditorViewState extends State<BookmarksEditorView>
    with ToolResultHandler, ToolViewMixin {
  // Flat list representation: each item has title, pageIndex, indentLevel
  List<_BookmarkItem> _bookmarks = [];
  int _totalPages = 1;
  // The file currently being edited. After a save it points at the new output so
  // re-loading reflects the persisted bookmarks.
  late File _file = widget.file;
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    // Clear any leftover bookmark state from a previous tool run before loading.
    resetToolState([HttpStates.getBookmarks, HttpStates.editBookmarks]);
    _loadBookmarks();
    _loadPageCount();
  }

  Future<void> _loadPageCount() async {
    try {
      final doc = await PdfDocument.openFile(_file.path);
      if (mounted) setState(() => _totalPages = doc.pagesCount);
      await doc.close();
    } catch (_) {}
  }

  void _loadBookmarks() {
    Future.microtask(() async {
      final file = await MultipartFile.fromFile(_file.path);
      if (!mounted) return;
      pdfBloc.add(GetBookmarksEvent(getBookmarks: GetBookmarks(file: file)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(ToolStrings.name(context, 'bookmarks')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: L10n.of(context).addBookmark,
            onPressed: () => _showAddDialog(),
          ),
        ],
      ),
      body: BlocConsumer<PdfBloc, PdfState>(
        listenWhen: (p, c) {
          final getChanged = p.httpStates[HttpStates.getBookmarks] != c.httpStates[HttpStates.getBookmarks];
          final editChanged = p.httpStates[HttpStates.editBookmarks] != c.httpStates[HttpStates.editBookmarks];
          return getChanged || editChanged;
        },
        buildWhen: (p, c) {
          final getChanged = p.httpStates[HttpStates.getBookmarks] != c.httpStates[HttpStates.getBookmarks];
          final editChanged = p.httpStates[HttpStates.editBookmarks] != c.httpStates[HttpStates.editBookmarks];
          return getChanged || editChanged;
        },
        listener: (context, state) {
          final getState = state.httpStates[HttpStates.getBookmarks];
          if (getState?.done == true) {
            final raw = getState?.extras?['bookmarks'];
            if (raw is List) {
              setState(() {
                _bookmarks = _flattenBookmarks(raw, 0);
                _loadedOnce = true;
              });
            }
          } else if (getState?.error != null) {
            setState(() => _loadedOnce = true);
            NotificationService.showSnackbar(text: L10n.current.bookmarksLoadFailed, color: Colors.red);
          }

          final editState = state.httpStates[HttpStates.editBookmarks];
          if (editState?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            onToolSuccess(L10n.current.bookmarksSaved);
            final saved = editState?.extras?['savedFile'];
            if (saved is File) {
              // Keep editing the saved output and re-load so the user sees the
              // persisted outline instead of being thrown into the plain viewer.
              setState(() => _file = saved);
              _loadBookmarks();
              NotificationService.showSnackbar(
                text: L10n.current.bookmarksSaved,
                color: Colors.green,
                action: SnackBarAction(
                  label: L10n.current.viewPdf,
                  textColor: Colors.white,
                  onPressed: () => GoRouter.of(context).pushNamed(
                    AppRoutes.pdfFilePreviewRoute.name,
                    pathParameters: {'pdfFilePath': saved.path},
                  ),
                ),
              );
            }
          } else if (editState?.error != null) {
            NotificationService.showSnackbar(text: editState!.error!, color: Colors.red);
          }
        },
        builder: (context, state) {
          final getLoading = state.httpStates[HttpStates.getBookmarks]?.loading == true;
          final editState = state.httpStates[HttpStates.editBookmarks];
          final saving = editState?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: (getLoading && !_loadedOnce)
                    ? const Center(child: CircularProgressIndicator())
                    : _bookmarks.isEmpty
                        ? _buildEmptyState(theme)
                        : _buildList(theme),
              ),
              _buildSaveBar(theme, saving),
            ]),
            processingOverlay(editState, label: L10n.of(context).procWorking),
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
        Text(L10n.of(context).noBookmarksInPdf, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            L10n.of(context).bookmarksEmptyHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: Text(L10n.of(context).addFirstBookmark),
          onPressed: _showAddDialog,
        ),
      ]),
    );
  }

  Widget _buildList(ThemeData theme) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _bookmarks.length,
      onReorderItem: (oldIndex, newIndex) {
        setState(() => ReorderUtils.moveInPlace(_bookmarks, oldIndex, newIndex));
      },
      itemBuilder: (context, i) {
        final item = _bookmarks[i];
        return ListTile(
          // Stable per-item key so reorder/indent edits never mis-associate rows.
          key: ValueKey(item.id),
          contentPadding: EdgeInsets.only(left: 16 + item.indent * 20.0, right: 8),
          leading: Icon(Icons.bookmark_outline, color: theme.colorScheme.primary),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(L10n.of(context).pageNumber(item.pageIndex + 1)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            // Indent / dedent — mutate in place so the item keeps its key.
            IconButton(
              icon: const Icon(Icons.format_indent_increase, size: 18),
              tooltip: L10n.of(context).indentChild,
              onPressed: item.indent < 3 ? () => setState(() => item.indent++) : null,
            ),
            IconButton(
              icon: const Icon(Icons.format_indent_decrease, size: 18),
              tooltip: L10n.of(context).dedentUp,
              onPressed: item.indent > 0 ? () => setState(() => item.indent--) : null,
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: L10n.of(context).rename,
              onPressed: () => _showEditDialog(i),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              tooltip: L10n.of(context).delete,
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
        label: Text(L10n.of(context).saveBookmarks),
      ),
    );
  }

  void _showAddDialog() {
    final titleC = TextEditingController();
    final pageC = TextEditingController(text: '1');
    // Controllers created for a dialog are disposed when it closes; otherwise every open
    // leaks a pair.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context).addBookmarkTitle),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleC, decoration: InputDecoration(labelText: L10n.of(context).titleLabel, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
            controller: pageC,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: L10n.of(context).pageOfTotal(_totalPages), border: const OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L10n.of(context).cancel)),
          FilledButton(
            onPressed: () {
              final page = (int.tryParse(pageC.text) ?? 1).clamp(1, _totalPages) - 1;
              setState(() => _bookmarks.add(_BookmarkItem(
                title: titleC.text.trim().isEmpty ? L10n.current.bookmarkDefaultTitle : titleC.text.trim(),
                pageIndex: page,
                indent: 0,
              )));
              Navigator.pop(ctx);
            },
            child: Text(L10n.of(context).add),
          ),
        ],
      ),
    ).whenComplete(() {
      titleC.dispose();
      pageC.dispose();
    });
  }

  void _showEditDialog(int index) {
    final item = _bookmarks[index];
    final titleC = TextEditingController(text: item.title);
    final pageC = TextEditingController(text: '${item.pageIndex + 1}');
    // Disposed when the dialog closes, as above.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context).editBookmarkTitle),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleC, decoration: InputDecoration(labelText: L10n.of(context).titleLabel, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
            controller: pageC,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: L10n.of(context).pageOfTotal(_totalPages), border: const OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L10n.of(context).cancel)),
          FilledButton(
            onPressed: () {
              final page = (int.tryParse(pageC.text) ?? 1).clamp(1, _totalPages) - 1;
              // Mutate in place so the row keeps its stable key.
              setState(() {
                item.title = titleC.text.trim().isEmpty ? item.title : titleC.text.trim();
                item.pageIndex = page;
              });
              Navigator.pop(ctx);
            },
            child: Text(L10n.of(context).actionSave),
          ),
        ],
      ),
    ).whenComplete(() {
      titleC.dispose();
      pageC.dispose();
    });
  }

  Future<void> _onSave() async {
    final tree = _buildTree(_bookmarks);
    final file = await MultipartFile.fromFile(_file.path);
    if (!mounted) return;
    runTool((cancelToken) => EditBookmarksEvent(
          editBookmarks: EditBookmarks(
            bookmarksJson: jsonEncode(tree),
            file: file,
          ),
          cancelToken: cancelToken,
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
      while (parentStack.length > depth + 1) {
        parentStack.removeLast();
      }
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
  static int _seq = 0;
  // Stable identity for list keys, independent of position/content edits.
  final int id;
  String title;
  int pageIndex;
  int indent;
  _BookmarkItem({required this.title, required this.pageIndex, required this.indent})
      : id = _seq++;
}
