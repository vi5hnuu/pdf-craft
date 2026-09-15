# PDF Craft — UI / UX / Flow Audit (2026-09-15)

Branch: `audit/ui-ux-improvements` · App version `3.0.0+11`

## How this was audited

- **Code review** of every tab, the shared tool infrastructure (`ToolRegistry`, `CreditGate`,
  `ToolViewMixin`, `ProcessingOverlay`, `PdfBloc`), file browsing, auth, credits, ads and settings.
- **Hands-on testing on a real device** — Samsung Galaxy A35 (SM-A356E), Android 16,
  1080×2340, dark mode, system font scale 0.8 — with screenshots of every screen analysed.
  Also re-checked in **light theme** and at **font scale 1.3** (restored to 0.8 afterwards).
- Tools were run end-to-end against the **real production backend** (see caveats).

### Test caveats (read before acting)

- Production is currently **unreachable from the internet** (port 443 refused on 49.205.216.160);
  testing used a debug build installed side-by-side (`com.vi5hnu.pdf_craft.debug`) talking to the
  homelab Caddy through a local test proxy. Performance was therefore not judged (debug build).
- Google Sign-In / Drive could not be completed in the side-by-side debug build (OAuth client is
  tied to the release package + key) — their flows were reviewed from code only.
- Temporary, **uncommitted** test-only changes exist and must never be committed:
  `android/app/build.gradle` (`applicationIdSuffix ".debug"`, marked `AUDIT-TEMP`) and
  `android/app/src/debug/google-services.json`.

### Severity

- **P0** — broken, misleading, or a policy / trust risk. Fix first.
- **P1** — significant UX friction or inconsistency.
- **P2** — polish.

Things that looked wrong but were **verified not to be bugs** are listed at the end.

---

## Top priorities (P0)

| # | Finding | Evidence |
|---|---------|----------|
| 1 | **Production is unreachable.** Both prod hosts resolve to the home IP, but TCP 443 is refused from outside; the homelab box itself (192.168.1.2) serves correctly. Router port-forward / ISP issue. The `/api/v1` auth-URL fix (`de156f7`, on `main`) also still needs a release build. | curl/WebFetch from outside → `ECONNREFUSED`; LAN via Caddy → 200 |
| 2 | **"Searchable PDF (OCR)" is not OCR.** The card promises a selectable text layer but calls exactly the same scan as "Scan to PDF". | `lib/pages/tab-widgets/ScannerScreen.dart:131` vs `:107` |
| 3 | **Interstitial ad after every successful tool run**, no frequency cap — including runs the user just **paid credits** for. It also hides the success snackbar and its "Next tool" action, and shows a black frame before rendering. | `lib/singletons/AdsSingleton.dart:75`; observed after Compress |
| 4 | **App-open ad fires on return from any system UI** (lifecycle `inactive` counts as backgrounded): notification shade, permission dialogs, Google account picker, document scanner, share sheet, external viewer. No cooldown and **no Pro check** (Pro users still get it). High AdMob-policy risk. | `lib/main.dart:209-215`, `lib/singletons/AppOpenAdManager.dart:66`; observed after the account picker |
| 5 | **Opening the Cloud tab immediately launches the Google account picker** — silent restore falls through to interactive sign-in on tab open. | `lib/pages/DriveScreen.dart:49` → `lib/services/cloud/GoogleDriveService.dart:32`; observed |
| 6 | **Password fields in Protect / Unprotect PDF are not obscured** (shoulder-surfing; screen recordings). | `lib/pages/ProtectPdfView.dart:105,112`; `UnProtectPdfView.dart` (0 `obscureText`) |
| 7 | **No client-side upload size check.** Server limit is 50 MB/file, 100 MB/request; the app happily uploaded a 237 MB PDF, the connection was cut mid-upload and the user saw only "Failed to compress PDF" — the server's friendly 413 message ("That file is larger than the upload limit") never reached them. The credit dialog had quoted "from 2 credits". | `pdf-studio-api application.properties:3-4`; observed |
| 8 | **Scanner spends credits without confirmation.** "Scan to JPEG → Merge to PDF" dispatches `ImageToPdfEvent` directly, bypassing `CreditGate`, although `image-to-pdf` is a priced tool. | `ScannerScreen._saveResult` |
| 9 | **Rate-app prompt is double counted / can opt users out forever.** Both `MainScreen` and `ToolResultHandler` call `recordSuccess()` on the same success (counter +2, two different dialogs), and MainScreen's "Later" still calls `markRated()` (the fix was only applied to the mixin). | `lib/pages/MainScreen.dart:38,126`, `lib/utils/ToolResultHandler.dart:31` |
| 10 | **Play-policy risks:** `MANAGE_EXTERNAL_STORAGE` for a PDF tool (API 33+) is routinely rejected; Drive uses `drive.readonly`, a **restricted** OAuth scope that requires Google verification. | `AndroidManifest.xml:7`; `GoogleDriveService.dart:20-23` |
| 11 | **Wrong version in Settings** — shows `2.0.0`, app is `3.0.0+11`. | `lib/pages/tab-widgets/SettingScreen.dart:271` |
| 12 | **First launch shows the permission wall before onboarding.** The global router `redirect` (async permission check on *every* navigation, splash and onboarding included) sends new users to the error/permission page before they see the intro. | `lib/main.dart:227` |

