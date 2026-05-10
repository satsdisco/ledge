# Sparkle setup

Ledge ships with Sparkle 2 wired into the app. Until you complete the
one-time setup below, the updater is inert: "Check Now…" will surface a
clean error and the background scheduler does nothing. None of that
breaks the app — you just can't ship updates yet.

## Status today

| Done | What | Where |
|------|------|-------|
| ✓ | Sparkle dependency | `Package.swift` |
| ✓ | `UpdaterService` wraps `SPUStandardUpdaterController` | `Sources/Ledge/Services/Updater/UpdaterService.swift` |
| ✓ | Background scheduler started on app launch | `RootCoordinator.start()` |
| ✓ | "Check Now…" + auto-check toggle | Settings → General → Updates |
| ✓ | `Sparkle.framework` embedded + signed during bundling | `scripts/make-app.sh` |
| ✓ | `disable-library-validation` entitlement | `Resources/Ledge.entitlements` |
| ⏳ | EdDSA keypair generated | **you do this once** |
| ⏳ | `SUPublicEDKey` filled in `Info.plist` | **you do this once** |
| ⏳ | `SUFeedURL` points at a real `appcast.xml` | **you do this once** |
| ⏳ | Appcast hosting decided + first appcast published | **you do this once** |
| ⏳ | `scripts/release.sh` updated to sign + append to appcast | **you do this once** |

## Step 1 — Generate the EdDSA keypair

Sparkle ships `generate_keys` and `sign_update` inside its SPM artifact.
After a `swift build`, they're at:

```
.build/artifacts/sparkle/Sparkle/bin/generate_keys
.build/artifacts/sparkle/Sparkle/bin/sign_update
```

(Path may vary slightly with Sparkle version. `find .build -name generate_keys`
will locate it.)

Run it once:

```bash
.build/artifacts/sparkle/Sparkle/bin/generate_keys
```

It prints two things:

1. The **public key** (base64) — copy this into `Resources/Info.plist`
   under `<key>SUPublicEDKey</key>`, replacing `REPLACE_WITH_PUBLIC_EDDSA_KEY`.
2. The **private key** — stored automatically in your macOS Keychain
   under `Sparkle: ed25519 private key`. **Do not export, commit, or share.**

If you ever need to retrieve it (e.g. to migrate machines):

```bash
.build/artifacts/sparkle/Sparkle/bin/generate_keys -x ~/Desktop/sparkle-key.private
```

Treat that file like a Bitcoin seed — losing it means you can never sign
another update for existing installs.

## Step 2 — Decide where the appcast lives

The appcast is a small XML file installed copies poll for new versions.
It needs to be at a stable HTTPS URL. Two cheap options:

**Option A — GitHub Pages (recommended)**

1. Enable Pages on the `satsdisco/ledge` repo (Settings → Pages → Source: `main` branch, `/docs` folder, save).
2. Commit `docs/appcast.xml` to the repo.
3. URL becomes `https://satsdisco.github.io/ledge/appcast.xml` — already
   the placeholder in `Info.plist`, so no change needed.

**Option B — GitHub Release asset**

Upload `appcast.xml` to each release. URL is unstable
(`/releases/latest/download/appcast.xml` works but Sparkle prefers a
stable URL across versions). Slightly more brittle. Skip unless Pages is
unavailable.

## Step 3 — Wire the release script

`scripts/release.sh` already builds and signs the DMG. Add two steps after
DMG creation (insert near the bottom):

```bash
# 1. Sparkle EdDSA signature for the DMG.
SIGNATURE_OUTPUT=$(./.build/artifacts/sparkle/Sparkle/bin/sign_update "dist/Ledge-${VERSION}.dmg")
# Outputs: sparkle:edSignature="..." length="..."

# 2. Append a new <item> to docs/appcast.xml with:
#    - <enclosure url="https://github.com/satsdisco/ledge/releases/download/v${VERSION}/Ledge-${VERSION}.dmg"
#                 sparkle:version="${BUILD_NUMBER}"
#                 sparkle:shortVersionString="${VERSION}"
#                 ${SIGNATURE_OUTPUT}
#                 type="application/octet-stream" />
#    - <pubDate>...</pubDate>
#    - <description>...</description>  (release notes)
```

You can either generate the appcast entry by hand for the first 1–2
releases (simpler, more deliberate) or write a small Swift/sh helper that
emits it. For 1–2 releases per quarter the manual path is fine.

## Step 4 — First appcast

Create `docs/appcast.xml` with one initial item describing the current
version. Minimal template:

```xml
<?xml version="1.0" standalone="yes"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Ledge</title>
        <link>https://github.com/satsdisco/ledge</link>
        <description>Most recent updates to Ledge</description>
        <language>en</language>

        <item>
            <title>0.9.0</title>
            <pubDate>Tue, 12 May 2026 00:00:00 +0000</pubDate>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <description><![CDATA[
                <h3>What's new</h3>
                <ul>
                    <li>Clipboard module with OCR on stashed images</li>
                    <li>Notes module — daily notepad with markdown rendering</li>
                    <li>Stopwatch mode in Timer</li>
                </ul>
            ]]></description>
            <enclosure url="https://github.com/satsdisco/ledge/releases/download/v0.9.0/Ledge-0.9.0.dmg"
                       sparkle:version="9"
                       sparkle:shortVersionString="0.9.0"
                       sparkle:edSignature="PASTE_FROM_SIGN_UPDATE"
                       length="PASTE_FROM_SIGN_UPDATE"
                       type="application/octet-stream" />
        </item>
    </channel>
</rss>
```

## Verifying it works

After the public key is in Info.plist and the appcast is live:

1. Build a current copy: `./scripts/make-app.sh`
2. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`,
   build a new DMG, run `sign_update` on it, append to appcast, push.
3. Run the *older* `.app` and click Settings → General → Updates → Check Now.
   Sparkle should find and offer the new version.

If Sparkle says "No update available," it found the appcast but version
numbers match — that's expected. Increase the bundle version on the new
build.

## Operational notes

- **Never bump `CFBundleVersion` backward.** Sparkle uses it to decide
  whether an appcast item is "newer" than the running app.
- **Re-sign Sparkle.framework with your Developer ID for production
  releases.** `scripts/make-app.sh` currently signs with whatever
  `SIGN_IDENTITY` is set to (default ad-hoc). For Developer-ID-signed
  releases, pass `SIGN_IDENTITY="Developer ID Application: NAME (TEAMID)"`
  before invoking the script — both the app and the embedded framework get
  signed with that identity, which is required for notarization.
- **Notarization stamps both.** When you notarize the DMG, the embedded
  `Sparkle.framework` is notarized along with the host app, since they're
  bundled together.
- **Release notes** go in the `<description>` block of each appcast item.
  Sparkle renders them in the update prompt — keep them readable.
