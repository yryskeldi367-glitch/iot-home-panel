// tabs.dart -- четыре экрана панели: обзор, реле, история, настройки.
import 'package:flutter/cupertino.dart';

import '../app_state.dart';
import '../models.dart';
import 'ui/widgets.dart';

/// Большой заголовок экрана в стиле iOS.
class ScreenHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const ScreenHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w700)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ====================================================================
// Вкладка «Обзор»
// ====================================================================

class HomeTab extends StatelessWidget {
  final AppState state;

  const HomeTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final living = state.climateOf('living');
            final temp = living?.values['temp'];
            final hum = living?.values['hum'];
            final gas = state.firstOfType('gas');
            final motion = state.firstOfType('motion');
            final water = state.firstOfType('water');
            final gasPpm = gas?.values['ppm'];
            final gasAlarm = (gasPpm ?? 0) > 120;
            final leak = water?.flag == true;

            return ListView(
              children: [
                ScreenHeader('Умный дом',
                    trailing: StatusPill(
                        status: state.status, lastError: state.lastError)),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Гостиная',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.secondaryLabel)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                              child: BigValue(
                                  value: fmt1(temp, suffix: '°'),
                                  label: 'температура',
                                  icon: CupertinoIcons.thermometer)),
                          Expanded(
                              child: BigValue(
                                  value: fmt1(hum, suffix: '%'),
                                  label: 'влажность',
                                  icon: CupertinoIcons.drop)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LineChart(
                        points: state.pointsOf('clim-living-01', 'temp'),
                        color: CupertinoColors.systemBlue,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                          child: MiniTile(
                              title: 'Движение (холл)',
                              value: motion?.flag == true ? 'ЕСТЬ' : 'нет',
                              icon: CupertinoIcons.person_fill)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: MiniTile(
                              title: 'Газ (кухня)',
                              value: fmt1(gasPpm, suffix: ' ppm'),
                              icon: CupertinoIcons.exclamationmark_triangle_fill,
                              alarm: gasAlarm)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                          child: MiniTile(
                              title: 'Протечка (ванна)',
                              value: leak ? 'ТЕЧЁТ!' : 'сухо',
                              icon: CupertinoIcons.drop_fill,
                              alarm: leak)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: MiniTile(
                              title: 'События',
                              value:
                                  '${state.events.length} за всё время',
                              icon: CupertinoIcons.list_bullet)),
                    ],
                  ),
                ),
                if (state.lastError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Ошибка: ${state.lastError}',
                        style: const TextStyle(
                            fontSize: 12, color: CupertinoColors.systemRed)),
                  ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ====================================================================
// Вкладка «Реле»
// ====================================================================

class RelaysTab extends StatelessWidget {
  final AppState state;

  const RelaysTab({super.key, required this.state});

  String _prettyName(String id, String room) {
    if (id.contains('lamp')) return 'Свет';
    if (id.contains('fan')) return 'Вытяжка';
    if (id.contains('cool')) return 'Кондиционер';
    if (id.contains('heat')) return 'Обогрев';
    if (id.contains('valve')) return 'Клапан';
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final relays = state.relays;
            return ListView(
              children: [
                ScreenHeader('Реле'),
                if (relays.isEmpty)
                  GlassCard(
                    child: Text(
                      state.demoMode
                          ? 'Реле появятся через секунду -- демо-данные идут'
                          : 'Реле ещё не отправляли состояние. Подключитесь к брокеру и дождитесь retained-статусов.',
                      style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context)),
                    ),
                  )
                else
                  ...relays.map((r) => GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              _iconFor(r.id),
                              size: 22,
                              color: r.on
                                  ? CupertinoColors.systemGreen
                                  : CupertinoColors.systemGrey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_prettyName(r.id, r.room),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                  Text(r.room,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: CupertinoColors
                                              .secondaryLabel
                                              .resolveFrom(context))),
                                ],
                              ),
                            ),
                            CupertinoSwitch(
                              value: r.on,
                              onChanged: (v) => state.toggleRelay(r.id, v),
                            ),
                          ],
                        ),
                      )),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Переключатели отправляют команду в smarthome/cmd/<id>; '
                    'фактическое состояние реле приходит в ответ и подсвечивает переключатель.',
                    style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _iconFor(String id) {
    if (id.contains('lamp')) return CupertinoIcons.lightbulb_fill;
    if (id.contains('fan')) return CupertinoIcons.wind;
    if (id.contains('cool')) return CupertinoIcons.snow;
    if (id.contains('heat')) return CupertinoIcons.flame_fill;
    if (id.contains('valve')) return CupertinoIcons.wrench_fill;
    return CupertinoIcons.square_grid_2x2_fill;
  }
}