---

## Phase 1 — Launch, brand, onboarding, permissions

**P1**
- **Brand identity is split in four:** logo artwork reads "I ♥ PDF" (birds), screens say
  "PDF Craft", launcher label is lowercase `pdf craft` (`AndroidManifest.xml:10`), task title
  `'Pdf craft'` (`main.dart:990`), output folder is `ilvPdf`. Pick one name and apply everywhere
  (also avoids confusion with iLovePDF).
- **Ad keywords are copy-pasted from another app** — `'gfg','geeksforgeeks','leetcode','codechef'…`
  plus competitor `'ilovepdf'` (`lib/widgets/BannerAdd.dart:35`). Hurts ad relevance/revenue.
- **Onboarding is generic:** three identical icon-in-circle pages; does not explain the
  credits model, that tools run on a server, privacy, or ask for storage access in context.
  "Skip" is small, low-contrast, top-right.
- **Theme defaults to Dark and ignores the system setting** (`lib/theme/theme_manager.dart:10`).
  Default to `ThemeMode.system`.

**P2**
- Splash has a fixed 3 s fallback gated on AdMob init; show content as soon as auth/prefs are ready.
- `debugLogDiagnostics: true` on the router ships in release.

## Phase 2 — Navigation & home (Files tab, Tools tab)

**P1**
- **No primary action on the landing tab.** Files shows recents + four storage folders; there is
  no "Open PDF / Scan / Merge" call to action. A `HomeScreen` with quick actions exists but is dead
  code (only a commented reference, `main.dart:895`).
- **Double headers:** a global app bar (logo, theme, search, settings) sits above per-tab titles
  ("All Tools", "Google Drive"), costing ~120 px on every tab.
- **Theme switcher in the top app bar** duplicates Settings and takes prime space.
- **Search icon has no tooltip/semantics label** (the only unlabeled app-bar action).
- **Tools tab: 61 tools in one uniform grid** (~7 screens of scrolling), no category jump chips,
  no "Popular" row for new users; "Batch" is a whole section for one tool.
- **Duplicate tool icons** make scanning hard: Reorder = Reverse (`swap_vert`), Mirror = Flip,
  Compress PDF = Compress Image, Rotate PDF = Rotate Image, Optimize = Image Filters
  (`auto_fix_high`).
- **Info "ⓘ" icon on every card** (61×) adds noise; long-press is used for favourites but is not
  discoverable.
- **Credit cost badge** is 10 px and low contrast; the `toll` glyph reads as "(O", not "credits";
  free tools show nothing, so "free" and "price not loaded yet" look identical.
- **Tools search keeps query + focus:** returning to the tab re-opens the keyboard, and the first
  Back press only closes the keyboard. Search matches names only (no synonyms: "join", "shrink",
  "lock", "sign").

**P2**
- Heading scale is inconsistent on Files ("Recent Files" 18 px vs "My Storage" 24 px) with a large
  gap between sections.
- Storage tiles show unlabeled counts (e.g. "349" = items in the folder, not PDFs) and no chevron.
- Some recent-file thumbnails fail and fall back to a placeholder; very large PDFs are rendered for
  thumbnails on the main screen.
- Category heading contrast: Batch brown `#6D4C41` on `#0D0D0D` is nearly invisible; red PDF icons
  on dark-red tint are low contrast.
- `"All Tools ( 61 )"` — spaces inside the parentheses.

## Phase 3 — Choosing files (picker & file browser)

**P1**
- **Picker is titled "File Management"** (`lib/widgets/FilesManagement.dart:29`) — should say what
  to pick ("Select a PDF", "Select 2 or more PDFs"). No selection count / minimum hint; the
  "Complete Selection" button does not show a count and stays disabled without saying why.
- **Starts at storage root** with breadcrumb "0"; shows hidden dot-folders and `Android/`; no
  shortcuts to Recent PDFs / Downloads / Documents. Finding a PDF took folder digging + filtering.
- **Extension chips are built from every file in the folder** (`.apk`, `.jks`, `.aab`) even when the
  tool only accepts PDF; sort + type chips are crammed into one horizontal row and clip.
