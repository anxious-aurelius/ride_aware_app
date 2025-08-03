# ride-aware-mvp

## Configuration

The backend requires several environment variables:

- `OPENWEATHER_API_KEY` – API key for accessing OpenWeather data.
- `OPENWEATHER_URL` *(optional)* – Base URL for the OpenWeather One Call API.
  Defaults to the free endpoint `https://api.openweathermap.org/data/2.5/onecall`.

## Deployment

Ensure `OPENWEATHER_API_KEY` is set in the environment where the backend runs.
`OPENWEATHER_URL` may be overridden if pointing to a different OpenWeather
instance; otherwise, it falls back to the free v2.5 endpoint listed above.
