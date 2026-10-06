/// Validating the page range a user typed, before anything is spent on it.
///
/// This exists because of a failure proven on device: Header/Footer on a three-page document
/// with "From page 99, To page 2" was accepted as typed, the request returned 200, a credit was
/// charged, and the file that came back was the original with nothing applied. The user paid for
/// a copy of what they already had, and nothing told them. Whatever the server does with a range
/// it cannot satisfy, the app should not spend a credit to find out.
library;

import 'package:pdf_craft/l10n/l10n.dart';

/// A validated range, in the 0-based indices the API expects.
class PageRange {
  const PageRange({required this.fromIndex, required this.toIndex});

  /// First page, 0-based.
  final int fromIndex;

  /// Last page, 0-based and inclusive, or null for "to the end of the document".
  final int? toIndex;
}

/// Why [from]/[to] cannot be used, or null when they can.
///
/// [pageCount] of 0 means the document's length is not known — the count-based checks are then
/// skipped rather than guessed at, and only the ordering rule applies.
///
/// Both fields are 1-based, as the user typed them. An empty [from] means the first page and an
/// empty [to] means the last, which is what the blank "To page (optional)" field has always
/// implied.
PageRangeError? validatePageRange({
  required String from,
  required String to,
  required int pageCount,
}) {
  final f = from.trim();
  final t = to.trim();

  final fromNum = f.isEmpty ? 1 : int.tryParse(f);
  if (fromNum == null) return PageRangeError.notANumber;
  if (fromNum < 1) return PageRangeError.notANumber;

  int? toNum;
  if (t.isNotEmpty) {
    toNum = int.tryParse(t);
    if (toNum == null) return PageRangeError.notANumber;
    if (toNum < 1) return PageRangeError.notANumber;
  }

  if (pageCount > 0 && fromNum > pageCount) return PageRangeError.beyondDocument;
  // A `to` past the end is not an error — "to 99" on a three-page document plainly means "to the
  // end", and [resolvePageRange] clamps it. A `to` *before* `from` has no such reading.
  if (toNum != null && toNum < fromNum) return PageRangeError.backwards;

  return null;
}

/// The range as indices, assuming [validatePageRange] already passed.
PageRange resolvePageRange({
  required String from,
  required String to,
  required int pageCount,
}) {
  final f = from.trim();
  final t = to.trim();
  final fromNum = f.isEmpty ? 1 : (int.tryParse(f) ?? 1);
  var toNum = t.isEmpty ? null : int.tryParse(t);
  if (toNum != null && pageCount > 0 && toNum > pageCount) toNum = pageCount;
  return PageRange(fromIndex: fromNum - 1, toIndex: toNum == null ? null : toNum - 1);
}

/// What is wrong with a range, so the caller can show the right sentence.
enum PageRangeError { notANumber, beyondDocument, backwards }

/// The sentence to show the user for [error], or null when there is nothing wrong.
///
/// Lives here so the two screens that take a range cannot drift apart on the wording.
String? pageRangeMessage(PageRangeError? error, int pageCount) => switch (error) {
      null => null,
      PageRangeError.notANumber => L10n.current.errPageNotANumber,
      PageRangeError.beyondDocument => L10n.current.errPageBeyondDocument(pageCount),
      PageRangeError.backwards => L10n.current.errPageRangeBackwards,
    };