// ====================================================================
// Вкладка «История»
// ====================================================================

class HistoryTab extends StatefulWidget {
  final AppState state;

  const HistoryTab({super.key, required this.state});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String _metric = 'temp';

  static const _metrics = {
    'temp': ('Температура, °C', CupertinoColors.systemBlue),
    'hum': ('Влажность, %', CupertinoColors.systemTeal),
    'ppm': ('Газ, ppm', CupertinoColors.systemOrange),
  };

  @override
  Widget build(BuildContext context) {
    final st = widget.state;
    // объединяем ряды всех устройств с этой метрикой (по последнему устройству)
    String? devId;
    for (final key in st.series.keys) {
      if (key.endsWith('|$_metric')) {
        devId = key.split('|').first;
        if (st.latest[devId] != null) break;
      }
    }
    final points =
        devId == null ? const <MetricPoint>[] : st.pointsOf(devId, _metric);
    final color = _metrics[_metric]!.$2;

    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: st,
          builder: (context, _) => ListView(
            children: [
              ScreenHeader('История'),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(devId ?? '--',
                        style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context))),
                    const SizedBox(height: 8),
                    LineChart(points: points, color: color, height: 150),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: CupertinoSlidingSegmentedControl<String>(
                  groupValue: _metric,
                  children: const {
                    'temp': Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text('°C')),
                    'hum': Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text('%')),
                    'ppm': Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text('ppm')),
                  },
                  onValueChanged: (v) {
                    if (v != null) setState(() => _metric = v);
                  },
                ),
              ),
              GlassCard(
                padding: const EdgeInsets.all(0),
                child: Column(
                  children: [
                    if (st.events.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Событий пока нет',
                            style: TextStyle(color: CupertinoColors.systemGrey)),
                      )
                    else
                      ...st.events.take(20).map((e) => Container(
                            decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: CupertinoColors.separator
                                          .resolveFrom(context),
                                      width: 0.6)),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Text(e,
                                style: const TextStyle(fontSize: 13)),
                          )),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: CupertinoButton(
                  color: CupertinoColors.systemRed,
                  onPressed: () => st.clearHistory(),
                  child: const Text('Очистить историю'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// Вкладка «Настройки»
// ====================================================================

class SettingsTab extends StatefulWidget {
  final AppState state;

  const SettingsTab({super.key, required this.state});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late final TextEditingController _host;
  late final TextEditingController _port;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController(text: widget.state.host);
    _port = TextEditingController(text: widget.state.port.toString());
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.state;
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: st,
          builder: (context, _) => ListView(
            children: [
              ScreenHeader('Настройки'),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Демо-режим',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text(
                        'Встроенный генератор данных: приложение работает '
                        'полностью офлайн, без брокера и интернета.',
                        style: TextStyle(
                            fontSize: 13, color: CupertinoColors.systemGrey)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Использовать демо-данные'),
                        CupertinoSwitch(
                          value: st.demoMode,
                          onChanged: (v) => st.setDemoMode(v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MQTT-брокер',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text(
                        'Например, брокер из настольного проекта: адрес компьютера '
                        'в домашней сети, порт 1883. Без пароля (allow_anonymous).',
                        style: TextStyle(
                            fontSize: 13, color: CupertinoColors.systemGrey)),
                    const SizedBox(height: 10),
                    CupertinoTextField(
                      controller: _host,
                      placeholder: '192.168.1.50',
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(CupertinoIcons.globe,
                            size: 18, color: CupertinoColors.systemGrey),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: _port,
                      keyboardType: const TextInputType.numberWithOptions(),
                      placeholder: '1883',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton.filled(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            onPressed: () {
                              final h = _host.text.trim();
                              final p = int.tryParse(_port.text.trim()) ?? 1883;
                              st.setDemoMode(false).then((_) {
                                st.connectMqtt(h, p);
                              });
                            },
                            child: const Text('Подключиться'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 14),
                          onPressed: () {
                            st.disconnectMqtt();
                            st.setDemoMode(true);
                          },
                          child: const Text('Демо'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Статус: ${st.status}',
                        style: const TextStyle(
                            fontSize: 12, color: CupertinoColors.systemGrey)),
                  ],
                ),
              ),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Данные',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                        'Хранение: ${st.storageHint}. Регистрация не нужна, '
                        'интернет не используется в демо-режиме.',
                        style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context))),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
