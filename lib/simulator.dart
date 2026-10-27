// simulator.dart -- встроенный источник демо-данных.
// Работает без брокера и без интернета: те же модели, что и в настольном
// проекте (суточный ход + AR(1)-дрейф + шум + редкие события), период 1 с.
// Эмитит пакеты в том же формате, что и MQTT: (топик, JSON) -- AppState
// не различает источники.
import 'dart:async';
import 'dart:math' as math;

class DemoSource {
  final void Function(String topic, Map<String, dynamic> json) emit;
  final math.Random _rnd = math.Random();
  late final Timer _timer;

  // климат: база + дрейф AR(1)
  // базовые температуры комнат; мутируются дрейфом в _tick()
  // ignore: prefer_final_fields
  double _tLiving = 22.5, _tBedroom = 20.0, _tKitchen = 24.0;
  double _hLiving = 47, _hBedroom = 52, _hKitchen = 44;
  double _walkL = 0, _walkB = 0, _walkK = 0;

  // газ: фон + событие «готовка» с фазами рост/плато/спад
  double _gasEvent = 0;
  int _gasStage = 0; // 0 нет, 1 рост, 2 плато, 3 спад

  bool _motionUntil = false;
  int _motionTicks = 0;
  bool _leak = false;
  int _leakTicks = 0;

  bool _lampOn = false;
  bool _fanOn = false;

  DemoSource(this.emit) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void dispose() {
    _timer.cancel();
  }

  void _send(String room, String id, String type, Map<String, dynamic> fields) {
    final payload = <String, dynamic>{
      'dev': id,
      'type': type,
      'room': room,
      'ts': DateTime.now().millisecondsSinceEpoch / 1000.0,
      ...fields,
    };
    emit('smarthome/$room/$id/telemetry', payload);
  }

  void _tick() {
    final now = DateTime.now();
    final hour = now.hour;

    // --- климат гостиной
    _walkL = _walkL * 0.99 + (_rnd.nextDouble() - 0.5) * 0.08;
    final dayPhase = ((now.hour * 60 + now.minute) / 1440) * 2 * math.pi;
    final t = _tLiving +
        _walkL +
        1.8 * 0.5 * (1 - math.cos(dayPhase)) +
        _gauss() * 0.2;
    _hLiving += ((48 - 1.8 * (t - 22.5)) - _hLiving) * 0.08 + _gauss() * 0.5;
    _send('living', 'clim-living-01', 'climate', {
      'temp': _round(t),
      'hum': _round(_hLiving.clamp(20, 90)),
      'lux': _round(_lux(hour)),
    });

    // --- климат спальни
    _walkB = _walkB * 0.99 + (_rnd.nextDouble() - 0.5) * 0.06;
    _hBedroom += (52 - _hBedroom) * 0.05 + _gauss() * 0.4;
    _send('bedroom', 'clim-bedroom-01', 'climate', {
      'temp': _round(_tBedroom + _walkB + _gauss() * 0.2),
      'hum': _round(_hBedroom),
      'lux': _round(_lux(hour) * 0.6),
    });

    // --- климат кухни
    _walkK = _walkK * 0.99 + (_rnd.nextDouble() - 0.5) * 0.07;
    _hKitchen += (44 - _hKitchen) * 0.05 + _gauss() * 0.4;
    _send('kitchen', 'clim-kitchen-01', 'climate', {
      'temp': _round(_tKitchen + _walkK + _gauss() * 0.2),
      'hum': _round(_hKitchen),
      'lux': _round(_lux(hour)),
    });

    // --- движение в холле (расписание по часам)
    final p = _motionProb(hour);
    var motion = false;
    if (_motionUntil && _motionTicks > 0) {
      motion = true;
      _motionTicks--;
      if (_motionTicks == 0) _motionUntil = false;
    } else if (_rnd.nextDouble() < p) {
      _motionUntil = true;
      _motionTicks = 4 + _rnd.nextInt(12);
      motion = true;
    }
    _send('hall', 'pir-hall-01', 'motion', {
      'motion': motion,
      'hold_sec': motion ? 3 : 0,
    });

    // --- газ на кухне (автомат фаз)
    _gasTick();
    _send('kitchen', 'gas-kitchen-01', 'gas', {
      'ppm': _round(math.max(0, 8 + _rnd.nextDouble() * 12 + _gasEvent)),
    });

    // --- протечка (редкое событие)
    if (!_leak && _rnd.nextDouble() < 0.0008) {
      _leak = true;
      _leakTicks = 20 + _rnd.nextInt(25);
    } else if (_leak) {
      _leakTicks--;
      if (_leakTicks <= 0) _leak = false;
    }
    _send('bathroom', 'wat-bathroom-01', 'water', {
      'leak': _leak,
      'damp': _leak ? 42 : 0,
    });

    // --- реле: в демо-режиме состоянием управляет сама панель
    _send('living', 'rel-lamp-living-01', 'relay',
        {'state': _lampOn ? 'on' : 'off', 'by': 'demo'});
    _send('kitchen', 'rel-fan-kitchen-01', 'relay',
        {'state': _fanOn ? 'on' : 'off', 'by': 'demo'});
  }

  /// В демо-режиме переключение реле делает сама панель.
  void setRelay(String id, bool on) {
    if (id.contains('lamp')) _lampOn = on;
    if (id.contains('fan')) _fanOn = on;
  }

  void _gasTick() {
    switch (_gasStage) {
      case 0:
        if (_rnd.nextDouble() < 0.004) _gasStage = 1;
        break;
      case 1:
        _gasEvent += 25 + _rnd.nextDouble() * 60;
        if (_gasEvent > 160 + _rnd.nextDouble() * 240) _gasStage = 2;
        break;
      case 2:
        if (_rnd.nextDouble() < 0.2) _gasStage = 3;
        break;
      case 3:
        _gasEvent -= 35 + _rnd.nextDouble() * 55;
        if (_gasEvent <= 0) {
          _gasEvent = 0;
          _gasStage = 0;
        }
        break;
    }
  }

  double _lux(int hour) {
    if (hour >= 8 && hour < 19) return 300 + _rnd.nextDouble() * 350;
    if ((hour >= 6 && hour < 8) || (hour >= 19 && hour < 22)) {
      return 80 + _rnd.nextDouble() * 150;
    }
    return 1 + _rnd.nextDouble() * 12;
  }

  double _motionProb(int hour) {
    if (hour < 6) return 0.03;
    if (hour < 9) return 0.35;
    if (hour < 17) return 0.12;
    if (hour < 23) return 0.4;
    return 0.2;
  }

  double _gauss() {
    // Box-Muller без внешних зависимостей
    final u1 = math.max(_rnd.nextDouble(), 1e-9);
    final u2 = _rnd.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  double _round(double v) => (v * 10).roundToDouble() / 10;
}
