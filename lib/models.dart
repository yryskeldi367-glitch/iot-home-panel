// models.dart -- модели данных панели.
// Reading -- универсальный пакет показаний (та же схема топиков, что и у
// настольного симулятора курсовой: smarthome/<комната>/<id>/telemetry).
/// Одна точка числового ряда (для истории и графика).
class MetricPoint {
  final DateTime time;
  final double value;
  const MetricPoint(this.time, this.value);

  Map<String, dynamic> toJson() =>
      {'t': time.millisecondsSinceEpoch, 'v': value};

  static MetricPoint fromJson(Map<String, dynamic> j) => MetricPoint(
        DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
        (j['v'] as num).toDouble(),
      );
}

/// Пакет показаний одного устройства.
class Reading {
  final String id;
  final String type; // climate | motion | gas | water | relay
  final String room;
  final DateTime time;
  final Map<String, double> values; // temp/hum/lux/ppm/damp
  final bool? flag; // motion / leak
  final String? relayState; // "on" / "off" для реле

  const Reading({
    required this.id,
    required this.type,
    required this.room,
    required this.time,
    required this.values,
    this.flag,
    this.relayState,
  });
}

/// Кольцевой ряд метрик с ограничением длины.
class Series {
  final List<MetricPoint> _points;
  final int limit;

  Series(this.limit) : _points = <MetricPoint>[];

  void add(DateTime t, double v) {
    _points.add(MetricPoint(t, v));
    if (_points.length > limit) {
      _points.removeRange(0, _points.length - limit);
    }
  }

  List<MetricPoint> get points => List.unmodifiable(_points);

  void restore(List<MetricPoint> pts) {
    _points
      ..clear()
      ..addAll(pts.length > limit ? pts.sublist(pts.length - limit) : pts);
  }

  double? get last => _points.isEmpty ? null : _points.last.value;
}

/// Утилиты чисел для отображения.
String fmt1(double? v, {String suffix = ''}) =>
    v == null ? '--' : v.toStringAsFixed(1) + suffix;
