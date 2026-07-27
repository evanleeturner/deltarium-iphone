# STORE_LISTING.md — the App Store submission sheet

*Everything the App Store Connect forms will ask for, drafted and
character-counted, plus the one-time setup checklist. Committed on purpose:
the first draft of this file was untracked and lost. Redrafted 2026-07-26.*

## One-time setup (owner, web UI — the API cannot do this step)

The App Store Connect API refuses app-record creation (probed 2026-07-26:
`The resource 'apps' does not allow 'CREATE'`). At
<https://appstoreconnect.apple.com> → My Apps → **+** → New App, enter:

| Field | Value |
| --- | --- |
| Platform | iOS |
| Name | Deltarium |
| Primary language | English (U.S.) |
| Bundle ID | `com.evanleeturner.easymodeler` (explicit, named "Deltarium") |
| SKU | `DELTARIUM1` |
| User access | Full access |

The bundle ID is already registered (resource `VXR8FSX8FJ`, 2026-07-26). If
Apple reports the name "Deltarium" is taken, the fallback is
**"Deltarium: Worlds of Change"** (27 characters, limit 30).

## GitHub secrets (release workflow)

`.github/workflows/release.yml` needs 3 repository secrets — key ID, issuer
ID, and the `.p8` body. Set from this box:

```bash
gh secret set ASC_KEY_ID --repo evanleeturner/deltarium-iphone
gh secret set ASC_ISSUER_ID --repo evanleeturner/deltarium-iphone
gh secret set ASC_PRIVATE_KEY --repo evanleeturner/deltarium-iphone < AuthKey_XXXXX.p8
```

The key values live outside every repo, in the house credential notes. If the
first run fails at signing with a permissions error, the key's role is too
low for cloud-managed signing: generate a new API key with the **App
Manager** role in App Store Connect → Users and Access → Integrations, and
update the 3 secrets.

## Version 1.0.0 metadata (copy-paste fields)

**Name** (limit 30)

> Deltarium

**Subtitle** (28 of limit 30)

> Play with the math of change

**Category.** Primary: Education. Secondary: none.

**Price.** Free. Availability: all territories.

**Keywords** (93 of limit 100, comma-separated, no spaces)

> math,science,physics,simulation,chaos,equations,ode,ecology,orbits,relativity,education,model

**Promotional text** (151 of limit 170)

> 8 worlds of living mathematics: rabbits and foxes, a chaotic butterfly,
> three dancing stars, a rocket bending time. Press play and watch change
> happen.

**Description** (about 2,300 of limit 4,000; plain text, blank-line breaks)

> Deltarium is a place to walk among worlds, the way a planetarium is a
> place to walk among stars. Each world is a living system of change. You
> move a few sliders, press play, and watch what the mathematics does:
> rabbits and foxes chase each other in cycles, a chaotic attractor traces
> its butterfly wings, a rocket bends time on its way to another star.
>
> Built for kids and curious people first, and for scientists too. There is
> nothing to sign into, nothing to buy, and no ads. The app runs entirely on
> your phone and collects nothing.
>
> THE 8 WORLDS
>
> PREDATOR AND PREY. The classic hare-and-lynx cycle. Set the birth,
> hunting, and dying rates and watch the populations chase each other around
> a loop. A guided tour walks through this world one step at a time.
>
> THE BUTTERFLY. The Lorenz attractor in 3D, spun with a finger. Turn on the
> twin path, which starts a hair away from the first, and watch the two
> separate. The butterfly effect you can see.
>
> ESTUARY. A coastal model of nutrients and life that blooms and crashes
> with the seasons.
>
> THE DANCE. Three stars pulling on each other, including the famous
> figure-eight where they chase one another forever.
>
> PARKING IN SPACE. The 5 Lagrange points, the spots where a small craft can
> hold its place relative to the Earth and Moon. Give all 5 a shared kick
> and see which ones stay parked and which wander off.
>
> RADIOACTIVITY. How a radioactive source fades over time, following the
> real decay chain from a parent down through its daughters.
>
> TIME DILATION. A rocket that holds a steady 1 gravity of thrust all the
> way to a distant star, flipping over at the midpoint to slow down. The
> clock on the ship and the clock back on Earth pull apart.
>
> BUILD YOUR OWN. Write your own equations, add sliders for the parts you
> want to tune, and watch the system run.
>
> UNDER THE HOOD
>
> Every world is a real system of ordinary differential equations, solved on
> your phone by the same numerical method scientists use. Each screen
> carries a science card naming the model, its author, and a reference you
> can look up. The phone's engine is checked against a published Python
> reference, and all the source code is public at
> github.com/evanleeturner/deltarium-iphone.

**What's New in This Version**

> First release. 8 worlds, a guided tour, and Build Your Own equations.

**URLs**

| Field | Value |
| --- | --- |
| Support URL | <https://github.com/evanleeturner/deltarium-iphone/issues> |
| Marketing URL (optional) | <https://github.com/evanleeturner/deltarium-iphone> |
| Privacy policy URL | <https://github.com/evanleeturner/deltarium-iphone/blob/main/docs/PRIVACY.md> |

**Copyright.** © 2026 Evan Lee Turner

## Questionnaires

**App Privacy.** "Do you or your third-party partners collect data from this
app?" → **No** → the label reads "Data Not Collected". True by construction:
no network calls, no analytics, no third-party code (see
[`PRIVACY.md`](PRIVACY.md)).

**Age rating.** Answer **None** to every content question → rating **4+**.

**Export compliance.** Handled in the build: the release Info.plist carries
`ITSAppUsesNonExemptEncryption = false` (see `project.yml`), so uploads skip
the per-build encryption question.

**App Review notes.** No sign-in, no account, no configuration. All content
runs on device with no network.

## Screenshots (iPhone-only app, so 1 size class)

**Upload the files in `docs/store-assets/appstore/` — 1284x2778 exactly.**
The App Store Connect uploader for this listing accepts only 1242x2688,
2688x1242, 1284x2778, or 2778x1284 (its own error lists them; the raw
1290x2796 captures were refused, 2026-07-27). The store set is the raw
captures center-cropped by 6x18 px (3 off each side, 9 off top and bottom),
which reaches 1284x2778 with the status bar intact and nothing visible
lost. Recipe, if the raw shots in `docs/screenshots/` ever change:
PIL `crop((3, 9, 1287, 2787))` on each 1290x2796 file.

The app targets iPhone only (`TARGETED_DEVICE_FAMILY = 1`), so no iPad set
is required. Suggested order (all in `store-assets/appstore/`):

1. `home.png` — the hall of worlds
2. `predator-prey.png`
3. `butterfly.png`
4. `time-dilation.png`
5. `radioactivity.png`
6. `build-your-own.png`
7. `build-your-own-equations.png`
8. `build-your-own-coefficients.png`

## Order of operations to 1.0.0

1. Owner creates the app record (checklist above).
2. Set the 3 GitHub secrets; push this branch to `main`.
3. Run the **release** workflow (Actions → release → Run workflow). Build
   number = the run number; version = 1.0.0 from `project.yml`.
4. Wait for the build to finish processing in App Store Connect (TestFlight
   tab), then attach it to version 1.0.0.
5. Paste the metadata above, upload the screenshots, answer the 2
   questionnaires, submit for review.
