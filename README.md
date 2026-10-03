# Dictation pill

A small pill at the bottom of the screen while [Voxtype](https://voxtype.io) is dictating, in the style of Wispr Flow. It uses Omarchy's popup colours, so it matches the volume OSD and changes with your theme.

![Dictation pill](preview.png)

- **Recording:** the bars follow your voice, newest level in the middle.
- **Transcribing:** the bars ripple softly until the text is typed.
- **Idle:** nothing on screen.

It shows on whichever monitor has focus, never takes keyboard focus, and lets clicks pass through. It respects `voxtype record start --no-osd`.

## Requirements

- Omarchy 4 (Quickshell shell).
- Voxtype, with `voxtype-audio-bridge` on your `PATH` (it ships with `voxtype-bin`). Omarchy installs both through *Install > Dictation*.

No other dependencies. The plugin doesn't install anything, use sudo, or touch the network. While the pill is showing it runs `voxtype-audio-bridge` to read the mic level, and stops it when the pill hides.

## Install

```bash
omarchy plugin add https://github.com/kenners22/omarchy-dictation-pill --enable
```

Then turn off Voxtype's own overlay so you don't get two:

```bash
voxtype config set osd.enabled false
systemctl --user restart voxtype
```

## Remove

```bash
omarchy plugin remove kenners22.dictation-pill
voxtype config set osd.enabled true
systemctl --user restart voxtype
```

## Tip: the first word going missing

On many laptops the mic goes to sleep after a few seconds idle and takes around half a second to wake. Voxtype starts recording straight away, but the first ~0.5-0.7 s never reaches it. The pill appears instantly, so give it a beat after pressing your dictation key before you speak. Details: [voxtype#817](https://github.com/peteonrails/voxtype/issues/817).

## Licence

MIT
