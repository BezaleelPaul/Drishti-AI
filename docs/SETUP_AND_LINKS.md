# Drishti-AI — Links, Setup & How to Connect

One page with every link and start command. If it isn't here, ask before
improvising.

## 1. Live links

| What | Link |
|---|---|
| Backend API (Render, free tier) | https://drishti-ai-xg6w.onrender.com |
| Backend health check | https://drishti-ai-xg6w.onrender.com/ (expect `"status": "up"`) |
| Streamlit demo (friend-deployed, separate engine copy) | https://drishti-ai-dr.streamlit.app/ |
| Release downloads (APK, Windows, macOS, Linux) | https://github.com/BezaleelPaul/Drishti-AI/releases/tag/v1.0.0-hardened |
| Web demo (auto-deployed from `master`) | https://bezaleelpaul.github.io/Drishti-AI/ |
| Render dashboard (redeploy, logs, env vars) | https://dashboard.render.com |
| Privacy & access matrix | `docs/PRIVACY.md` |

> Render free tier sleeps when idle: first request can take ~30 s. Open the
> health-check URL a minute before any demo.

## 1b. Two engines — do not mix them up

The same pipeline code (`src/`) runs in **two independent deployments**:

- **Render (`api/`)**: engine behind FastAPI. Serves the Android / Windows /
  macOS / Linux apps. Auto-deploys on every `master` push.
- **Streamlit Cloud (`demo/app.py`)**: engine embedded in the web page
  process. It **never calls the Render backend** — it runs the pipeline in
  its own container. Deployed/owned separately: code updates reach it only
  when the owner **reboots/redeploys the Streamlit app** (dashboard → Reboot).

Privacy consequence: the mobile app is offline-first (memory-only queue, no
PHI at rest, no backup). The Streamlit demo uploads images to a third-party
cloud for processing — use synthetic/test captures there, never real patient
photos. `docs/PRIVACY.md` covers app + API only.

## 2. Start the backend
- **Cloud (normal):** nothing to start — Render runs `uvicorn api.main:app`
  on every push to `master`. Check Logs tab if `/` doesn't answer.
- **Local:** `run_windows.bat` (Windows) / `run_mac.sh` (Mac) / `run_demo.sh`.
  Localhost builds of the apps point at `http://localhost:8000` only when
  built without `--dart-define=DRISHTI_BASE_URL=...`.

## 3. Connect an app build to the backend

Release builds bake these at compile time (see `flutter_app/lib/services/api_service.dart`):

```
--dart-define=DRISHTI_BASE_URL=https://drishti-ai-xg6w.onrender.com
--dart-define=DRISHTI_API_KEY=<operator key from README of secrets>
```

All store builds (APK, Windows, macOS, Linux, web) already carry these.
The app's Online badge goes green when `/status` answers with the key.

## 4. Install per platform

| Platform | File (in the release) | How |
|---|---|---|
| Android | `netra_ai_mobile-release.apk` | Uninstall any old debug build first (signature changed), tap APK, allow unknown apps |
| Windows | `netra_ai_windows_app.zip` | Extract, run `netra_ai_mobile.exe`, no install |
| macOS | `netra_ai_macos.zip` | Unzip, right-click `netra_ai_mobile.app` → Open (unsigned bypass, once) |
| Linux | `netra_ai_linux.tar.gz` | `tar -xzf netra_ai_linux.tar.gz && ./bundle/netra_ai_mobile` |
| iOS | — (unsigned CI build only) | Needs Apple Developer account ($99/yr); see CI artifacts |

## 5. Keys & secrets (never commit)

- `DRISHTI_API_KEYS` (Render env) and repo secret of the same name hold
  `operator,doctor,admin` keys. Release builds embed the **operator** key.
- Android `key.properties` + `netra-release.jks` live only on the release
  machine and in CI secrets — losing the keystore ends Play update continuity.
- Rotate any key that ever appears in chat/logs: regenerate, update Render +
  repo secret, rebuild.

## 6. Rebuild everything (release checklist)

```powershell
# Android + Windows (needs Android SDK + VS Build Tools)
cd flutter_app
flutter build apk --release --dart-define=DRISHTI_BASE_URL=<url> --dart-define=DRISHTI_API_KEY=<op-key>
flutter build windows --release --dart-define=DRISHTI_BASE_URL=<url> --dart-define=DRISHTI_API_KEY=<op-key>
# macOS + Linux + iOS (cloud Mac / Linux runners, free)
gh workflow run 'Drishti-AI CI Pipeline' --ref master
# Publish
gh release upload v1.0.0-hardened <files> --clobber
```
