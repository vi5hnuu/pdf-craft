import 'package:flutter/material.dart';

/// The app's wordmark, in a version that can actually be read on the current theme.
///
/// The artwork spells "I ♥ PDF" with the letters in white, which is invisible against a light
/// app bar — on a light theme the birds floated on their own with no wordmark at all. The light
/// variant carries the same artwork with the lettering in slate; the birds and hearts are
/// identical in both, so switching between them does not change the brand.
class AppLogo extends StatelessWidget {
  final double width;
  final BoxFit fit;

  const AppLogo({super.key, this.width = 112, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    final onLightSurface = Theme.of(context).brightness == Brightness.light;
    return Image.asset(
      onLightSurface ? 'assets/logo_light.webp' : 'assets/logo.webp',
      width: width,
      fit: fit,
      // Named for a screen reader, which otherwise announces nothing for the app's own mark.
      semanticLabel: 'PDF Craft',
    );
  }
}
