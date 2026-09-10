---
name: run-kiln
description: Build and launch the Kiln macOS app locally, optionally in light appearance or with a screenshot of its window. Use when asked to run, launch, see, or screenshot Kiln, or to check a UI change in the real app rather than in tests.
---

# Run Kiln

```bash
./scripts/run-app.sh                                    # build, launch in the Mac's appearance
./scripts/run-app.sh --light --screenshot build/kiln-light.png
```

- **Xcode:** the script picks one that meets `project.yml`'s `xcodeVersion`. Leave
  `DEVELOPER_DIR` unset unless a specific Xcode is needed.
- **Look at the screenshot.** Read the PNG after capturing it. An image without the window's
  contents usually means the terminal lacks Screen Recording permission.
- **Appearance:** without `--light` the app follows the Mac. For a contrast check on a Mac
  in dark mode, run once plain and once with `--light`. There is no dark flag.
- **Relaunching** replaces the copy the script started. A copy run from Xcode is left alone.
- **Build failures:** the log is `build/app.log`.
- **iPhone:** run the `Kiln-iOS` scheme from Xcode on a device. Live prompts do not work in
  the iOS Simulator (ADR-003).
- **Tests** are `./scripts/run-tests.sh`, not this.
