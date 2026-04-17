# Numb

A tiny macOS app that makes your keyboard go numb so you can clean it without mashing keys. Toddlers and cats welcome.

![Numb — default state: blurred screen, on-screen keyboard at rest](docs/default-state.png)

## What it does

- Swallows every keystroke and modifier the moment it launches
- Blurs and dims every connected display so you know it's locked
- Renders a live on-screen Mac keyboard that scales to 75% of each screen's width
- Every stray press flashes the matching key a **random color** from a 24-hue palette, then slowly fades back over 2.5s — accidental lightshow
- Only **⌘ ⌥ K** quits the app and brings the keyboard back

Mouse, trackpad, and the physical power button are not blocked, so you always have a way out.

![Numb — light show activated: random colors flashing across the keyboard as keys are mashed](docs/light-show.png)

## Install

[**Download Numb.zip**](https://github.com/ravivasavan/numb/releases/latest/download/Numb.zip) &nbsp;·&nbsp; [all releases](https://github.com/ravivasavan/numb/releases)

1. Download `Numb.zip` from the link above (or the [releases page](https://github.com/ravivasavan/numb/releases/latest)).
2. Unzip and drag `Numb.app` into `/Applications`.
3. First launch prompts for **Accessibility** access — required for the keyboard lock. Grant it in **System Settings → Privacy & Security → Accessibility**, then relaunch.

## Use

1. Open `Numb.app`
2. Screen blurs + dims, keyboard is dead
3. Clean the keyboard (or let the toddler / cat go to town)
4. Press **⌘ ⌥ K** to unlock

## Build from source

```sh
./build.sh
open build/Numb.app
```

Requires Xcode command-line tools (`swiftc`, `iconutil`, `sips`). The script builds the `.app` bundle, generates the icon set from `Resources/AppIcon.png`, and ad-hoc signs the result.
