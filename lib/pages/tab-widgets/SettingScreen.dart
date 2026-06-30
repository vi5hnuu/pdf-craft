import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/theme/theme_manager.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  late ThemeMode _themeMode;
  int _processedFileCount = 0;
  String _processedDirSize = '0 KB';

  @override
  void initState() {
    super.initState();
    _themeMode = ThemeManager().mode;
    _loadProcessedStats();
  }

  Future<void> _loadProcessedStats() async {
    final dir = Directory(Constants.processedDirPath);
    if (!dir.existsSync()) return;
    final files = dir.listSync().whereType<File>().toList();
    int totalBytes = 0;
    for (final f in files) {
      try { totalBytes += f.lengthSync(); } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _processedFileCount = files.length;
        _processedDirSize = _formatBytes(totalBytes);
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _setTheme(ThemeMode mode) async {
    await ThemeManager().setMode(mode);
    setState(() => _themeMode = mode);
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Processed Files'),
        content: Text('Delete all $_processedFileCount files in the processed folder?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final dir = Directory(Constants.processedDirPath);
    if (dir.existsSync()) {
      for (final entity in dir.listSync()) {
        try { entity.deleteSync(recursive: true); } catch (_) {}
      }
    }
    await _loadProcessedStats();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Processed files cleared'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _clearPasswordHints() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('pwd_hint_')).toList();
    for (final k in keys) await prefs.remove(k);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password hints cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Appearance
          _sectionHeader(theme, 'Appearance', Icons.palette_outlined),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Column(children: [
                  _themeTile(theme, ThemeMode.system, 'System Default', Icons.brightness_auto),
                  const Divider(height: 1, indent: 56),
                  _themeTile(theme, ThemeMode.light, 'Light', Icons.light_mode_outlined),
                  const Divider(height: 1, indent: 56),
                  _themeTile(theme, ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
                ]),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Storage
          _sectionHeader(theme, 'Storage', Icons.folder_outlined),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('Processed Files Folder'),
                    subtitle: Text(Constants.processedDirPath, style: theme.textTheme.bodySmall),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: const Text('Processed Files'),
                    subtitle: Text('$_processedFileCount files · $_processedDirSize · tap to view'),
                    onTap: () => GoRouter.of(context).pushNamed(AppRoutes.resultsRoute.name),
                    trailing: TextButton(
                      onPressed: _processedFileCount == 0 ? null : _clearCache,
                      child: const Text('Clear', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('Password Hints'),
                    subtitle: const Text('Saved hints for protected PDFs'),
                    trailing: TextButton(
                      onPressed: _clearPasswordHints,
                      child: const Text('Clear'),
                    ),
                  ),
                ]),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Privacy & Data — be transparent that tools process on the server.
          _sectionHeader(theme, 'Privacy & Data', Icons.shield_outlined),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tools run on our secure server so results are identical on every '
                          'device. Files are sent over an encrypted (HTTPS) connection, processed, '
                          'and removed afterwards — we don\'t keep your documents.',
                          style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.45,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // About
          _sectionHeader(theme, 'About', Icons.info_outlined),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Column(children: [
                  const ListTile(
                    leading: Icon(Icons.apps),
                    title: Text('PDF Craft'),
                    subtitle: Text('PDF & Image toolkit'),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.slideshow_outlined),
                    title: const Text('App Intro'),
                    subtitle: const Text('Replay the welcome walkthrough'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => GoRouter.of(context)
                        .pushNamed(AppRoutes.onboardingRoute.name),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.code_outlined),
                    title: const Text('Version'),
                    trailing: Text('2.0.0', style: theme.textTheme.bodyMedium),
                  ),
                ]),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title, IconData icon) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
        child: Row(children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary, letterSpacing: 0.8)),
        ]),
      ),
    );
  }

  Widget _themeTile(ThemeData theme, ThemeMode mode, String label, IconData icon) {
    final selected = _themeMode == mode;
    return ListTile(
      leading: Icon(icon, color: selected ? theme.colorScheme.primary : null),
      title: Text(label),
      trailing: selected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
      onTap: () => _setTheme(mode),
    );
  }
}
