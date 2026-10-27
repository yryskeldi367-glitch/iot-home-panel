// app_state.dart -- центральное состояние панели (ChangeNotifier).
// Два источника данных: DemoSource (локально, без интернета) и MqttLink
// (реальный брокер). Оба сводятся к одному методу ingest() -- UI не знает,
// откуда пришли данные.
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'models.dart';
import 'mqtt_service.dart';
import 'simulator.dart';
import 'store.dart';

class RelayView {
  final String id;
  final String room;
  bool on;
  RelayView(this.id, this.room, this.on);
}

class AppState extends ChangeNotifier {
  final LocalStore store = LocalStore();

  // -- настройки (сохраняются локально)
  bool demoMode = true;
  String host = '192.168.1.50';
  int port = 1883;

  // -- состояние подключения: demo | connecting | online | offline | error
  String status = 'demo';
  String? lastError;

  // -- живые данные
  final Map<String, Reading> latest = {};
  final Map<String, List<MetricPoint>> series = {};
  final List<String> events = [];

  DemoSource? _demo;
  MqttLink? _link;
  Timer? _saver;
  bool _dirty = false;

  static const int seriesLimit = 600; // 10 минут при периоде 1 с
  static const int eventsLimit = 100;

  // ------------------------------------------------------------------
  // Жизненный цикл
  // ------------------------------------------------------------------

  Future<void> init() async {
    final settings = await store.read('settings.json');
    if (settings != null) {
      demoMode = (settings['demo'] as bool?) ?? true;
      host = (settings['host'] as String?) ?? host;
      port = (settings['port'] as num?)?.toInt() ?? port;
    }
    await _restoreHistory();
    if (demoMode) {
      _startDemo();
    } else {
      status = 'offline';
    }
    _saver = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_dirty) _saveHistory();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _saver?.cancel();
    _demo?.dispose();
    _link?.disconnect();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Демо-режим (без интернета)
  // ------------------------------------------------------------------

  void _startDemo() {
    _link?.disconnect();
    _demo?.dispose();
    _demo = DemoSource(ingest);
    status = 'demo';
    notifyListeners();
  }

  void _stopDemo() {
    _demo?.dispose();
    _demo = null;
  }

  // ------------------------------------------------------------------
  // Режим реального брокера
  // ------------------------------------------------------------------

  Future<void> connectMqtt(String host, int port) async {
    this.host = host;
    this.port = port;
    _stopDemo();
    _link ??= MqttLink(onJson: ingest, onStatus: _onMqttStatus);
    await _link!.connect(host, port);
    notifyListeners();
  }

  void disconnectMqtt() {
    _link?.disconnect();
    status = 'offline';
    notifyListeners();
  }

