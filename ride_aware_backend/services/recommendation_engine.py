from typing import Dict, Any, List
import logging


logger = logging.getLogger(__name__)


def generate_recommendations(
    evaluation: Dict[str, Any],
    rules: Dict[str, List[str]] = None,
) -> List[str]:
    logger.debug("Generating recommendations from evaluation: %s", evaluation)
    default_rules: Dict[str, List[str]] = {
        "time_exceeded": [
            "Consider leaving earlier.",
            "Check for faster routes.",
        ],
        "weather_warning": [
            "Bring an umbrella.",
            "Allow extra travel time due to weather.",
        ],
    }
    suggestions: List[str] = []
    lookup = rules or default_rules
    for key, flagged in evaluation.items():
        if flagged and key in lookup:
            suggestions.extend(lookup[key])
    logger.debug("Generated suggestions: %s", suggestions)
    return suggestions
