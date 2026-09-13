# Weather

`tronbyt-weather` is a Tronbyt-native, key-free Weather v1 candidate. It consumes
only bounded normalized server reports; no weather, icon or geocoder HTTP calls
occur in Pixlet. Existing upstream Weather apps remain unchanged.

Use the device's saved location and timezone. iOS provides Celsius/Fahrenheit
and Auto/Current/Forecast settings, plus a link to existing device location
configuration. No separate coordinates/provider/cache controls are needed.

Current: consistent 20px transparent icon, readable 6×13 temperature with degree
and unit, sun/moon daytime handling, compact feels-like/high-low values, condition or STALE footer. Forecast:
three equal 21px columns, weekday, local icon, high and low. AUTO uses five-second
pages: Current, optional meaningful Rain/Snow/Ice, Forecast. Current and Forecast
modes show only their requested view. Upcoming precipitation uses server guidance
at >=50% probability or >=0.2 mm within four hours; timing is approximate and
suppressed for old data. Currently measured precipitation says NOW.

Nullable/missing observations, forecast values, unknown conditions and missing
probabilities are handled explicitly. Missing location says SET LOCATION; no
useful report says UNAVAILABLE. A daily-only stale report still shows a forecast.
All icons are bundled and deterministic; `generate_icons.py` reproduces local
transparent PNGs and embedded base64 constants for single-file Pixlet portability.

Server cache: public location/timezone shared across devices and units, normalized
metric storage, 15-minute current/hourly and 60-minute daily freshness, six hours
additional LKG, five-minute failed-refresh retry spacing. See server
`internal/providers/WEATHER.md` for contract/provider swap details and Open-Meteo
usage/licensing considerations. Attribution: forecast data by Open-Meteo
(https://open-meteo.com/), CC BY 4.0; free development service is not a blanket
commercial-service license.

Offline render regression:
`apps/tronbytweather/test_render_variants.sh`
Includes Canadian clear/humid/rain/storm/ice/snow/fog/cold/hot cases, Celsius and
Fahrenheit extremes, Auto precipitation/no precipitation/stale, aligned forecasts,
unknown/null/partial data and diagnostics. Every rendered frame is exactly 64×32.
Physical approval on ben-frame is still required before marking verified.

Forecast mode fetches daily data only (approximately one provider request/hour/shared
location). Current and Auto share 15-minute current/hourly data and the same
60-minute daily cache. Nullable normalized daytime selects sun/moon; missing
daytime uses the daytime icon deterministically.
