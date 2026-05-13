import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/file-selection-config.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/FavoritesService.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/singletons/RecentFilesService.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/StoragePermissions.dart';
import 'package:pdf_craft/widgets/BannerAdd.dart';
import 'package:pdf_craft/widgets/StorageTile.dart';
import 'package:rxdart/rxdart.dart';

class StorageStats {
  final int totalItemsInRoot;
  final int totalItemsInDownloads;
  final int totalItemsInDocuments;
  final int totalProcessedFiles;
  final int totalFileInBin;
  final bool isLoading;

  StorageStats(
      {required this.totalItemsInRoot,
      required this.totalItemsInDownloads,
      this.isLoading = false,
      required this.totalItemsInDocuments,
      required this.totalProcessedFiles,
      required this.totalFileInBin});

  StorageStats copyWith({
    int? totalItemsInRoot,
    int? totalItemsInDownloads,
    int? totalItemsInDocuments,
    int? totalProcessedFiles,
    int? totalFileInBin,
    bool? isLoading,
  }) {
    return StorageStats(
        totalItemsInRoot: totalItemsInRoot ?? this.totalItemsInRoot,
        totalItemsInDownloads:
            totalItemsInDownloads ?? this.totalItemsInDownloads,
        isLoading: isLoading ?? this.isLoading,
        totalItemsInDocuments:
            totalItemsInDocuments ?? this.totalItemsInDocuments,
        totalProcessedFiles: totalProcessedFiles ?? this.totalProcessedFiles,
        totalFileInBin: totalFileInBin ?? this.totalFileInBin);
  }

