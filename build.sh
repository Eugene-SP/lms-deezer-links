#!/bin/sh
# Builds dist/DeezerLinks-<version>.zip and repo.xml for the LMS extension repository.
# The version comes from DeezerLinks/install.xml; repo.xml points at the GitHub release
# v<version>, so the zip uploaded there must be exactly this one (the sha1 is checked).
# Usage: ./build.sh  (any POSIX sh; on Windows, Git Bash)
set -eu
cd "$(dirname "$0")"

VERSION=$(sed -n 's:.*<version>\(.*\)</version>.*:\1:p' DeezerLinks/install.xml)
ZIP=DeezerLinks-$VERSION.zip
URL=${URL:-https://github.com/Eugene-SP/lms-deezer-links/releases/download/v$VERSION/$ZIP}

mkdir -p dist
rm -f dist/DeezerLinks-*.zip

# install.xml must be at the top level of the zip, without the plugin directory
if command -v zip >/dev/null 2>&1; then
	(cd DeezerLinks && zip -qrX "../dist/$ZIP" .)
elif [ -x /c/Windows/System32/tar.exe ]; then
	(cd DeezerLinks && /c/Windows/System32/tar.exe -a -cf "../dist/$ZIP" *)
else
	echo "zip (or Windows tar.exe) is required" >&2
	exit 1
fi

SHA=$(sha1sum "dist/$ZIP" | cut -d' ' -f1)

cat > repo.xml <<EOF
<?xml version='1.0' standalone='yes'?>
<extensions>
  <plugins>
    <plugin name="DeezerLinks" maxTarget="*" minTarget="8.3" version="$VERSION">
      <sha>$SHA</sha>
      <creator>Eugene-SP</creator>
      <title lang="EN">Deezer Links</title>
      <desc lang="EN">Play links shared from the Deezer app with the Deezer plugin</desc>
      <category>musicservices</category>
      <url>$URL</url>
      <link>https://github.com/Eugene-SP/lms-deezer-links</link>
    </plugin>
  </plugins>
</extensions>
EOF

echo "dist/$ZIP sha1=$SHA"
echo "repo.xml -> $URL"
