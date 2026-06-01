# Publishing VeltoKit

Checklist before making the repository public on GitHub.

## 1. Repository settings (GitHub UI or CLI)

Suggested **description** (≤ 350 characters):

```text
VeltoKit — unofficial Swift SDK: BLE cap IMU → GameInput for iOS games. Sample arcade app (Pong, Dart, Bowling, Quiz) + Docusaurus docs (EN/PL).
```

Suggested **topics** (copy into *About* → *Topics* or use `gh repo edit`):

```text
swift
ios
swiftui
ble
bluetooth-low-energy
motion-sdk
game-input
imu
gyroscope
corebluetooth
sample-app
docusaurus
documentation
pong
educational
reverse-engineering
veltokit
```

One-shot CLI (after `git remote add origin …`):

```bash
gh repo edit \
  --description "VeltoKit — unofficial Swift SDK: BLE cap IMU → GameInput for iOS games. Sample arcade (Pong, Dart, Bowling, Quiz) + docs (EN/PL)." \
  --add-topic swift --add-topic ios --add-topic ble --add-topic motion-sdk \
  --add-topic game-input --add-topic imu --add-topic sample-app --add-topic docusaurus \
  --add-topic veltokit --add-topic educational
```

## 2. GitHub Pages (docs site)

1. Push `main` to GitHub (includes `.github/workflows/deploy-website.yml`).
2. **Settings → Pages → Build and deployment**: Source = **GitHub Actions**.
3. After the workflow succeeds, open the **homepage** (not only `/docs/intro`):

`https://przemyslawsikora.github.io/veltokit/`

Manual fallback:

```bash
cd website && npm ci && npm run build
# upload website/build via Actions artifact, or: npm run deploy
```

Do **not** set Pages source to the repo `/docs` folder — that is a legacy redirect; the product site lives in `website/`.

## 3. Release tag (SDK snapshot — required for SPM & CocoaPods)

SPM and CocoaPods resolve versions from **git tags**. After merging `Package.swift` and `VeltoKit.podspec`:

```bash
git tag -a v0.1.0 -m "VeltoKit 0.1.0 — SPM, CocoaPods, sample + docs"
git push origin v0.1.0
```

Bump `s.version` in `VeltoKit.podspec` and the `from:` version in docs when releasing `v0.2.0`, etc.

Draft release notes: link to [docs intro](https://przemyslawsikora.github.io/veltokit/docs/intro), install via SPM/CocoaPods, list `VeltoKit/` + sample app, disclaimer (unofficial BLE).

## 4. What *not* to ship

- `website/node_modules/`, `website/build/`, `.docusaurus/` (gitignored)
- Secrets, `.env`, signing keys
- `xcuserdata/` (gitignored)

## 5. Verify before announce

```bash
cd app && open gametriki.xcodeproj   # build gametriki on device
cd website && npm run build  # EN + PL docs, no broken links
```
