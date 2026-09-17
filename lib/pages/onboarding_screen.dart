import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf_craft/theme/app_radius.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Built on every build (not a const list) so the copy follows the current language.
  static List<_OnboardingPage> _pages(AppLocalizations l) => [
        _OnboardingPage(
          lottieAsset: null,
          icon: Icons.picture_as_pdf_outlined,
          title: l.onbTitle1,
          description: l.onbBody1,
        ),
        _OnboardingPage(
          lottieAsset: null,
          icon: Icons.document_scanner_outlined,
          title: l.onbTitle2,
          description: l.onbBody2,
        ),
        _OnboardingPage(
          lottieAsset: null,
          icon: Icons.folder_open_outlined,
          title: l.onbTitle3,
          description: l.onbBody3,
        ),
      ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) GoRouter.of(context).goNamed(AppRoutes.filesRoute.name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final l = L10n.of(context);
    final pages = _pages(l);
    final isLast = _currentPage == pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(l.onbSkip, style: TextStyle(color: primary.withValues(alpha: 0.7))),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final page = pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(page.icon, size: 60, color: primary),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(pages.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? primary
                              : primary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(AppRadius.surface),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isLast
                          ? _finish
                          : () => _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              ),
                      child: Text(isLast ? l.onbGetStarted : l.onbNext),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _OnboardingPage {
  final String? lottieAsset;
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingPage({
    this.lottieAsset,
    required this.icon,
    required this.title,
    required this.description,
  });
}
