# deltarium-iphone — XTOOL.md

*The iOS-from-Linux lane: build and sign the iPhone app on this Linux box with
[xtool](https://github.com/xtool-org/xtool), no Mac. The same lane the IRS app
(`irs-penalty-calculate`) and `ham-measure` proved end-to-end — both install and
run on the owner's iPhone from it. Full scar detail (SDK install, App Store
Connect auth, the toolchain issues) lives in the IRS app's `docs/XTOOL.md`; the
essentials are restated here so this repo is self-contained.*

## State (2026-07-26)

| Piece | State |
| --- | --- |
| xtool 1.17.0 AppImage | ✅ `~/.local/bin/xtool` |
| Swift 6.3.3 (swiftly) | ✅ `source ~/.local/share/swiftly/env.sh` first — tool shells lose PATH |
| darwin Swift SDK | ✅ installed (`swift sdk list` → `darwin`); `App/` builds via `xtool dev build` |
| ASC key `.p8` + issuer / key IDs | live OUTSIDE the repo (see IRS `XTOOL.md`); never committed |
| usbmuxd + pairing | proven by the IRS and ham apps |
| iPhone Developer Mode + cable | needed at the device gate |

## The Kit-first backbone

`EasyModelerKit/` is pure `Double` arithmetic — no UIKit, no SwiftUI, no simd,
no network — so it builds and tests on Linux and in CI, like HamKit and the IRS
app's PenaltyKit. The SwiftUI + xtool app shell is a separate package under
`App/` (a later phase), mirroring ham-measure's split.

Keeping the numerical core Linux-buildable is also the fidelity lane: plain
`+ − × ÷` (no simd, no platform transcendentals) means Linux-x86 and iOS-ARM
integrate bit-identically, so the engine can be checked against the Python
`port_reference` fixtures on either platform.

## The App/ shell

`App/` is the shipped Deltarium app (feature-complete, nine worlds), following
ham-measure's `App/` exactly: one automatic library product in `Package.swift`
(xtool packs the cwd package's single automatic library — a `type:` or a second
product breaks selection), an `xtool.yml` (bundleID, product, `infoPath`,
`iconPath`), `Support/Info.plist`, and `Resources/AppIcon.png`. Build with
`xtool dev build`; the `App/.build/` and `App/xtool/` trees are gitignored.
Development builds and device installs are proven end-to-end (owner device gates).

## Distribution: the Linux → App Store path (research, 2026-07-26)

> **Decision (2026-07-26): option (c), the macOS CI runner.** The lane is
> `.github/workflows/release.yml` (manual trigger): XcodeGen generates the
> project from `project.yml`, `xcodebuild archive` + `-exportArchive` with
> cloud-managed signing via the ASC `.p8` (repo secrets `ASC_KEY_ID`,
> `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`), destination `upload`. Xcode stamps the
> DT\* keys and compiles `Assets.car` from `App/Assets.xcassets`. The research
> below is kept as the record of why.

Development and device installs are proven; **App Store distribution is a
separate, unproven lane**. Findings from a research spike:

**Bottom line.** The *upload* is a solved problem from Linux. The *build* and
*sign* pieces exist on Linux too. The real obstacle is **App Store Connect's
post-upload bundle validation**, which a device install never touches, and one
piece of it (the `Assets.car` app icon) has no Linux generator today. So a
fully-Linux submit is plausible but unverified, and the guaranteed fallback is a
thin macOS CI job for the final archive plus upload.

### The three legs

