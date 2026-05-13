import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfPageThumbnail extends StatelessWidget {
  final PdfDocument document;
  final int pageNumber;
  final double width;
  final double height;

  const PdfPageThumbnail({
    super.key,
    required this.document,
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
      final PdfPage page = await document.getPage(pageNumber);
      final PdfPageImage? image = await page.render(
        width: page.width,
        height: page.height,
        format: PdfPageImageFormat.jpeg,  // Adjust the format if needed
      );
      await page.close();
      return image;
    } catch (e) {
      throw Exception("Failed to load pdf page");
    }
  }
}
