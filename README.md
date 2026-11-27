# Pure Lyrics

A floating desktop widget that shows DMS's own synced lyrics view: word-by-word fill, spring
scrolling, lines that grow into the centre, accent colours from the cover art.

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

DMS Settings → Desktop Widgets → Pure Lyrics:

- Font (any installed family, or the DMS font)
- Active line weight and other lines weight
- One line mode
- Cover and title header until the first line
- Text shadow (on by default)
- Active line glow (animates every frame)
- Smooth sweep
- Background and border opacity

Lyrics providers, sync and the followed player come from DMS Settings → Media.

## Requirements

- DMS >= 2.1.2 with the lyrics backend (`dms` server capability `lyrics`)
