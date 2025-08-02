from typing import Dict, Any, List


def generate_recommendations(
    evaluation: Dict[str, Any],
    rules: Dict[str, List[str]] = None
) -> List[str]:
    """
    Generate user suggestions based on evaluation results.
    """
    default_rules: Dict[str, List[str]] = {
        "time_exceeded": [
            "Consider leaving earlier.",
            "Check for faster routes."
        ],
        "weather_warning": [
            "Bring an umbrella.",
            "Allow extra travel time due to weather."
        ]
    }
    suggestions: List[str] = []
    lookup = rules or default_rules
    for key, flagged in evaluation.items():
        if flagged and key in lookup:
            suggestions.extend(lookup[key])
    return suggestions