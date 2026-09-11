# Local Weather

Candidate Tronbyt app backed by the server-side OpenWeather One Call 3.0
adapter. Device location and timezone are inherited by default. The app receives
only sanitized weather JSON; the OpenWeather credential remains encrypted on
the server. One Call 3.0 updates its model approximately every ten minutes, so
the recommended render interval is ten minutes.
