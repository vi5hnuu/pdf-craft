import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_craft/theme/app_radius.dart';
import 'package:pdf_craft/widgets/PageSelectorGrid.dart';
import 'package:pdfx/pdfx.dart';

/// Chooses which pages a tool applies to, by tapping thumbnails.
///
/// Several tools — crop, greyscale, scale, resize — rewrote every page with no way to narrow
/// them, so fixing three bad scans in an eighty-page document meant changing all eighty. This is
/// the one control they share, so "which pages?" looks and behaves the same wherever it is asked.
///
/// Collapsed by default and empty by default, because applying to the whole document is the
/// common case and should not require a decision. The document is opened lazily on first expand:
/// a tool the user never narrows should not pay to parse the file.
class PageRangeSelector extends StatefulWidget {
  final File file;

  /// 0-indexed selected pages. Empty means every page.
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final Color accent;

  /// Opens straight into the grid, skipping the collapsed summary row — used when the caller
  /// has already committed the screen space, as the modal form has.
  final bool startExpanded;

  const PageRangeSelector({
    super.key,
    required this.file,
    required this.selected,
    required this.onChanged,
    this.accent = Colors.blue,
    this.startExpanded = false,
  });

  @override
  State<PageRangeSelector> createState() => _PageRangeSelectorState();

  /// Presents the same selection in a modal sheet, for screens whose layout cannot give up
  /// room inline — the crop editor, whose canvas deliberately fills what is left of the screen
  /// so dragging a handle never fights a scroll.
  ///
  /// Returns the new selection, or null if the sheet was dismissed without changing anything.
  static Future<Set<int>?> show(
    BuildContext context, {
    required File file,
    required Set<int> selected,
    Color accent = Colors.blue,
  }) {
    return showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _PageRangeSheet(
        file: file,
        initial: selected,
        accent: accent,
      ),
    );
  }
}

/// The modal form of [PageRangeSelector], holding its own draft selection until confirmed.
class _PageRangeSheet extends StatefulWidget {
  final File file;
  final Set<int> initial;
  final Color accent;

  const _PageRangeSheet({required this.file, required this.initial, required this.accent});

  @override
  State<_PageRangeSheet> createState() => _PageRangeSheetState();
}

class _PageRangeSheetState extends State<_PageRangeSheet> {
  late Set<int> _draft = Set<int>.from(widget.initial);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Apply to', style: theme.textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: _draft.isEmpty ? null : () => setState(_draft.clear),
                  child: const Text('Every page'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.5,
              child: PageRangeSelector(
                file: widget.file,
                selected: _draft,
                accent: widget.accent,
                startExpanded: true,
                onChanged: (pages) => setState(() => _draft = pages),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context, _draft),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageRangeSelectorState extends State<PageRangeSelector> {
  late bool _open = widget.startExpanded;
  PdfDocument? _document;
  int _totalPages = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.startExpanded) _load();
  }

  @override
  void dispose() {
    _document?.close();
    super.dispose();
  }

  Future<void> _toggleOpen() async {
    if (_open) {
      setState(() => _open = false);
      return;
    }
    setState(() => _open = true);
    await _load();
  }

  Future<void> _load() async {
    if (_document != null || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final document = await PdfDocument.openFile(widget.file.path);
      if (!mounted) {
        await document.close();
        return;
      }
      setState(() {
        _document = document;
        _totalPages = document.pagesCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not read the pages of this file.';
      });
    }
  }

  String get _summary {
    if (widget.selected.isEmpty) return 'All pages';
    if (widget.selected.length == 1) return 'Page ${widget.selected.first + 1}';
    final sorted = widget.selected.toList()..sort();
    return '${sorted.length} pages (${sorted.first + 1}–${sorted.last + 1})';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.startExpanded)
          Row(
            children: [
              Text('Apply to', style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton(
                onPressed: _toggleOpen,
                child: Text('$_summary · ${_open ? 'done' : 'change'}'),
              ),
            ],
          ),
        if (_open) ...[
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            )
          else if (_document != null) ...[
            // Inline the grid gets a fixed slice of the screen; presented modally the caller has
            // already decided how tall the sheet is, so it takes what is left.
            _Sized(
              expand: widget.startExpanded,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: AppRadius.surfaceRadius,
                ),
                child: PageSelectorGrid(
                  document: _document!,
                  totalPages: _totalPages,
                  selected: widget.selected,
                  accent: widget.accent,
                  onToggle: (index) {
                    final next = Set<int>.from(widget.selected);
                    if (!next.remove(index)) next.add(index);
                    widget.onChanged(next);
                  },
                ),
              ),
            ),
            if (!widget.startExpanded)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.selected.isEmpty
                      ? null
                      : () => widget.onChanged(<int>{}),
                  child: const Text('Clear — apply to every page'),
                ),
              ),
          ],
        ],
      ],
    );
  }
}


/// Gives its child either a fixed height or whatever vertical space is left.
///
/// Exists so the grid can be laid out both ways without duplicating the tree around it.
class _Sized extends StatelessWidget {
  final bool expand;
  final Widget child;

  const _Sized({required this.expand, required this.child});

  @override
  Widget build(BuildContext context) =>
      expand ? Expanded(child: child) : SizedBox(height: 260, child: child);
}
