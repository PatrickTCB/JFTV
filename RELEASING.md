# Releasing the Apple TV app

This fork ships one thing: the **tvOS app** (`JFTV/`) through App Store Connect. The web
site, Docker container and Roku port from the upstream repo are gone.

## Where the version numbers live

Both in `JFTV/JFTV.xcodeproj/project.pbxproj`, and both appear **twice** (Debug and
Release config blocks). Change all four values or the two configs drift.

| Key | Meaning |
|---|---|
| `MARKETING_VERSION` | The version users see, e.g. `1.0.0` |
| `CURRENT_PROJECT_VERSION` | The build number, e.g. `1` |

```
grep -n "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" JFTV/JFTV.xcodeproj/project.pbxproj
```

`TVOS_DEPLOYMENT_TARGET` is in the same file (currently **18.0**). If you raise it, the App Store
listing has to move with it.

## The one rule that keeps getting broken

**Read the real latest build number from App Store Connect or TestFlight before you bump it.
Never from memory, and never from the last release commit.** Apple rejects a build number it has
already seen, so it only ever goes up:

1. App Store Connect -> your app -> TestFlight -> note the highest build number Apple has.
2. New build number = that number + 1.
3. Then edit `project.pbxproj`.

Uploading is what makes a build number real. A number that was committed but never uploaded is
still free to reuse, but confirm that in TestFlight rather than assuming.

## Release steps

1. Do the build-number check above, then bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in
   both config blocks.
2. Update `JFTV/APP_STORE_METADATA.md` with the release notes for this version.
3. Re-read `JFTV/PRIVACY_POLICY.md`. If the release changed what data the app touches, it has
   to say so before submission.
4. Make sure `JFTVTests` passes (see `CLAUDE.md` for the command).
5. Archive and upload. Either:
   - Xcode -> Product -> Archive -> Distribute App -> App Store Connect, or
   - `scripts/release-tvos.sh` (archive -> validate -> upload; `--dry-run` stops before upload).
     It reads an App Store Connect API key from `~/.appstoreconnect/private_keys`; put your own
     key id / issuer id in the script. `scripts/asc.mjs` is a small App Store Connect client for
     checking build status and attaching release notes (`node scripts/asc.mjs status`).
6. Wait for processing, confirm the build shows up in TestFlight, then submit for review. This
   never submits automatically: a human makes that call.

## Tags

Tag every uploaded build right after the upload succeeds, so the git history is an honest record
of what Apple has:

```
git tag -a v1.0.0-build1 -m "JFTV 1.0.0 (build 1)"
git push origin v1.0.0-build1
```

Format: `v<MARKETING_VERSION>-build<CURRENT_PROJECT_VERSION>`. A build that was committed but
never uploaded does not get a tag.
