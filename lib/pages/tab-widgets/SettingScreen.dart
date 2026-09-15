import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AuthService.dart';
import 'package:pdf_craft/theme/theme_manager.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pdf_craft/l10n/L10n.dart';
import 'package:pdf_craft/l10n/LocaleManager.dart';
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
  // Read from the installed package (pubspec version) — it was hard-coded as 2.0.0 and went
  // stale with every release.
  String _version = '';

  @override
  void initState() {
    super.initState();
    _themeMode = ThemeManager().mode;
    _loadProcessedStats();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
  }

  Future<void> _loadProcessedStats() async {
    // Async listing and sizes: opening Settings used to walk the output folder synchronously on
    // the UI thread, which janked the screen transition when the folder was large.
    final dir = Directory(Constants.processedDirPath);
    if (!await dir.exists()) return;
    final files = await dir.list().where((e) => e is File).cast<File>().toList();
    int totalBytes = 0;
    for (final f in files) {
      try { totalBytes += await f.length(); } catch (_) {}
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
    if (!mounted) return;
    setState(() => _themeMode = mode);
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(ctx).settingsClearProcessedTitle),
        content: Text(L10n.of(ctx).settingsClearProcessedBody(_processedFileCount)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L10n.of(ctx).cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.of(ctx).delete, style: const TextStyle(color: Colors.red)),
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
        SnackBar(content: Text(L10n.of(context).settingsProcessedCleared), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _clearPasswordHints() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('pwd_hint_')).toList();
    for (final k in keys) await prefs.remove(k);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).settingsPasswordHintsCleared)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).actionSettings)),
      body: SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Account
          _sectionHeader(theme, L10n.of(context).settingsSectionAccount, Icons.person_outline),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: AnimatedBuilder(
                  animation: AuthService(),
                  builder: (context, _) {
                    final user = AuthService().user;
                    final signedIn = AuthService().isSignedInFull;
                    final unverified = signedIn && !(user?.enabled ?? true);
                    return ListTile(
                      leading: Icon(
                        unverified
                            ? Icons.mark_email_unread_outlined
                            : signedIn
                                ? Icons.verified_user_outlined
                                : Icons.person_outline,
                        color: unverified ? theme.colorScheme.error : null,
                      ),
                      title: Text(signedIn
                          ? (user?.email ?? user?.username ?? L10n.of(context).settingsSectionAccount)
                          : L10n.of(context).guest),
                      subtitle: Text(
                        unverified
                            ? L10n.of(context).settingsEmailNotVerified
                            : signedIn
                                ? L10n.of(context).settingsManageAccount
                                : L10n.of(context).settingsSignInPrompt,
                        style: unverified
                            ? TextStyle(color: theme.colorScheme.error)
                            : null,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => GoRouter.of(context)
                          .pushNamed(AppRoutes.accountRoute.name),
                    );
                  },
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Appearance
          _sectionHeader(theme, L10n.of(context).settingsSectionAppearance, Icons.palette_outlined),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Column(children: [
                  _themeTile(theme, ThemeMode.system, L10n.of(context).themeSystem, Icons.brightness_auto),
                  const Divider(height: 1, indent: 56),
                  _themeTile(theme, ThemeMode.light, L10n.of(context).themeLight, Icons.light_mode_outlined),
                  const Divider(height: 1, indent: 56),
                  _themeTile(theme, ThemeMode.dark, L10n.of(context).themeDark, Icons.dark_mode_outlined),
                ]),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Language — System follows the device; English / हिन्दी override it.
          _sectionHeader(theme, L10n.of(context).settingsLanguage, Icons.translate),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: ListenableBuilder(
                  listenable: LocaleManager(),
                  builder: (context, _) {
                    final l = L10n.of(context);
                    return Column(children: [
                      _languageTile(theme, AppLanguage.system, l.languageSystem, Icons.phone_android_outlined),
                      const Divider(height: 1, indent: 56),
                      _languageTile(theme, AppLanguage.english, l.languageEnglish, Icons.abc),
                      const Divider(height: 1, indent: 56),
                      _languageTile(theme, AppLanguage.hindi, l.languageHindi, Icons.translate),
                    ]);
                  },
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Storage
          _sectionHeader(theme, L10n.of(context).settingsSectionStorage, Icons.folder_outlined),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(L10n.of(context).settingsProcessedFolder),
                    subtitle: Text(Constants.processedDirPath, style: theme.textTheme.bodySmall),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: Text(L10n.of(context).storageProcessed),
                    subtitle: Text(L10n.of(context).settingsProcessedSummary(_processedFileCount, _processedDirSize)),
                    onTap: () => GoRouter.of(context).pushNamed(AppRoutes.resultsRoute.name),
                    trailing: TextButton(
                      onPressed: _processedFileCount == 0 ? null : _clearCache,
                      child: Text(L10n.of(context).clear, style: const TextStyle(color: Colors.red)),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: Text(L10n.of(context).settingsPasswordHints),
                    subtitle: Text(L10n.of(context).settingsPasswordHintsSub),
                    trailing: TextButton(
                      onPressed: _clearPasswordHints,
                      child: Text(L10n.of(context).clear),
                    ),
                  ),
                ]),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Privacy & Data — be transparent that tools process on the server.
          _sectionHeader(theme, L10n.of(context).settingsSectionPrivacy, Icons.shield_outlined),
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
                          L10n.of(context).settingsPrivacyBody,
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
          _sectionHeader(theme, L10n.of(context).settingsSectionAbout, Icons.info_outlined),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.apps),
                    title: Text(L10n.of(context).appName),
                    subtitle: Text(L10n.of(context).settingsAboutSubtitle),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.slideshow_outlined),
                    title: Text(L10n.of(context).settingsAppIntro),
                    subtitle: Text(L10n.of(context).settingsAppIntroSub),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => GoRouter.of(context)
                        .pushNamed(AppRoutes.onboardingRoute.name),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.code_outlined),
                    title: Text(L10n.of(context).settingsVersion),
                    trailing: Text(_version, style: theme.textTheme.bodyMedium),
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

  Widget _languageTile(ThemeData theme, AppLanguage language, String label, IconData icon) {
    final selected = LocaleManager().language == language;
    return ListTile(
      leading: Icon(icon, color: selected ? theme.colorScheme.primary : null),
      title: Text(label),
      trailing: selected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
      onTap: () => LocaleManager().setLanguage(language),
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
