# WeatherShare VIP 2.0

Production-oriented SwiftUI weather app for iOS 17+.

## Included
- Device location + reverse geocoding
- City search with live suggestions
- Current conditions
- 24-hour forecast
- 7-day forecast
- Rain probability and precipitation
- UV, pressure, humidity and wind
- Sunrise / sunset
- Apple Map location card
- Metric / imperial units
- World clock
- Feedback + app information
- Request cancellation, timeout handling and user-friendly network errors

## Data
Weather: Open-Meteo. No API key is required for the default public endpoints.

## iPhone-only build
The repository includes `.github/workflows/build-real-ipa.yml`.
The workflow builds the physical-device app on a GitHub-hosted macOS runner, verifies the Mach-O executable and creates an IPA with this exact structure:

```text
WeatherShare-unsigned.ipa
└── Payload/
    └── WeatherShare.app/
        ├── Info.plist
        └── WeatherShare   # Mach-O arm64 executable
```

The workflow uploads the IPA itself with `archive: false`, so the GitHub artifact is not wrapped in another ZIP. After downloading, use the `WeatherShare-unsigned.ipa` file for your signing workflow (for example ESign with your own authorized certificate/profile).
