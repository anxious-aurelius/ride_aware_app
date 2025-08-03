from decimal import Decimal

from utils.routing import convert_decimal_to_float


def test_convert_decimal_to_float():
    data = {"a": Decimal("1.2"), "b": [Decimal("3.4"), {"c": Decimal("5.6")}]}
    assert convert_decimal_to_float(data) == {"a": 1.2, "b": [3.4, {"c": 5.6}]}
