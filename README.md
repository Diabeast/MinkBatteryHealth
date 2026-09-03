# Mink Battery Health

iPhone-dashboard voor de zelfgehoste Tesla Fleet Telemetry-installatie. De app bevat geen Tesla client secret, refresh token, private key of DuckDNS-token.

## GitHub Actions / TestFlight

De workflow `.github/workflows/testflight.yml` genereert het Capacitor iOS-project, ondertekent het met Fastlane Match en uploadt het naar TestFlight.

Benodigde GitHub Actions-secrets:

- `APP_STORE_CONNECT_API_KEY_BASE64`
- `FASTLANE_KEY_ID`
- `FASTLANE_ISSUER_ID`
- `TEAMID`
- `MATCH_PASSWORD`
- `MATCH_GIT_BASIC_AUTHORIZATION`

De dashboardwaarden zijn in versie 0.1 demonstratiegegevens. De volgende stap koppelt de app via een veilig apparaat-token aan de Mac-backend.
