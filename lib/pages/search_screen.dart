import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/recent_files_service.dart';
import 'package:pdf_craft/state/files-state/files_bloc.dart';
import 'package:pdf_craft/state/selection/selection_service.dart';
import 'package:pdf_craft/utils/constants.dart';
import 'package:pdf_craft/utils/file_sort_filter.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/banner_add.dart';
import 'package:pdf_craft/widgets/file_actions_sheet.dart';
import 'package:pdf_craft/widgets/filter_pill.dart';
import 'package:pdf_craft/widgets/file_tile.dart';
import 'package:pdf_craft/widgets/selection_bar.dart';
import 'package:pdf_craft/widgets/sort_controls.dart';
import 'package:rxdart/rxdart.dart';
import 'package:pdf_craft/theme/app_radius.dart';
import 'package:pdf_craft/widgets/app_logo.dart';

/// File search across device storage, kept consistent with the Files browser:
/// same type/sort/direction filters, the same per-file actions (long-press) and
/// the same cross-folder selection + Tools bar. The query is debounced (500ms);
/// the bloc cancels in-flight searches and caps results. An empty box shows
/// Recents instead of a blank hint.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

enum _TypeFilter { all, pdf, images, docs }

class _SearchScreenState extends State<SearchScreen> {
  late FilesBloc bloc = BlocProvider.of<FilesBloc>(context);
  final BehaviorSubject<String> searchSubject = BehaviorSubject();

  _TypeFilter _typeFilter = _TypeFilter.all;
  FileSortMode _sortMode = FileSortMode.date;
  bool _ascending = false; // newest/largest first by default

  String _query = '';
  List<File>? _recents; // null while loading

  static const _imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
  static const _docExts = ['.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt'];

  @override
  void initState() {
    super.initState();
    searchSubject
        .debounceTime(const Duration(milliseconds: 500))
        .listen((value) {
      if (!mounted) return;
      if (value.trim().isNotEmpty) {
        bloc.add(SearchFileEvent(
            path: Constants.rootStoragePath, nameLike: value.trim()));
      } else {
        bloc.add(const ResetSearchEvent());
      }
    }, cancelOnError: false);
    SelectionService().addListener(_onSelectionChanged);
    _loadRecents();
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadRecents() async {
    final files = await RecentFilesService().getRecentFiles(limit: 50);
    if (mounted) setState(() => _recents = files);
  }

  @override
  void dispose() {
    SelectionService().removeListener(_onSelectionChanged);
    SelectionService().clear();
    searchSubject.close();
    bloc.add(const ResetSearchEvent());
    super.dispose();
  }

  bool _matchesType(FileSystemEntity file) {
    final ext = Utility.fileExtension(file as File).toLowerCase();
    switch (_typeFilter) {
      case _TypeFilter.all:
        return true;
      case _TypeFilter.pdf:
        return ext == '.pdf';
      case _TypeFilter.images:
        return _imageExts.contains(ext);
      case _TypeFilter.docs:
        return _docExts.contains(ext);
    }
  }

  /// Applies the type filter + shared sort to a result/recents list.
  List<File> _shape(List<File> files) {
    final typed = files.where(_matchesType).toList();
    return applySortFilter(typed,
            mode: _sortMode, ascending: _ascending, dirsFirst: false)
        .cast<File>();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selecting = SelectionService().isActive;

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Back cancels an active selection first.
        SelectionService().clear();
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 5,
          leading: const Padding(
            padding: EdgeInsets.only(left: 16.0),
            child: AppLogo(width: 112, fit: BoxFit.fitWidth),
          ),
          leadingWidth: 112,
          bottom: PreferredSize(
            preferredSize: const Size(double.infinity, 60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextFormField(
                autofocus: true,
                onChanged: (value) {
                  searchSubject.sink.add(value);
                  setState(() => _query = value);
                },
                enableSuggestions: true,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: L10n.of(context).searchFilesHint,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.surface)),
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            _buildFilterSortBar(theme),
            Expanded(child: _buildBody(theme)),
            if (selecting) const SelectionBar(),
            const BannerAdd(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSortBar(ThemeData theme) {
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final t in _TypeFilter.values) ...[
              FilterPill(
                label: _typeLabel(t),
                selected: _typeFilter == t,
                onTap: () => setState(() => _typeFilter = t),
              ),
              const SizedBox(width: 6),
            ],
            // Divider between the type group and the sort group.
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: theme.dividerColor,
            ),
            SortControls(
              mode: _sortMode,
              ascending: _ascending,
              onModeChanged: (m) => setState(() => _sortMode = m),
              onToggleDirection: () => setState(() => _ascending = !_ascending),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // Empty box -> Recents.
    if (_query.trim().isEmpty) {
      final recents = _recents;
      if (recents == null) return _searching(theme, label: L10n.of(context).loading);
      final shaped = _shape(recents);
      if (shaped.isEmpty) return _hint(theme, L10n.of(context).noRecentFiles);
      return _list(theme, L10n.of(context).recent, shaped);
    }

    // Otherwise show search results.
    return BlocBuilder<FilesBloc, FilesState>(
      buildWhen: (p, c) => p.searchStream != c.searchStream,
      builder: (context, state) {
        final searchStream = state.searchStream;
        if (searchStream == null) return _searching(theme);
        return StreamBuilder<List<File>>(
          stream: searchStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return _searching(theme);
            final shaped = _shape(snapshot.data ?? const []);
            if (shaped.isEmpty) return _hint(theme, L10n.of(context).noMatchingFiles);
            return _list(theme, L10n.of(context).filesFound(shaped.length), shaped);
          },
        );
      },
    );
  }

  Widget _list(ThemeData theme, String header, List<File> files) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
          child: Text(header,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              return FileTile(
                file: file,
                selected: SelectionService().contains(file.path),
                onPress: () {
                  if (SelectionService().isActive) {
                    SelectionService().toggle(file);
                  } else {
                    _openFile(file);
                  }
                },
                onLongPress: () => FileActionsSheet.show(context, file,
                    allowSelect: true, onChanged: _loadRecents),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _hint(ThemeData theme, String text) => Center(
        child: Text(text,
            style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
      );

  Widget _searching(ThemeData theme, {String? label}) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(height: 12),
            Text(label ?? L10n.of(context).searching,
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      );

  String _typeLabel(_TypeFilter t) {
    switch (t) {
      case _TypeFilter.all:
        return L10n.of(context).filterAll;
      case _TypeFilter.pdf:
        return L10n.of(context).filterPdf;
      case _TypeFilter.images:
        return L10n.of(context).filterImages;
      case _TypeFilter.docs:
        return L10n.of(context).filterDocs;
    }
  }

  _openFile(File file) async {
    if (Utility.isPdf(file.path)) {
      GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,
          pathParameters: {'pdfFilePath': file.path});
    } else {
      await OpenFile.open(file.path,
          type: Constants.extrnalOpenSupportedFiles[
                  Utility.fileExtension(file)] ??
              '*/*');
    }
  }
}
