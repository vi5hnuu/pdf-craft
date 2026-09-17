import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/file_selection_config.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/favorites_service.dart';
import 'package:pdf_craft/singletons/file_store.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/singletons/recent_files_service.dart';
import 'package:pdf_craft/utils/constants.dart';
import 'package:pdf_craft/utils/storage_permissions.dart';
import 'package:pdf_craft/widgets/banner_add.dart';
import 'package:pdf_craft/widgets/file_actions_sheet.dart';
import 'package:pdf_craft/widgets/file_preview_card.dart';
import 'package:pdf_craft/widgets/storage_tile.dart';
import 'package:rxdart/rxdart.dart';

class StorageStats {
  final int totalItemsInRoot;
  final int totalItemsInDownloads;
  final int totalItemsInDocuments;
  final int totalProcessedFiles;
  final bool isLoading;

  StorageStats(
      {required this.totalItemsInRoot,
      required this.totalItemsInDownloads,
      this.isLoading = false,
      required this.totalItemsInDocuments,
      required this.totalProcessedFiles});

  StorageStats copyWith({
    int? totalItemsInRoot,
    int? totalItemsInDownloads,
    int? totalItemsInDocuments,
    int? totalProcessedFiles,
    bool? isLoading,
  }) {
    return StorageStats(
        totalItemsInRoot: totalItemsInRoot ?? this.totalItemsInRoot,
        totalItemsInDownloads:
            totalItemsInDownloads ?? this.totalItemsInDownloads,
        isLoading: isLoading ?? this.isLoading,
        totalItemsInDocuments:
            totalItemsInDocuments ?? this.totalItemsInDocuments,
        totalProcessedFiles: totalProcessedFiles ?? this.totalProcessedFiles);
  }

