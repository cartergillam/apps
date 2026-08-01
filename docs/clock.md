# OG Clock verification

The apps repository pins Pixlet v0.50.1 in `PIXLET_VERSION`. Use that version for app
validation; older releases may reject file targets such as
`load("images/cloudy.png", CLOUDY_ASSET = "file")` with `invalid module` even
though the asset exists. Pixlet v0.42.1 is known to fail at that boundary. The
server currently embeds Pixlet Go module v0.53.1 from `tronbyt-server/go.mod`;
the same deterministic regression has also passed through that embedded
renderer. Release rehearsal should retain both checks.

On macOS arm64, a version-local setup that does not alter the system Pixlet is:

```sh
version=$(cat PIXLET_VERSION)
curl -LO "https://github.com/tronbyt/pixlet/releases/download/${version}/pixlet_${version}_darwin_arm64.tar.gz"
mkdir -p /tmp/tronbyt-pixlet
tar -xzf "pixlet_${version}_darwin_arm64.tar.gz" -C /tmp/tronbyt-pixlet
/tmp/tronbyt-pixlet/pixlet version
```

Run the deterministic Clock regression from the repository root:

```sh
/tmp/tronbyt-pixlet/pixlet format --dry-run apps/ogclock/og_clock.star
/tmp/tronbyt-pixlet/pixlet render \
  apps/ogclock/og_clock.star \
  __run_regression_tests=true \
  --output /tmp/og-clock-regression.webp
```

The embedded regression uses fixed timestamps and verifies:

- device timezone selection (`America/Toronto`);
- custom timezone selection (`America/Vancouver`);
- 12-hour and 24-hour formatting;
- Toronto daylight-saving conversion;
- the next exact minute boundary; and
- every instant inside one minute produces the same next-render boundary.

Normal rendering prints one sanitized `TRONBYT-NEXT-RENDER` timestamp. The
server honors that boundary, so a cached Clock frame is refreshed at the next
minute without scheduling redundant renders inside the current minute.
