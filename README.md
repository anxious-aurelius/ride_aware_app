# ride-aware-mvp

## Configuration

The backend requires several environment variables:

- `OPENWEATHER_API_KEY` – API key for accessing OpenWeather data.
- `OPENWEATHER_URL` *(optional)* – Base URL for the OpenWeather 5-day forecast API.
  Defaults to the free endpoint `https://api.openweathermap.org/data/2.5/forecast`.

## Deployment

Ensure `OPENWEATHER_API_KEY` is set in the environment where the backend runs.
`OPENWEATHER_URL` may be overridden if pointing to a different OpenWeather
instance; otherwise, it falls back to the free forecast endpoint listed above.

## Building and Running

The backend lives in the `ride_aware_backend` directory and uses FastAPI. Its
ASGI application is defined in `main.py`, while `wsgi.py` exposes a
WSGI-compatible `application` object using `a2wsgi`.

### Local development (ASGI)

```bash
cd ride_aware_backend
pip install -r requirements.txt
uvicorn main:app --reload
```

### Running on a WSGI container

For environments like the CIS devweb platform that only support WSGI:

```bash
cd ride_aware_backend
pip install -r requirements.txt
gunicorn wsgi:application
```

If the environment lacks internet access, vendor the dependencies and adjust
`PYTHONPATH` as described in the [CIS devweb Python guide]
(https://docs.cis.strath.ac.uk/devweb/python/).

#### Deploying to the CIS devweb container

1. Install dependencies into a `vendor` directory on a lab machine:

   ```bash
   cd ride_aware_backend
   pip install -r requirements.txt -t vendor
   ```

   Add the `vendor` folder to the Python path either by setting
   `PYTHONPATH=vendor` or by inserting the snippet from the devweb guide at the
   top of `wsgi.py`.

2. Copy the contents of `ride_aware_backend/` (including `vendor/` and
   `wsgi.py`) to `~/DEVWEB/2024/python` on the devweb server.

3. Restart the application so Gunicorn reloads it:

   ```bash
   ssh <username>@linuxlab.cis.strath.ac.uk
   touch ~/DEVWEB/2024/python/wsgi.py
   ```

4. Verify the deployment by visiting
   `https://devweb2024.cis.strath.ac.uk/<username>-python/docs` or by issuing a
   request:

   ```bash
   curl https://devweb2024.cis.strath.ac.uk/<username>-python/docs
   ```

   The platform logs output to
   `~/DEVWEB/2024/.logs/python/python.out.log` if troubleshooting is needed.
