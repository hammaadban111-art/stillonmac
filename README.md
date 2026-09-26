# StillOnMac

A menu bar app that keeps a Mac awake 24/7, even with the lid closed and the external monitor switched off or unplugged. It's built for running Claude Code on a Mac and controlling it from a phone with `/rc`.

Click the cup icon next to Wi-Fi to see these controls:

| Control | What it does |
|---|---|
| **Keep Mac On** | Stops system sleep, display sleep and lid-closed sleep until you turn it off. |
| **Block Shutdown & Restart** | Cancels restart, shut down and log out requests. macOS shows *"StillOnMac interrupted restart"*. |
| **Auto-Quit Closed Apps** | Quits an app a few seconds after you close its last window. Finder, Terminal and apps you choose are skipped. |
| **Display Off Now** | Turns the monitor off. The Mac stays awake. |
| **Memory tab** | What's using RAM, biggest first, in plain words: `(Emulator) qemu-system-aarch64 · 2.1 GB · running 3h 12m`. Apps are grouped with their helper processes. A stop button on every line: Quit first, Force Quit if it's ignored, and a password prompt for macOS/root processes. Critical macOS processes are locked. It only samples while the tab is open, so it costs nothing in the background. |

UI design canvas: https://claude.ai/artifact/9BiapJTbJqPoRChgYNMgjL

## Install from the DMG (easiest)

1. Download **StillOnMac.dmg** from the [latest release](https://github.com/hammaadban111-art/stillonmac/releases/tag/latest).
2. Open it and drag **StillOnMac** onto **Applications**.
3. Open StillOnMac from Applications. macOS blocks the first launch because the app isn't notarized by Apple:
   - go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**, or
   - run `xattr -dr com.apple.quarantine /Applications/StillOnMac.app` and open it again.

GitHub Actions builds a new DMG on every push (`.github/workflows/build.yml`). To make one yourself: `./scripts/make-dmg.sh` → `build/StillOnMac.dmg`. For the styled installer window, install dmgbuild first: `python3 -m pip install --user dmgbuild`.

## Build from source (on the Mac)

```bash
xcode-select --install                 # once, if you don't have the command line tools
git clone <this repo> && cd stillonmac
./scripts/build.sh --install           # builds, copies to /Applications, launches
```

On first launch, a setup window walks you through three steps:
1. **Install lid-closed helper**: asks for your password once.
2. **Allow Accessibility**: needed only for Auto-Quit.
3. **Turn on Keep Mac On**.

Then open **Settings… → Launch at login** so it starts after every reboot.

You can also run the helper setup from Terminal: `sudo ./scripts/setup-power.sh`.

## What the setup changes

- `/etc/sudoers.d/stillonmac` lets your user run exactly these two commands without a password, and nothing else:
  - `pmset -a disablesleep 1`
  - `pmset -a disablesleep 0`

  This is the only way to stop a closed MacBook from sleeping when no display is attached. Power assertions (what `caffeinate` uses) don't cover that case.
- `tcpkeepalive` and `womp` are turned on so the network stays up for remote sessions.
- Automatic macOS update installs are turned off, so updates can't restart the Mac on their own. You can still update by hand.
- The screen saver is turned off.

Undo everything: `sudo ./scripts/uninstall.sh`.

## 24/7 checklist for Claude Code `/rc`

- Keep the charger plugged in.
- **Keep Mac On** is ON (the cup icon is filled and amber).
- **Block Shutdown & Restart** is ON.
- Start Claude Code in Terminal, run `/rc`, close the lid, turn the monitor off.
- Check it: `pmset -g | grep SleepDisabled` shows `1`, and `pmset -g assertions` lists StillOnMac.

## Limits

- Nothing can block holding the power button, a kernel panic, or `sudo shutdown` typed in Terminal.
- If the Mac runs on battery and the battery runs out, it turns off.
- **Auto-Quit** only sees windows on the current Space. It resets when you switch Spaces, but an app whose only window is full screen on another Space could be quit. Add such apps to the exclusion list.
- After rebuilding, Accessibility has to be granted again, because the ad-hoc signature changes. `build.sh --install` resets the old entry for you.
- Quitting StillOnMac from its menu lets the Mac sleep normally again. It turns itself back on at the next launch.

## Project layout

```
Sources/StillOnMac/
  main.swift, AppDelegate.swift   menu bar item, popover, windows, quit handling
  AppState.swift                  settings, live status, actions
  AwakeController.swift           power assertions + pmset disablesleep
  ShutdownBlocker.swift           recognises restart/shutdown/logout quit events
  AutoQuitter.swift               quits windowless apps (Accessibility API)
  Notifier.swift                  "Restart blocked" notification
  AdminRunner.swift               runs a command as root behind the password prompt
  Memory/                         RAM sampling, plain-words names, stopping processes
  LoginItem.swift, SystemStatus.swift, Shell.swift, Theme.swift
  Views/                          SwiftUI panel, settings, onboarding
Resources/Info.plist
scripts/build.sh, make-dmg.sh, make-art.swift (icon + DMG art), dmg-settings.py, setup-power.sh, uninstall.sh
```

Requires macOS 13 or later.