  static StorageStats zero() {
    return StorageStats(
        isLoading: true,
        totalItemsInRoot: 0,
        totalItemsInDownloads: 0,
        totalItemsInDocuments: 0,
        totalProcessedFiles: 0,
        totalFileInBin: 0);
  }
}

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  BehaviorSubject<StorageStats> storageStats =
      BehaviorSubject.seeded(StorageStats.zero());
  List<File> _recentPdfs = [];
  List<File> _favoritePdfs = [];

  @override
  void initState() {
    _loadStats();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_recentPdfs.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8),
                child: Text(
                  'Recent Files',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                height: 130,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _recentPdfs.length,
                  itemBuilder: (context, index) {
                    final pdf = _recentPdfs[index];
                    final name = pdf.path.split('/').last;
                    return GestureDetector(
                      onTap: () => router.pushNamed(
                          AppRoutes.pdfFilePreviewRoute.name,
                          pathParameters: {'pdfFilePath': pdf.path}),
                      child: Card(
                        elevation: 0,
                        color: theme.cardColor,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: SizedBox(
                          width: 90,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.picture_as_pdf,
                                    color: primary, size: 36),
                                const SizedBox(height: 8),
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (_favoritePdfs.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8),
                child: Text(
                  'Favorites',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                height: 130,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _favoritePdfs.length,
                  itemBuilder: (context, index) {
                    final pdf = _favoritePdfs[index];
                    final name = pdf.path.split('/').last;
                    return GestureDetector(
                      onTap: () => router.pushNamed(
                          AppRoutes.pdfFilePreviewRoute.name,
                          pathParameters: {'pdfFilePath': pdf.path}),
                      child: Card(
                        elevation: 0,
                        color: theme.cardColor,
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: SizedBox(
                          width: 90,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 36),
                                const SizedBox(height: 8),
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const Padding(
              padding: EdgeInsets.only(left: 18.0, top: 24.0),
              child: Row(
                children: [
                  Text(
                    'My Storage',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                                  excludeShowingDirsPath: [
                                    Constants.binDirPath
                                  ],
                                  path: Constants.rootStoragePath))
                          .then((value) => _loadStats()),
                      trailing: stats == null || stats.isLoading
                          ? loadingWidget
                          : Text(stats.totalItemsInRoot.toString(),
                              style: const TextStyle(fontSize: 16)),
                      leadingIconSvgPath: 'assets/icons/hard-disk.svg',
                      title: 'Internal Storage',
                    ),
                    StorageTile(
                      onTap: () => router
                          .pushNamed(AppRoutes.filesListingRoute.name,
                              extra: FileSelectionConfig(
                                  excludeShowingDirsPath: [
                                    Constants.binDirPath
                                  ],
                                  path: Constants.downloadsStoragePath))
                          .then((value) => _loadStats()),
                      trailing: stats == null || stats.isLoading
                          ? loadingWidget
                          : Text(stats.totalItemsInDownloads.toString(),
                              style: const TextStyle(fontSize: 16)),
                      leadingIconSvgPath: 'assets/icons/downloads.svg',
                      title: 'Downloads',
                    ),
                    StorageTile(
                      onTap: () => router
                          .pushNamed(AppRoutes.filesListingRoute.name,
                              extra: FileSelectionConfig(
                                  excludeShowingDirsPath: [
                                    Constants.binDirPath
                                  ],
                                  path: Constants.documentsStoragePath))
                          .then((value) => _loadStats()),
                      trailing: stats == null || stats.isLoading
                          ? loadingWidget
                          : Text(stats.totalItemsInDocuments.toString(),
                              style: const TextStyle(fontSize: 16)),
                      leadingIconSvgPath: 'assets/icons/documents.svg',
                      title: 'Documents',
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
                      leadingIconSvgPath: 'assets/icons/folder-management.svg',
                      title: 'Processed Files',
                    ),
                  ],
                );
              },
            ),
            const BannerAdd(),
            const Padding(
              padding: EdgeInsets.only(left: 18.0, top: 12.0),
              child: Row(
                children: [
                  Text(
                    'Others',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                return StorageTile(
                  onTap: _goToBin,
                  trailing: stats == null || stats.isLoading
                      ? loadingWidget
                      : Text(stats.totalFileInBin.toString(),
                          style: const TextStyle(fontSize: 16)),
                  leadingIconSvgPath: 'assets/icons/recycle-bin.svg',
                  title: 'Bin',
                );
              },
            ),
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
        storageStats.sink.add(storageStats.value.copyWith(isLoading: true));
        final stats = await Future.wait([
          Directory(Constants.rootStoragePath).list(followLinks: false).length,
          Directory(Constants.downloadsStoragePath)
              .list(followLinks: false)
              .length,
          Directory(Constants.documentsStoragePath)
              .list(followLinks: false)
              .length,
          Directory(Constants.processedDirPath).list(followLinks: false).length,
          Directory(Constants.binDirPath).list(followLinks: false).length,
        ]);
        storageStats.sink.add(StorageStats(
            totalItemsInRoot: stats[0],
            totalItemsInDownloads: stats[1],
            totalItemsInDocuments: stats[2],
            totalProcessedFiles: stats[3],
            totalFileInBin: stats[4]));

        final recents = await RecentFilesService().getRecentFiles(limit: 10);
        final favorites = await FavoritesService().getFavorites();
        if (mounted) setState(() {
          _recentPdfs = recents;
          _favoritePdfs = favorites;
        });
      } else {
        NotificationService.showSnackbar(
            text: 'Storage permission denied', color: Colors.red);
      }
    } catch (e) {
      NotificationService.showSnackbar(
          text: 'Something went wrong', color: Colors.red);
    }
  }

  Future<void> _createMainDirs() async {
    final mainDirs = [
      Constants.downloadsStoragePath,
      Constants.documentsStoragePath,
      Constants.processedDirPath,
      Constants.binDirPath
    ];
    for (var dirPath in mainDirs) {
      final dir = Directory(dirPath);
      if (!(await dir.exists())) {
        dir.create(recursive: true);
      }
    }
  }

  void _goToBin() {
    GoRouter.of(context)
        .pushNamed(AppRoutes.filesListingRoute.name,
            extra: FileSelectionConfig(path: Constants.binDirPath))
        .then((value) => _loadStats());
  }
}
