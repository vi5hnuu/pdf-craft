# PDF Craft — Task Tracker

> **DO NOT COMMIT this file.**
> Local URL: `http://localhost:8082/api/v1` | Prod URL: `https://pdf-studio-api.laxmi.solutions/api/v1`

### Image Studio (4 stub endpoints — verify backend impl before integrating)
| Tool | Endpoint |
|------|----------|
| Compress Image | `/image-studio/compress-image` |
| Convert to JPG | `/image-studio/convert-to-jpg` |
| Convert from JPG | `/image-studio/convert-from-jpg` |
| Resize Image | `/image-studio/resize-image` |


### 🟢 LOW Priority
- [ ] **Image studio integration** — First verify backend endpoints are actually functional (currently stubs with `Object a` params). Once confirmed, add compress/resize image tools.

## Notes

- `Standard14Fonts.FontName` enum values needed for header/footer: HELVETICA, HELVETICA_BOLD, HELVETICA_OBLIQUE, TIMES_ROMAN, TIMES_BOLD, COURIER, etc. — map these to a user-friendly dropdown.
- `ColorModel` in backend expects `{r, g, b, a}` JSON — already handled by existing watermark implementation; reuse the same pattern for header/footer.
- `Postion` enum (note: typo in backend — "Postion" not "Position") values: START, CENTER, END.
- Backend uses `@JsonNaming(SnakeCaseStrategy)` so all JSON fields must be snake_case.


///

High value (core utility):
- [ ] 1. PDF Form Fields Editor (your suggestion) — overlay draggable/resizable form fields (text input, checkbox, radio, signature, date) onto any PDF page, then flatten them in.
   Needs a canvas-based page editor with field placement UI. This is genuinely complex but very high value — most PDF apps charge for this.
- [ ] 2. PDF Page Crop / Margin Trim — visually drag crop handles on a page thumbnail to remove white margins or crop to a region. Currently you have Crop PDF but it's likely
   parameter-based, not visual.
- [ ] 3. Annotate PDF — draw highlights, arrows, text boxes, or freehand on pages. Similar canvas to form fields.

Medium value:
- [ ] 4. PDF to Word/Excel/PPT export — backend stubs already exist, just need the backend actually implemented.
- [x] 5. QR Code / Barcode stamp — DONE. `qr_flutter` package added; QrStampPdfView generates QR from any URL/text, captures as PNG, sends to /stamp-pdf API. Route: `qr-stamp-pdf-tool`.
- [x] 6. Split by bookmark/outline — DONE. Added `SPLIT_BY_BOOKMARK` to both Flutter enum and backend Java enum + PDFBox outline extraction in PdfTools.splitPdf. SplitConfig has new ListTile for it.
- [x] 7. File selection UX — DONE. router.push → router.replace in FilesManagement so tools route replaces picker in back stack.
- [x] 8. Recent files — DONE. RecentFilesService scans processedDir/downloads/documents; purely filesystem-based, no SharedPreferences.
- [x] 9. Scanner redesign — DONE. ScannerScreen rebuilt with two ScanCard tiles (scan to PDF / scan to JPEG), result view with header/filename/preview/action bar.
- [x] 10. App hangs — DONE. Removed all sync IO from build methods: async file meta in FileTile, pre-cached sort stats (O(N) instead of O(N log N)) in DirectoryFilesListing, pre-cached sizes in BatchProcessView. Also removed N+1 sort calls per ListView build.
- [ ] 11. Cloud storage integration — Research complete (see below):
  **Google Drive**: `google_sign_in` + `googleapis` packages; OAuth 2.0 with `https://www.googleapis.com/auth/drive.file` scope; use `DriveApi` for upload/download.
  **Dropbox**: No official Dart SDK — use `flutter_web_auth_2` for OAuth + Dio for Dropbox REST API v2 (`/files/upload`, `/files/download`).
  **OneDrive / SharePoint**: `msal_auth` package for Microsoft Identity; Microsoft Graph API (`/me/drive/root:/path:/content`) for files; SharePoint needs extra `Sites.ReadWrite.All` scope.
  **All providers need**: `flutter_secure_storage` for token persistence, `flutter_web_auth_2` for OAuth redirect handling, `dio` (already present) for API calls. Suggest implementing one provider first (Google Drive has best Dart support) behind a common `CloudStorageProvider` interface.

CONCLUSION : implement for only google drive , and remove placeholders for rest