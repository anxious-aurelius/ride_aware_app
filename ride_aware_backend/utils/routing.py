
def convert_decimal_to_float(obj):
    if isinstance(obj, dict):
        return {k: convert_decimal_to_float(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [convert_decimal_to_float(v) for v in obj]
    elif isinstance(obj, float):
        return obj
    elif hasattr(obj, '__float__'):
        return float(obj)
    return obj