- **Stale row state bug:** `FileTile` has no `didUpdateWidget` and list items have no keys, so a
  recycled row keeps the previous file's size/date/favourite. Observed: PDFs in the picker showed
  no size/date after filtering, while the same files show sizes in Results.
  (`lib/widgets/FileTile.dart:32`)
- **Tapping a folder while a load is in flight** still pushes it onto the breadcrumb but skips the
  load → breadcrumb and list desync (`lib/widgets/DirectoryFilesListing.dart:594`).
- **Banner ad rides above the keyboard** and covers results while filtering (picker and Search) —
  bad UX and an accidental-click policy risk. Hide banners while the keyboard is open.
- **Copy / Move silently overwrite** an existing file at the destination; rename has no collision
  check.
- **Raw exceptions shown to users** (`FileSystemException: …`) — `files_bloc.dart:56,101,111`.

**P2**
- Selected row = red text + red tint (reads like an error); use a checkbox/check mark.
- Favourite star on every row in pick mode is irrelevant there.
- Sort choice resets every time the picker opens.
- Empty folder shows "No files found" and hides the breadcrumb/filter bar.

## Phase 4 — Running tools & results

**P1**
- **Three generations of tool screens:** 19 use `ToolViewMixin`, 31 use hand-rolled
  `LoadingOverlay` listeners, 6 have neither. Result: success behaviour differs per tool — legacy
  screens get no "Next tool" action or rate hook, Split has no Cancel, Split opens its result in an
  external app while others open the in-app preview.
- **Credit confirmation happens before a file is chosen** ("Use 2" before picking) — reads as an
  immediate spend and can't include the size surcharge. Show the price on the tool's action button
  once the file is known ("Compress · 2 credits").
- **Tool screens don't show the chosen file** (name, size, page count, thumbnail). Compress is an
  empty name field + three radios + a large blank area.
- **Output naming:** the name field is empty with an invisible default (`compressed_file`); outputs
  collide into "(1)", "(2)". Default to `<original>_compressed.pdf` and show it as the field value.
- **No outcome summary** — Compress went 264 KB → 205 KB (−22%) but nothing says so.
- **Errors:** generic ("Failed to compress PDF"), no Retry, and the snackbar covers the primary
  button. Map connection/timeout/413/402 to specific, actionable messages.
- **Result preview app bar is overcrowded** (page counter + 5 icons) → filename truncated to
  "compre…". Move Drive/Night/Bookmarks into the overflow menu.
- **Interstitial close ✕ sits exactly on the preview's ⋮** — a tap on ✕ also opened the menu.
- **Split PDF back trap:** first Back only resets the split type (`SplitPdfView.dart:63`).
- **Protect PDF:** both passwords silently require ≥10 chars (button just stays disabled);
  permission labels are raw enum names ("Modify_annotations", "Extract_for_accessibility"); emoji
  warning; underlined heading.
- **Merge:** no thumbnails/page counts/sizes, can't add or remove files after picking.

**P2**
- Typos: "Successfull" (`MergePdfView.dart:55`, `PdfToJpgView.dart:72`, `SplitRange.dart:78`,
  `SplitPdfView.dart:73`), "successfull" (`ImageToPdfView.dart:64`); titles "Split Pdf",
  "Protect Pdf".
- **Results hub:** a red delete icon on every row (no undo; the `ilvPdfBin` trash constant is
  unused), no grouping by date/tool, no thumbnails, no search; "Clear all" is icon-only.
- **Search screen has no back button** — the app logo occupies the leading slot
  (`lib/pages/SearchScreen.dart:127`).

## Phase 5 — Account, credits, scanner, cloud, settings

**P1**
- **Credits:** all three packs show "Available soon" with greyed prices — looks broken. Hide the
  section (or one "coming soon" line) until products exist. "Claim daily credits" shows no busy
  state, no next-claim countdown, and **maps every failure to "Already claimed today"**
  (`lib/pages/CreditsScreen.dart:183`) — network errors included. "Watch an ad" doesn't say how many
  credits it gives.