| Leg | Linux status |
| --- | --- |
| Build a Release `.ipa` | ✅ `xtool dev build --configuration release --ipa` produces one |
| Sign for distribution | ⚠️ not via xtool — its `--sign` uses a **development** identity only (no distribution flag; xtool issue #117 open). Mint a distribution cert (`IOS_DISTRIBUTION`) + App Store profile (`IOS_APP_STORE`) through the ASC API with the existing `.p8`, then re-sign the `.ipa` on Linux with `zsign` (or xtool's own `XKit` signer) |
| Upload to App Store Connect | ✅ **solved.** Apple's **Build Upload API** (GA in ASC API 4.1, WWDC25 session 324) is plain HTTPS + JWT from the `.p8`: `POST /v1/buildUploads` → `/v1/buildUploadFiles` → PUT the parts → PATCH commit → poll state. `Apple-Actions/upload-testflight-build@v4` has an `appstore-api` backend that runs on Linux and is a ready reference implementation |

### The real blocker: bundle validation

App Store Connect rejects non-Xcode bundles at validation for reasons a device
install never sees:

1. **DT\* Info.plist keys** — `DTXcode`, `DTXcodeBuild`, `DTSDKName`, `DTSDKBuild`,
   `DTPlatformName/Version/Build`, `DTCompiler`, `BuildMachineOSBuild` — must be
   present and match a **currently supported, non-beta** Xcode/SDK. Missing or
   stale keys give the "Unsupported SDK or Xcode version" error that other
   non-Xcode toolchains (Godot, RoboVM) fixed by stamping the full set. Stampable
   in principle, unproven for xtool.
2. **`Assets.car` app icon** + `CFBundleIconName` — mandatory for submission.
   `actool` is macOS-only and **there is no Linux `Assets.car` generator**. This
   is the one hard Mac dependency: build the `.car` once on any Mac (or one macOS
   CI run per icon change) and commit it into the bundle at pack time.
3. Minor: `ITSAppUsesNonExemptEncryption` (a trivial plist key) and a residual
   SwiftSupport risk if any Swift dylibs get embedded.

### Options, ranked

- **(a) Fully-Linux** (xtool release build → stamp DT keys + inject a committed
  `Assets.car` → `zsign` distribution re-sign → Build Upload API): every piece
  exists on Linux, but there is **no end-to-end success report** (searched through
  July 2026) and xtool #117 is open. Needs a Mac **once** for the `Assets.car`.
  PLAUSIBLE, UNVERIFIED.
- **(b) Transporter / fastlane on Linux**: works only with an `AppStoreInfo.plist`
  wrinkle (Xcode-generated), clunkier than the API, same validation risk. Not
  recommended now that the Build Upload API exists.
- **(c) macOS CI runner for archive + upload only** (one GitHub Actions `macos-15`
  job: `xcodebuild archive` + `-exportArchive` app-store method, cloud-managed
  signing via the `.p8`): the **guaranteed** path. Xcode stamps the DT keys and
  builds `Assets.car` for free, and the SwiftPM/xtool layout keeps the Mac job
  thin.

### Recommended next action

Run the cheap probe from this box, because the ASC pipeline now returns
machine-readable `StateDetail` diagnostics per attempt, so each rejection becomes
a named, individually fixable ITMS code:

1. Mint an `IOS_DISTRIBUTION` cert (OpenSSL CSR) + `IOS_APP_STORE` profile via the
   ASC API with the existing `.p8`.
2. Take `xtool dev build --configuration release --ipa`, stamp the full DT\* key
   set to match the Xcode release behind the installed darwin SDK, set
   `CFBundleIconName` (borrow one Mac session for the `Assets.car` first, or take
   the icon error on probe #1), re-sign with `zsign`.
3. Upload via the Build Upload API (crib `Apple-Actions/upload-testflight-build`'s
   `appstore-api` backend) and read the `StateDetail` errors.

One upload converts every remaining unknown into a fixable item, or proves the
macOS-CI fallback (c) is needed. Either way the `.p8` stays outside the repo.

### Sources

xtool [repo](https://github.com/xtool-org/xtool) ·
[#117 upload to App Store (open)](https://github.com/xtool-org/xtool/issues/117) ·
Apple [Build Uploads API](https://developer.apple.com/documentation/appstoreconnectapi/build-uploads) ·
[WWDC25 session 324](https://developer.apple.com/videos/play/wwdc2025/324/) ·
[Apple-Actions/upload-testflight-build](https://github.com/Apple-Actions/upload-testflight-build) ·
[zsign](https://github.com/zhlynn/zsign) ·
[Assets.car format (timac)](https://blog.timac.org/2018/1018-reverse-engineering-the-car-file-format/).