  void _onMqttStatus(String st) {
    if (st.startsWith('err:')) {
      lastError = st.substring(4);
      status = 'error';
    } else {
      status = st;
      if (st == 'online') lastError = null;
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Переключение режима в настройках
  // ------------------------------------------------------------------

  Future<void> setDemoMode(bool demo) async {
    demoMode = demo;
    await _saveSettings();
    if (demo) {
      _startDemo();
    } else {
      _stopDemo();
      status = 'offline';
      notifyListeners();
    }
  }

  Future<void> _saveSettings() async {
    await store.write('settings.json',
        {'demo': demoMode, 'host': host, 'port': port});
  }

  // ------------------------------------------------------------------
  // Приём данных (общий для демо и MQTT)
  // ------------------------------------------------------------------

  void ingest(String topic, Map<String, dynamic> json) {
    if (topic.endsWith('/raw')) {
      return; // строковые статусы online/offline тут не используются
    }
    final parts = topic.split('/');
    if (parts.length != 4 || parts.first != 'smarthome') return;
    final room = parts[1];
    final id = parts[2];
    final kind = parts[3];

    if (kind == 'alarm') {
      final what = json['alarm'] == 'water' ? 'Протечка воды' : 'Газ';
      final where = json['room'] ?? room;
      final ppm = json['ppm'] == null ? '' : ' ${_num(json['ppm'])} ppm';
      _addEvent('$what: $where$ppm');
      return;
    }
    if (kind != 'telemetry') return;

    final type = (json['type'] as String?) ?? 'unknown';
    final values = <String, double>{};
    json.forEach((k, v) {
      if (v is num && (k == 'temp' || k == 'hum' || k == 'lux' || k == 'ppm' || k == 'damp')) {
        values[k] = v.toDouble();
      }
    });
    final now = DateTime.now();
    final r = Reading(
      id: id,
      type: type,
      room: room,
      time: now,
      values: values,
      flag: json['motion'] == true || json['leak'] == true,
      relayState: json['state'] is String ? json['state'] as String : null,
    );
    latest[id] = r;

    // числовые ряды
    values.forEach((metric, v) {
      final key = '$id|$metric';
      final list = series.putIfAbsent(key, () => <MetricPoint>[]);
      list.add(MetricPoint(now, v));
      if (list.length > seriesLimit) {
        list.removeRange(0, list.length - seriesLimit);
      }
    });

    // реле и события тревоги
    if (type == 'relay') {
      final st = r.relayState == 'on';
      if (!_relayStates.containsKey(id) || _relayStates[id]!.on != st) {
        _relayStates[id] = RelayView(id, room, st);
      }
    }
    if (type == 'gas') {
      final ppm = values['ppm'];
      if (ppm != null) {
        if (ppm > 120 && !_gasLatched) {
          _gasLatched = true;
          _addEvent('Газ: $room ${ppm.toStringAsFixed(0)} ppm -- ТРЕВОГА');
        } else if (ppm < 90 && _gasLatched) {
          _gasLatched = false;
          _addEvent('Газ: $room нормализовался (${ppm.toStringAsFixed(0)} ppm)');
        }
      }
    }
    if (type == 'water' && r.flag == true && !_waterLatched) {
      _waterLatched = true;
      _addEvent('Протечка воды: $room');
    }
    if (type == 'water' && r.flag == false && _waterLatched) {
      _waterLatched = false;
      _addEvent('Протечка: $room -- сухо');
    }

    _dirty = true;
    notifyListeners();
  }

  bool _gasLatched = false;
  bool _waterLatched = false;

  final Map<String, RelayView> _relayStates = {};

  List<RelayView> get relays => _relayStates.values.toList()
    ..sort((x, y) => x.id.compareTo(y.id));

  void toggleRelay(String id, bool on) {
    final room = latest[id]?.room ?? '';
    if (demoMode) {
      _demo?.setRelay(id, on);
      // демо-источник сам пришлёт telemetry следующим тиком;
      // для мгновенной реакции обновляем состояние здесь
      _relayStates[id] = RelayView(id, room, on);
      ingest('smarthome/$room/$id/telemetry',
          {'type': 'relay', 'state': on ? 'on' : 'off', 'by': 'panel'});
      return;
    }
    _relayStates[id] = RelayView(id, room, on); // оптимистично
    _link?.publish('smarthome/cmd/$id',
        {'cmd': 'set', 'state': on ? 'on' : 'off', 'by': 'panel'});
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // События и история
  // ------------------------------------------------------------------

  void _addEvent(String text) {
    final t = DateTime.now();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    events.insert(0, '$hh:$mm  $text');
    if (events.length > eventsLimit) events.removeLast();
    _dirty = true;
  }

  Future<void> _restoreHistory() async {
    final data = await store.read('history.json');
    if (data == null) return;
    final ser = data['series'];
    if (ser is Map<String, dynamic>) {
      ser.forEach((key, pts) {
        if (pts is List) {
          final restored = pts
              .whereType<Map>()
              .map((m) => MetricPoint.fromJson(m.cast<String, dynamic>()))
              .toList();
          series[key] = restored.length > seriesLimit
              ? restored.sublist(restored.length - seriesLimit)
              : restored;
        }
      });
    }
    final ev = data['events'];
    if (ev is List) {
      events
        ..clear()
        ..addAll(ev.whereType<String>().take(eventsLimit));
    }
    final rel = data['relays'];
    if (rel is Map<String, dynamic>) {
      rel.forEach((id, v) {
        if (v is Map<String, dynamic>) {
          _relayStates[id] =
              RelayView(id, (v['room'] ?? '') as String, v['on'] == true);
        }
      });
    }
  }

  Future<void> _saveHistory() async {
    _dirty = false;
    final ser = <String, List<Map<String, dynamic>>>{};
    series.forEach((key, pts) {
      ser[key] = pts.map((p) => p.toJson()).toList();
    });
    final rel = <String, dynamic>{};
    _relayStates.forEach((id, r) {
      rel[id] = {'room': r.room, 'on': r.on};
    });
    await store.write('history.json', {
      'series': ser,
      'events': events,
      'relays': rel,
    });
  }

  Future<void> clearHistory() async {
    series.clear();
    events.clear();
    await store.delete('history.json');
    notifyListeners();
  }

  String get storageHint => 'локальные JSON-файлы в каталоге приложения';

  // -- удобные геттеры для UI ---------------------------------------

  Reading? climateOf(String room) {
    for (final r in latest.values) {
      if (r.type == 'climate' && r.room == room) return r;
    }
    return null;
  }

  Reading? firstOfType(String type) {
    for (final r in latest.values) {
      if (r.type == type) return r;
    }
    return null;
  }

  List<MetricPoint> pointsOf(String devId, String metric) {
    return series['$devId|$metric'] ?? const <MetricPoint>[];
  }

  // ---- случайная утилита, используется при форматировании времени событий
  String _num(Object v) {
    if (v is num) return v.toStringAsFixed(0);
    return v.toString();
  }
}
