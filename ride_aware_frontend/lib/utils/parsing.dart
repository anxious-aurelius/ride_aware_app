 double parseDouble(dynamic value, {double defaultValue = 0.0}) {
   if (value == null) return defaultValue;
   if (value is num) return value.toDouble();
   if (value is String) return double.tryParse(value) ?? defaultValue;
   return defaultValue;
 }
