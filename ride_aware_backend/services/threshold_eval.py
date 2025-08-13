"""Utilities for evaluating forecasts against user limits."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List


@dataclass
class Breach:
    """Represents a single metric that exceeds a user's limit."""

    metric: str
    value: float
    limit: float
    severity: str
    advice: str


def evaluate_forecast_point(point: Dict, limits: Dict) -> List[Breach]:
    """Compare a forecast point against weather limits and return breaches."""

    out: List[Breach] = []

    temp = point.get("temp")
    if temp is not None:
        if "min_temperature" in limits and temp < limits["min_temperature"]:
            out.append(
                Breach(
                    metric="temp",
                    value=temp,
                    limit=float(limits["min_temperature"]),
                    severity="warn",
                    advice="It will feel cold; consider thermal layers and gloves.",
                )
            )
        if "max_temperature" in limits and temp > limits["max_temperature"]:
            out.append(
                Breach(
                    metric="temp",
                    value=temp,
                    limit=float(limits["max_temperature"]),
                    severity="warn",
                    advice="It will be hot; hydrate well and wear breathable kit.",
                )
            )

    wind = point.get("wind_speed")
    if wind is not None and "max_wind_speed" in limits:
        limit = float(limits["max_wind_speed"])
        if wind > limit:
            sev = "alert" if wind > limit * 1.2 else "warn"
            out.append(
                Breach(
                    metric="wind_speed",
                    value=wind,
                    limit=limit,
                    severity=sev,
                    advice="Wind is high; travel light, avoid loose bags, allow extra time.",
                )
            )

    rain = point.get("rain")
    if rain is not None and "max_rain_intensity" in limits:
        if rain > float(limits["max_rain_intensity"]):
            out.append(
                Breach(
                    metric="rain",
                    value=rain,
                    limit=float(limits["max_rain_intensity"]),
                    severity="warn",
                    advice="Expect rain; waterproof jacket and mudguards recommended.",
                )
            )

    uv = point.get("uvi")
    if uv is not None and "max_uv_index" in limits:
        if uv > float(limits["max_uv_index"]):
            out.append(
                Breach(
                    metric="uvi",
                    value=uv,
                    limit=float(limits["max_uv_index"]),
                    severity="info",
                    advice="High UV; use sunscreen and glasses.",
                )
            )

    return out


def summarize_breaches(hourly_breaches: List[List[Breach]]) -> str:
    """Combine breaches into a short, de-duplicated advisory string."""

    flat = [b for lst in hourly_breaches for b in lst]
    if not flat:
        return ""

    priority = {"alert": 0, "warn": 1, "info": 2}
    flat.sort(key=lambda b: priority[b.severity])

    seen = set()
    ordered: List[str] = []
    for b in flat:
        if b.advice not in seen:
            ordered.append(b.advice)
            seen.add(b.advice)

    return " • ".join(ordered)

