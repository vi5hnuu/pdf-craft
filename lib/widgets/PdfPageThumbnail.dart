import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfPageThumbnail extends StatelessWidget {
  final PdfControllerPinch controller;
  final int pageNumber;
  final double width;
  final double height;

  const PdfPageThumbnail({
    super.key,
    required this.controller,
    required this.pageNumber,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PdfPageImage?>(
      future: _loadPageImage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: Icon(Icons.error, color: Colors.red)),
          );
        }

        return SizedBox(
          width: width,
          height: height,
          child: Image.memory(
            snapshot.data!.bytes,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }

  Future<PdfPageImage?> _loadPageImage() async {
    try {
      final document = await controller.document;
      final PdfPage page = await document.getPage(pageNumber);

      // Render full quality image using the page's intrinsic width/height ratio
      final double aspectRatio = page.width / page.height;
      final double renderWidth = (width * 3);  // High-res rendering
      final double renderHeight = (renderWidth / aspectRatio);

      final image = await page.render(
        width: renderWidth,
        height: renderHeight,
      );
      await page.close(); // Close the page to release resources
      return image;
    } catch (e) {
      throw Exception("Failed to load pdf page");
    }
  }
}
