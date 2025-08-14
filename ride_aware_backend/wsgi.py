"""WSGI entrypoint for running the FastAPI app on WSGI servers.

This wraps the ASGI application defined in :mod:`main` with
``a2wsgi.ASGIMiddleware`` so that the project can run on platforms that only
support the WSGI interface (e.g. the CIS devweb container). The resulting
``application`` object is compatible with servers like Gunicorn.
"""

from a2wsgi import ASGIMiddleware
from main import app

# Expose a WSGI-compatible callable for Gunicorn or other WSGI servers.
application = ASGIMiddleware(app)
