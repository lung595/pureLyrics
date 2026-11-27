# Pure Lyrics

A floating desktop widget that shows DMS's own synced lyrics view: word-by-word fill, spring
scrolling, lines that grow into the centre, fill in the DMS theme colour.

Fork of [lildengzi/pureLyrics](https://github.com/lildengzi/pureLyrics). Version 2 drops the
plugin's own fetching and rendering. `lyrics/` holds a copy of DMS 2.1.2's `LyricsOverlay`,
`LyricsLine` and `LyricsModel.js` (MIT, see `lyrics/LICENSE-DMS`), changed for the options below.
The sung fill takes the DMS theme colour (`Theme.primary`) instead of the cover-art accent.

## Why it is light

- Lyrics come from DMS's shared `LyricsService`. The dash and this widget use one controller,
  so a song is fetched once.
- The controller wakes on word and line cues, not on a fixed poll.
- With **Smooth sweep** off (default), nothing redraws between cues. Turn it on for the gliding
  fill of the dash; it redraws every frame while a line is sung.
- The widget hides when no player is playing, and then drops its lyrics subscription.

## Settings

DMS Settings → Desktop Widgets → Pure Lyrics. A search field (Ctrl+F) on top, four tabs:

- **Text**: font (any installed family, or the DMS font), middle line size, other lines size, line spacing, active line weight, other lines weight,
  one line mode
- **Effects**: cover and title header until the first line, depth blur on the lines around the
  sung one, floating sung word, text shadow (on by default),
  active line glow (animates every frame), smooth sweep
- **Player**: previous / play-pause / next buttons under the lyrics, shown on hover or always, their opacity, click a line
  to seek
- **Background**: background and border opacity

Lyrics synced per line only (no word timings from the provider) get word timings estimated from
word length, so they still fill word by word.

With several singers (lyrics that name voices, e.g. TTML), each singer takes a theme colour:
primary, tertiary, then secondary; group parts take secondary.

Instrumental breaks show DMS's wavy ring filling up until the next line.

After updating the plugin, restart DMS (`dms restart`): Quickshell keeps the old `lyrics/` types
cached across a plugin reload.

Lyrics providers, sync and the followed player come from DMS Settings → Media.

## Requirements

- DMS >= 2.1.2 with the lyrics backend (`dms` server capability `lyrics`)

## Plugin id

The id is `pureLyricsPlus`, not `pureLyrics`. DMS's registry already lists `pureLyrics` (the
upstream plugin), so with that id DMS showed the registry's metadata and checked this fork's
git remote for updates.