  static StorageStats zero() {
    return StorageStats(
        isLoading: true,
        totalItemsInRoot: 0,
        totalItemsInDownloads: 0,
        totalItemsInDocuments: 0,
        totalProcessedFiles: 0);
  }
}

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> with WidgetsBindingObserver {
  BehaviorSubject<StorageStats> storageStats =
      BehaviorSubject.seeded(StorageStats.zero());
  List<File> _recentPdfs = [];
  List<File> _favoritePdfs = [];

  @override
  void initState() {
    _loadStats();
    // This tab lives inside a StatefulShellRoute, so it is kept alive across tab switches and
    // never rebuilt. Without these two subscriptions the listing showed whatever was on disk
    // when the app started: run a tool, come back, and the new file simply was not there.
    FileStore().addListener(_refresh);
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    FileStore().removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    storageStats.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Files also arrive from outside the app — a download, a file manager, another app's share.
    // Coming back to the foreground is the one moment we know something may have changed.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  /// Re-scans without touching permissions. [_loadStats] asks for storage access, which is the
  /// right thing on first mount but wrong on every later refresh: it would put a system prompt
  /// in front of the user each time a tool finished.
  Future<void> _refresh() async {
    if (!mounted) return;
    if (!await StoragePermissions.isStoragePermissionGranted()) return;
    await _reloadListings();
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_recentPdfs.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 8, top: 24.0, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      L10n.of(context).filesRecentFiles,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    // The home preview is capped at 10; offer the full list.
                    TextButton(
                      onPressed: () => router
                          .pushNamed(AppRoutes.recentsRoute.name)
                          .then((_) => _loadStats()),
                      child: Text(L10n.of(context).seeMore),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _recentPdfs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final pdf = _recentPdfs[index];
                    return FilePreviewCard(
                      file: pdf,
                      onTap: () => router.pushNamed(
                          AppRoutes.pdfFilePreviewRoute.name,
                          pathParameters: {'pdfFilePath': pdf.path}),
                      onLongPress: () => FileActionsSheet.show(context, pdf,
                          onChanged: _loadStats),
                    );
                  },
                ),
              ),
            ],
            if (_favoritePdfs.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8),
                child: Text(
                  L10n.of(context).favorites,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _favoritePdfs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final pdf = _favoritePdfs[index];
                    return FilePreviewCard(
                      file: pdf,
                      onTap: () => router.pushNamed(
                          AppRoutes.pdfFilePreviewRoute.name,
                          pathParameters: {'pdfFilePath': pdf.path}),
                      onLongPress: () => FileActionsSheet.show(context, pdf,
                          onChanged: _loadStats),
                      badge: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.star,
                            color: Colors.amber, size: 16),
                      ),
                    );
                  },
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(left: 18.0, top: 24.0),
              child: Row(
                children: [
                  Text(
                    L10n.of(context).filesMyStorage,
                    style:
                        const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            StreamBuilder<StorageStats>(
              stream: storageStats.stream,
              builder: (context, snapshot) {
                final stats = snapshot.data;
                final loadingWidget = SizedBox(
                  width: 16,
                  child: SpinKitThreeBounce(
                      color: theme.colorScheme.onSurface, size: 8),
                );
                return Column(
                  children: [
                    StorageTile(
                      onTap: () => router
                          .pushNamed(AppRoutes.filesListingRoute.name,
                              extra: FileSelectionConfig(
                                  path: Constants.rootStoragePath))
                          .then((value) => _loadStats()),
                      trailing: stats == null || stats.isLoading
                          ? loadingWidget
                          : Text(stats.totalItemsInRoot.toString(),
                              style: const TextStyle(fontSize: 16)),
                      icon: Icons.phone_android_rounded,
                      title: L10n.of(context).storageInternal,
                    ),
                    StorageTile(
                      onTap: () => router
                          .pushNamed(AppRoutes.filesListingRoute.name,
                              extra: FileSelectionConfig(
                                  path: Constants.downloadsStoragePath))
                          .then((value) => _loadStats()),
                      trailing: stats == null || stats.isLoading
                          ? loadingWidget
                          : Text(stats.totalItemsInDownloads.toString(),
                              style: const TextStyle(fontSize: 16)),
                      icon: Icons.download_rounded,
                      title: L10n.of(context).storageDownloads,
                    ),
                    StorageTile(
                      onTap: () => router
                          .pushNamed(AppRoutes.filesListingRoute.name,
                              extra: FileSelectionConfig(
                                  path: Constants.documentsStoragePath))
                          .then((value) => _loadStats()),
                      trailing: stats == null || stats.isLoading
                          ? loadingWidget
                          : Text(stats.totalItemsInDocuments.toString(),
                              style: const TextStyle(fontSize: 16)),
                      icon: Icons.description_rounded,
                      title: L10n.of(context).storageDocuments,
                    ),
                    StorageTile(
                      onTap: () => router
                          .pushNamed(AppRoutes.filesListingRoute.name,
                              extra: FileSelectionConfig(
                                  path: Constants.processedDirPath))
                          .then((value) => _loadStats()),
                      trailing: stats == null || stats.isLoading
                          ? loadingWidget
                          : Text(stats.totalProcessedFiles.toString(),
                              style: const TextStyle(fontSize: 16)),
                      icon: Icons.auto_awesome_motion_rounded,
                      title: L10n.of(context).storageProcessed,
                    ),
                  ],
                );
              },
            ),
            const BannerAdd(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  _loadStats() async {
    try {
      if (await StoragePermissions.requestStoragePermissions()) {
        await _createMainDirs();
        await _reloadListings();
      } else {
        // A bare "denied" toast is a dead end once Android stops showing the dialog: the
        // only way to grant is Settings, and nothing here said so. ErrorPage already has
        // that recovery flow, so route to it rather than duplicating it.
        if (!mounted) return;
        if (await StoragePermissions.isPermanentlyDenied()) {
          if (mounted) GoRouter.of(context).goNamed(AppRoutes.errorRoute.name);
        } else {
          NotificationService.showSnackbar(
              text: L10n.current.errStoragePermissionNeeded,
              color: Colors.red);
        }
      }
    } catch (e) {
      NotificationService.showSnackbar(
          text: L10n.current.errSomethingWrong, color: Colors.red);
    }
  }

  /// Counts the storage folders and reloads the recent/favourite rows.
  ///
  /// Split out of [_loadStats] so a refresh can re-scan without re-requesting permissions.
  Future<void> _reloadListings() async {
    storageStats.sink.add(storageStats.value.copyWith(isLoading: true));
    final stats = await Future.wait([
      Directory(Constants.rootStoragePath).list(followLinks: false).length,
      Directory(Constants.downloadsStoragePath).list(followLinks: false).length,
      Directory(Constants.documentsStoragePath).list(followLinks: false).length,
      Directory(Constants.processedDirPath).list(followLinks: false).length,
    ]);
    if (storageStats.isClosed) return;
    storageStats.sink.add(StorageStats(
        totalItemsInRoot: stats[0],
        totalItemsInDownloads: stats[1],
        totalItemsInDocuments: stats[2],
        totalProcessedFiles: stats[3]));

    final recents = await RecentFilesService().getRecentFiles(limit: 10);
    final favorites = await FavoritesService().getFavorites();
    if (!mounted) return;
    setState(() {
      _recentPdfs = recents;
      _favoritePdfs = favorites;
    });
  }

  Future<void> _createMainDirs() async {
    final mainDirs = [
      Constants.downloadsStoragePath,
      Constants.documentsStoragePath,
      Constants.processedDirPath
    ];
    for (var dirPath in mainDirs) {
      final dir = Directory(dirPath);
      if (!(await dir.exists())) {
        dir.create(recursive: true);
      }
    }
  }

}
