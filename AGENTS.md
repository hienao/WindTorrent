# WindTorrent public repository

This repository contains product documentation, presentation assets, and user feedback. The application source is private and must remain outside this repository. Do not copy application code, development configuration, build output, credentials, real backups, or private Git history here.

- Keep `README.md` in English. Localized introductions are `README.zh-CN.md`, `README.ja.md`, `README.de.md`, `README.es.md`, `README.fr.md`, `README.pt-BR.md`, and `README.ru.md`. Keep the language selector on every README complete, with the current language shown as plain text. Keep product facts aligned across all introductions.
- Connection guides and FAQ are available in English (`docs/`) and Simplified Chinese (`docs/zh-CN/`). Label links to those guides, the website, privacy policy, and support forms with their actual languages in other introductions. The app interface currently supports English, Simplified Chinese, and Japanese; translated repository introductions do not imply additional app UI languages. If adding another introduction, also update the introduction count in each README.
- Verify product claims against the current app and store listing. Link to Google Play for installs; do not imply iOS availability or that this app downloads files directly onto Android.
- Free and Pro have the same core management features. Pro is a separate paid app with no advertising SDK; both editions use Firebase Analytics. Do not describe Pro as analytics-free or an in-app upgrade.
- Use only reviewed public assets or dedicated demo captures. Distinguish store preview compositions from current screenshots. Keep image provenance in `assets/readme/README.md`.
- Privacy policy and the website are maintained centrally in MyPlayAppPages. Link to `https://hienao-apps.pages.dev/windtorrent/` and `https://hienao-apps.pages.dev/windtorrent/privacy/`; do not duplicate those pages here or introduce another hosted site.
- Add release notes only for verified changes, and do not claim a production rollout is complete without checking Google Play. Keep both languages aligned.
- Documentation has no app build or CI requirement. Check relative links, image references, issue form YAML, narrow/wide rendering, and `git diff --check` before publishing.
