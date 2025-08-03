from services.recommendation_engine import generate_recommendations


def test_generate_recommendations_default():
    evaluation = {"time_exceeded": True, "weather_warning": True}
    suggestions = generate_recommendations(evaluation)
    assert "Consider leaving earlier." in suggestions
    assert "Bring an umbrella." in suggestions


def test_generate_recommendations_custom():
    evaluation = {"foo": True}
    rules = {"foo": ["bar"]}
    assert generate_recommendations(evaluation, rules) == ["bar"]
