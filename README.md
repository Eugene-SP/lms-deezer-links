# Deezer Links for Lyrion Music Server

A small LMS plugin that makes links shared from the Deezer app play through the
[Deezer plugin](https://github.com/philippe44/lms-deezer) (philippe_44, Michael Herger).

- **Android:** Deezer → Share → More → **Lyrion** (the LMS Material app, F-Droid / Play) → Play now / Play next / Insert.
- **Desktop / web:** copy the link in Deezer → Material Skin → queue menu ⋮ → *Add URL to queue* → Play / Add.

Tracks, albums, playlists and artists (top tracks) are supported.

## Why it is needed

Tested with LMS 9.1.1 and Deezer plugin 3.3.0:

1. The Deezer app shares short links: `https://link.deezer.com/s/<code>`. Lyrion and Material
   Skin pass the text to LMS as is (`playlist play <url>`).
2. The Deezer plugin only recognises `https://deezer.com/<type>/<id>`. A short link, or
   `https://www.deezer.com/<lang>/track/<id>`, is treated by LMS as a plain HTTP stream and
   does not play.
3. Even an expanded link to a **track** fails in the Deezer plugin: its `explodePlaylist`
   has branches for playlists, albums, artists and podcasts, but not for tracks.

## What it does

- Registers a URL handler for `link.deezer.com/…`, `deezer.page.link/…` and
  `www.deezer.com/<lang>/<type>/<id>`. Links without a language segment are left to the
  Deezer plugin.
- Expands a short link one redirect at a time (at most three) and takes the item from the
  URL: the first redirect of `link.deezer.com/s/…` already carries
  `dest=https://www.deezer.com/track/<id>?…`. Following the chain to the end is not
  needed — where Deezer is not open it ends at `www.deezer.com/soon`.
- A track becomes `deezer://<id>.<format>` (format from the Deezer plugin settings).
  Albums, playlists and artists are expanded by the Deezer plugin; only `deezer://` items
  are kept (the playlist expansion also returns a sort-order menu entry).

The Deezer plugin must be installed and configured (ARL). Log category:
`plugin.deezerlinks`, INFO by default — one or two lines per link.

## Installation

LMS → Settings → Plugins (`http://<server>:9000/settings/server/plugins.html`):

1. At the bottom, *Additional repositories*, add
   `https://raw.githubusercontent.com/Eugene-SP/lms-deezer-links/main/repo.xml` → Apply.
2. Tick **Deezer Links** → Apply → restart LMS.
3. The plugin should be listed as active. If it still says it will be installed after a
   restart, the restart did not happen — restart LMS again.

## Building and releasing

```sh
./build.sh          # dist/DeezerLinks-<version>.zip + repo.xml (sha1 of that zip)
```

1. Bump `<version>` in `DeezerLinks/install.xml`.
2. `./build.sh`, commit `repo.xml` and the code.
3. Create the GitHub release `v<version>` and upload **that** `dist/DeezerLinks-<version>.zip`
   (zip builds are not byte-reproducible, and LMS checks the sha1).

`test-links.pl` checks the link parsing with LMS modules stubbed out (instructions inside).

## License

MIT, see [LICENSE](LICENSE).