- **Cloud:** separate Google sign-in for Drive vs the app account (two "Google" concepts); no
  explanation of requested Drive access (see P0 #5, #10).
- **Settings is missing** Language, Rate app, Share app, Feedback/Contact, Privacy Policy & Terms
  links, Open-source licences, Restore purchases, default save folder.
- Processed-folder path shown without leading slash and as `ilvPdf`.

**P2**
- Scanner: page limit of 10 is hidden; tip repeats the subtitle; 2 + 1 card layout is uneven.
- Account (guest): sparse; no credit history; hero icon (award badge) is unrelated.
- Auth: "Name (optional)" as the first field adds friction; password rule only appears on error.
- Settings dividers are heavy (near-black in light theme) and start mid-row; the "PDF Craft /
  PDF & Image toolkit" About tile looks tappable but isn't.
- Credits balance card is a solid red block; refresh icon duplicates pull-to-refresh.

## Phase 6 — Theme, accessibility, errors & offline

**P1**
- **Font scale 1.3 breaks the tool grid:** fixed `childAspectRatio: 0.95`
  (`ToolsScreen.dart:179,313`) clips labels ("Reverse Pages", "Mirror Pages" cut off), words break
  mid-word ("Compr / ess PDF", "compressed_ / file.pdf"), cost badge overlaps the icon. Fixed heights
  elsewhere: recents rows 124 px, file cards 132 px, 10–11 px labels.
- **Fixed-size banners** (320×50 / 468×60) letterbox with black bars, very visible in light theme.
  Use anchored adaptive banners.
- **Offline:** the interceptor rejects requests with a clear message, but screens don't surface it
  consistently (Claim daily showed no feedback). Add a global offline banner and disable
  server-backed actions while offline.

**P2**
- `AppRadius.surface = 2` makes cards, buttons and dialogs nearly square — reads dated next to
  Material 3 components (consider 8–12). Subjective; decide once, apply globally.
- Credit chip semantics read only "10" — label it "10 credits, get more".

---

## Phase 7 — Feature opportunities

Ordered by expected impact for this app and market. Keep **app size** in mind (CLAUDE.md): prefer
Play-services-backed / unbundled models and server features over bundled binaries.

1. **Hindi language + in-app toggle** *(requested)* — `flutter_localizations` + ARB files (`en`,
   `hi`), a persisted `LocaleManager` (same pattern as `ThemeManager`), Settings → Language
   (System / English / हिन्दी). Poppins has no Devanagari — pair with Noto Sans Devanagari / Hind.
   Tool names/descriptions in `ToolRegistry` must be localized; backend messages stay English until
   the API honours `Accept-Language`. ~60 screens of strings → plan first.
2. **"Compress / resize to a target size"** (e.g. under 100 KB / 200 KB / 500 KB) for PDFs, photos
   and signatures — a top need for Indian government, exam and job-portal forms.
3. **ID card / Aadhaar print layout** — front + back on one A4, with correct physical size.
4. **Real OCR** for "Searchable PDF" and a "Copy text from image/scan" tool (ML Kit text
   recognition via Play services keeps APK size small).
5. **On-device processing for simple tools** (rotate, reorder, delete/extract pages, merge small
   files) — free, instant, works offline, better privacy; reserve credits for heavy server work.
6. **System file picker (SAF) + Recent PDFs in the picker** — faster picking and a path away from
   `MANAGE_EXTERNAL_STORAGE`.
7. **Compression result card** — before/after size, % saved, "try stronger" shortcut.
8. **Saved signatures & stamps** reusable across Sign / Stamp / Image Overlay.
9. **Workflows / presets** — chain tools (e.g. Scan → Compress → Protect) and re-run on new files.
10. **Launcher app shortcuts & share-sheet quick actions** — long-press icon: Scan, Merge, Compress.
11. **Reader upgrades** — text search in PDF, remember last page, horizontal/continuous modes.
12. **Trash with undo** for deletes in Results / file browser (the `ilvPdfBin` constant already exists).
13. **Monetization hygiene** — ad-free Pro subscription surfaced in Settings, ad frequency caps,
    no interstitials on paid runs, referral credits, daily-claim streaks.
14. **More conversions** — Word/Excel/PPT → PDF, HEIC/WebP → PDF, URL/HTML → PDF.
15. **More clouds** — share to WhatsApp as a first-class action; OneDrive/Dropbox later.

---

## Verified NOT bugs (checked and ruled out)

- **Credit balance going stale on legacy tool screens** — not a bug: the server sends
  `X-Credits-Remaining` on every charged response and `DioSingleton` feeds it to `CreditService`.
- **Settings → Account tile not opening** — was test-harness timing (UI dump racing the tap); the
  tile opens Account correctly.
- **Compress failure on the first attempt** — not the test proxy: the chosen file (237 MB) exceeds
  the server's 50 MB limit (backend returns 413 `FILE_TOO_LARGE`). The UX problem is recorded as P0 #7.

## Suggested fix order

1. Infra: restore public 443 (router/ISP), release a build with `de156f7`.
2. P0 trust & policy: ad frequency/placement (#3, #4), Cloud auto sign-in (#5), password masking
   (#6), size pre-check + specific errors (#7), scanner credit gate (#8), OCR claim (#2), rate prompt
   (#9), permission-before-onboarding (#12), version string (#11). Plan the storage/Drive scope
   change (#10) separately.
3. Consolidate all tool screens onto `ToolViewMixin` (fixes many P1 inconsistencies in one pass),
   then picker improvements and the `FileTile` stale-state bug.
4. Hindi localization (plan mode — large, touches every screen).
5. P2 polish and Phase 7 features.
