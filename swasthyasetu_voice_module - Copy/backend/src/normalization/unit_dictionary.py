"""Unit dictionary for medical vitals and clinical measurements."""

from typing import Dict

UNIT_CANONICAL_MAP: Dict[str, str] = {
    # Temperature
    "c": "celsius",
    "celsius": "celsius",
    "f": "fahrenheit",
    "deg f": "fahrenheit",
    "degrees": "fahrenheit",
    "fahrenheit": "fahrenheit",

    # Pulse / Heart rate
    "bpm": "beats_per_minute",
    "beats/min": "beats_per_minute",
    "/min": "per_minute",

    # Blood Pressure
    "mmhg": "mmhg",
    "mm hg": "mmhg",

    # Oxygen Saturation
    "%": "percentage",
    "percent": "percentage",

    # Time / Duration
    "sec": "seconds",
    "secs": "seconds",
    "seconds": "seconds",
    "min": "minutes",
    "mins": "minutes",
    "minute": "minutes",
    "minutes": "minutes",
    "hr": "hours",
    "hrs": "hours",
    "hour": "hours",
    "hours": "hours",
    "d": "days",
    "day": "days",
    "days": "days",
    "wk": "weeks",
    "wks": "weeks",
    "week": "weeks",
    "weeks": "weeks",
    "mo": "months",
    "mos": "months",
    "month": "months",
    "months": "months",
}
