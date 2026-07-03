# Production setup — auth, credits, Google Sign-In, Play Billing

This covers the **configuration** needed to run the auth + credit monetization stack
in production. All of it is external setup (keys, store products, credentials) — no
code changes required.

Three services:
- **auth** (`/Users/vishnu/IdeaProjects/auth`) — issues JWTs, port 8081
- **pdf-studio-api** (`/Users/vishnu/IdeaProjects/pdf-studio-api`) — validates JWTs, holds credits, port 8082
- **pdf-craft** (this repo) — the Flutter app

---

## 1. Auth service RSA signing keys (required)

Access tokens are RS256-signed. Dev auto-generates an ephemeral keypair; **prod must
provide a stable keypair** (otherwise `StartupSecretsValidator` aborts boot).

Generate a 2048-bit RSA keypair in PKCS#8 (private) + X.509 (public) PEM:

```bash
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out auth_private.pem
openssl rsa -in auth_private.pem -pubout -out auth_public.pem
```

Set on the **auth** service (prod profile):

| Env var | Value |
|---|---|
| `AUTH_JWT_PRIVATE_KEY_LOCATION` | `file:/secrets/auth_private.pem` |
| `AUTH_JWT_PUBLIC_KEY_LOCATION` | `file:/secrets/auth_public.pem` |
| `AUTH_JWT_KID` | e.g. `auth-key-1` (any stable id) |
| `AUTH_JWT_ISSUER` | `https://auth.laxmi.solutions` (must match pdf-studio's `AUTH_ISSUER`) |

Rotation: add a second keypair with a new `kid`; the JWKS can publish both so old
tokens keep verifying during the overlap.

## 2. pdf-studio-api → auth wiring (required)

pdf-studio verifies tokens against the auth JWKS. Set on **pdf-studio-api**:

| Env var | Value |
|---|---|
| `AUTH_JWKS_URI` | `https://auth.laxmi.solutions/.well-known/jwks.json` |
| `AUTH_ISSUER` | `https://auth.laxmi.solutions` (must equal `AUTH_JWT_ISSUER`) |

The Flutter app's base URLs are in `lib/utils/Constants.dart` (`baseUrl`, `authBaseUrl`) —
already switched by build mode; update the prod hosts there if they differ.

## 3. Google Sign-In (required for the "Continue with Google" button)

The app must receive an **ID token**, which requires a **Web** OAuth client id as the
`serverClientId`.

1. Google Cloud Console → **APIs & Services → Credentials**.
2. Create an **OAuth client ID → Web application**. Copy its client id.
3. Create an **OAuth client ID → Android** (package name + SHA-1 of your signing key)
   and an **iOS** client if shipping iOS.
4. **App (Android):** put `google-services.json` in `android/app/`; pass the *Web*
   client id as `serverClientId` to `GoogleSignIn`, or set it in
   `android/app/src/main/res/values/strings.xml` as `default_web_client_id`.
   (In `lib/singletons/AuthService.dart`, `GoogleSignIn(scopes: ['email'])` returns an
   `idToken` only when the server client id is configured.)
5. **Auth service:** set `AUTH_GOOGLE_CLIENT_IDS` to a comma-separated list of the
   **client ids** you accept as token audiences (the Web + Android + iOS ids). Empty =
   Google login disabled.

## 4. Google Play Billing — credit packs (required for buying credits)

### 4a. In-app products
Play Console → your app → **Monetize → In-app products**. Create three **consumable**
products with ids matching the code (`CreditsScreen` / `CreditsService`):

| Product id | Credits granted (server: `CreditsService.PRODUCT_CREDITS`) |
|---|---|
| `pdfcraft_credits_10` | 10 |
| `pdfcraft_credits_30` | 30 |
| `pdfcraft_credits_60` | 60 |

### 4b. Server-side verification (service account)
pdf-studio verifies purchase tokens with the Play Developer API.

1. Play Console → **Setup → API access** → link a Google Cloud project.
2. Create a **service account**, grant it **View financial data / Manage orders** (at
   least order + subscription visibility), download its **JSON key**.
3. Set on **pdf-studio-api**:

| Env var | Value |
|---|---|
| `PLAY_SERVICE_ACCOUNT_KEY_PATH` | `file` path to the service-account JSON |
| `PLAY_PACKAGE_NAME` | the app's package (e.g. `solutions.laxmi.pdfcraft`) |

Without the key, `/credits/purchase` safely returns "could not verify" (no crash).

### 4c. Refund / void clawback (RTDN — optional but recommended)
To claw back credits when a purchase is refunded/voided:

1. Play Console → **Monetization setup → Real-time developer notifications**.
2. Create a Pub/Sub topic + **push** subscription pointing at:
   `https://pdf-studio-api.laxmi.solutions/api/v1/credits/play-rtdn?secret=<PLAY_RTDN_SECRET>`
3. Authenticate the push. The webhook accepts two mechanisms and **every configured one
   must pass** (if none is configured it rejects, fail-closed):
   - **OIDC token (recommended, strongest):** in the Pub/Sub subscription, enable
     *Authentication*, choose a service account, and set the **audience** to the webhook
     URL. Then set `PLAY_RTDN_AUDIENCE` (that audience) and optionally
     `PLAY_RTDN_SERVICE_ACCOUNT` (the service-account email) on pdf-studio. Pub/Sub then
     signs each push with a Google OIDC token that the service verifies.
   - **Shared secret:** set `PLAY_RTDN_SECRET` on pdf-studio to match the `?secret=` in
     the push URL.

   A voided one-time purchase then triggers `CreditsService.revokeCreditsForToken`
   (idempotent, exact-amount clawback).

## 5. Email (SMTP) — verification & password reset (required for email/password auth)

Set on the **auth** service (prod):

| Env var | Value |
|---|---|
| `MAIL_HOST` / `MAIL_PORT` | your SMTP host / port (587) |
| `MAIL_USERNAME` / `MAIL_PASSWORD` | SMTP creds |
| `AUTH_MAIL_FROM` | from-address, e.g. `no-reply@laxmi.solutions` |
| `AUTH_VERIFY_BASE_URL` | `https://auth.laxmi.solutions/api/v1/auth/verify` |
| `AUTH_RESET_BASE_URL` | `https://auth.laxmi.solutions/api/v1/auth/reset-password` |

The verify/reset links open friendly HTML pages served by the auth service
(`AuthWebController` + `templates/verify-result.html` / `reset-form.html`).

## 6. Databases

Both backends use MySQL (`ddl-auto=update`; authoritative schema in each repo's
`src/main/resources/sql-init/init.sql`). Provide `DB_URL` / `DB_USERNAME` /
`DB_PASSWORD` (auth uses `auth_db`, pdf-studio uses `pdfstudio_db`).

## 7. Credit economy knobs (optional tuning — pdf-studio env)

| Env / property | Default |
|---|---|
| `app.credits.welcome-grant` | 10 |
| `app.credits.daily-allowance` | 3 |
| `app.credits.rewarded-ad-grant` | 2 |
| `app.credits.rewarded-ad-daily-cap` | 10 |

Per-tool prices live in the `tool_credit_costs` table (seeded by
`ToolCreditCostSeeder`, editable at runtime — 0 = free).

---

### Quick "is it wired?" checklist
- [ ] Auth boots in prod (RSA keys set) and serves `/.well-known/jwks.json`
- [ ] pdf-studio boots with `AUTH_JWKS_URI` + `AUTH_ISSUER`; a real token authenticates
- [ ] Google button returns an idToken (serverClientId set) and logs in
- [ ] Three consumable products live in Play; `PLAY_*` set; a test purchase credits once
- [ ] RTDN subscription + secret set; a test refund claws back
- [ ] SMTP set; register → email arrives → verify page shows success
