# Neutral Mac-produced phone fixtures

`MobileQAWorkspace.json` and `MobileQASettings.json` were written by the Mac TaskStore using injected disposable URLs, `seed: false`, public `save()` and the settings save path. The generator receives neutral values from `MobilePreviewFixture.generatedSession(samples: true)`. No user or TickTick data is included. `provenance.json` records hashes and the dirty source base.

The iPhone uses these bundled files only for validated Debug QA sessions. Normal launches start empty in the app container. Unknown-data cases add a synthetic payload to a copied fixture; they do not modify these originals. Missing bundle fixtures fail QA startup rather than falling back to unrelated storage.

On the recorded Xcode 27 SwiftPM layout, generate after `swift test --disable-sandbox --manifest-cache local`:

```sh
xcrun swiftc -D DEBUG -parse-as-library -I .build/out/Products/Debug \
  -module-cache-path /tmp/taskovsky-mobile-module-cache \
  Mobile/App/MobilePreviewFixture.swift scripts/mobile-fixture-tool.swift \
  .build/out/Products/Debug/TaskovskyCore.o \
  .build/out/Products/Debug/TaskovskyDomain.o \
  .build/out/Products/Debug/TaskovskyWorkspace.o \
  -o /tmp/taskovsky-mobile-fixture-tool
/tmp/taskovsky-mobile-fixture-tool generate "$PWD/Mobile/Fixtures"
```

Re-generation replaces these development fixtures; recheck provenance hashes. The helper's `verify`, `verify-capture` and `verify-first-capture` modes load a phone QA folder through Mac TaskStore without saving, expecting 8, 9 or 1 records respectively. It requires a UUID beneath `TaskovskyMobile/QA` and the initial audit file, rejecting ordinary workspace paths. The paths/object layout describe the recorded toolchain, not a portable build-system contract.
