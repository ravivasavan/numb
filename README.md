# Numb

A tiny macOS app that makes your keyboard go numb so you can clean it without mashing keys.

- Swallows every keystroke and modifier the moment it launches
- Dims every screen and shows the unlock hint
- Only **⌘ ⌥ E** quits the app and restores the keyboard

## Build

```sh
./build.sh
open build/Numb.app
```

First launch will prompt for Accessibility access (required for the event tap). Grant it in **System Settings → Privacy & Security → Accessibility**, then relaunch.

## Use

1. Launch `Numb.app`
2. Screen dims, keyboard is dead
3. Clean the keyboard
4. Press **⌘ ⌥ E** to exit

## How it works

A session-level `CGEventTap` intercepts `keyDown`, `keyUp`, and `flagsChanged` events and returns `nil` to consume them. The only exception is `E` with Command + Option held, which triggers `NSApp.terminate`. A borderless `.screenSaver`-level window is rendered on every screen for the visual.

## Notes

- The tap is session-level, so the lock applies to every app on the active login session.
- Touch Bar, mouse, trackpad, and physical power button are **not** blocked. Use the power button as an emergency exit.
- Arm builds are the default in `build.sh`; edit the `-target` flag for Intel or universal.
