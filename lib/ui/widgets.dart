// widgets.dart -- glassmorphism-примитивы и мелкие элементы в стиле iOS.
import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../models.dart';

/// Стеклянная полупрозрачная карточка с размытием фона.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    final bright = CupertinoTheme.brightnessOf(context);
    final fill = bright == Brightness.dark
        ? const Color(0x66202A38)
        : const Color(0x99FFFFFF);
    final border = bright == Brightness.dark
        ? const Color(0x33FFFFFF)
        : const Color(0x66FFFFFF);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border, width: 0.8),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Статус подключения -- маленькая «пилюля» сверху.
class StatusPill extends StatelessWidget {
  final String status;
  final String? lastError;

  const StatusPill({super.key, required this.status, this.lastError});

  (String, Color) _view() {
    switch (status) {
      case 'demo':
        return ('демо-режим', const Color(0xFF30B0C7));
      case 'online':
        return ('онлайн', const Color(0xFF30D158));
      case 'connecting':
        return ('подключение…', const Color(0xFFFFD60A));
      case 'error':
        return ('ошибка', const Color(0xFFFF453A));
      default:
        return ('офлайн', const Color(0xFF8E8E93));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _view();
    final err = lastError;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (status == 'error' && err != null)
          Text(err,
              style: TextStyle(
                  fontSize: 12, color: CupertinoColors.systemRed.resolveFrom(context))),
      ],
    );
  }
}

/// Крупная числовая пара (температура + влажность).
class BigValue extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const BigValue(
      {super.key,
      required this.value,
      required this.label,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: CupertinoColors.systemBlue),
            const SizedBox(width: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w700, height: 1.0)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context))),
      ],
    );
  }
}

/// Маленькая плитка-индикатор (движение, газ, протечка).
class MiniTile extends StatelessWidget {
  final String title;
  final String value;
  final bool alarm;
  final IconData icon;

  const MiniTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.alarm = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = alarm ? const Color(0xFFFF453A) : CupertinoColors.systemGreen;
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: alarm ? const Color(0xFFFF453A) : null)),
        ],
      ),
    );
  }
}

/// Простой линейный график (CustomPainter, без внешних пакетов).
class LineChart extends StatelessWidget {
  final List<MetricPoint> points;
  final Color color;
  final double height;

  const LineChart(
      {super.key, required this.points, required this.color, this.height = 90});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _ChartPainter(points, color)),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<MetricPoint> points;
  final Color color;

  _ChartPainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      // пустое состояние
      final tp = TextPainter(
        text: const TextSpan(
            text: 'собираем данные…',
            style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2));
      return;
    }

    var lo = points.first.value;
    var hi = points.first.value;
    for (final p in points) {
      if (p.value < lo) lo = p.value;
      if (p.value > hi) hi = p.value;
    }
    if (hi - lo < 0.8) {
      final mid = (hi + lo) / 2;
      lo = mid - 0.4;
      hi = mid + 0.4;
    }
    final pad = (hi - lo) * 0.15;
    lo -= pad;
    hi += pad;

    final t0 = points.first.time.millisecondsSinceEpoch.toDouble();
    final t1 = points.last.time.millisecondsSinceEpoch.toDouble();
    final span = (t1 - t0).abs() < 1 ? 1.0 : t1 - t0;

    Offset xy(MetricPoint p) {
      final x = (p.time.millisecondsSinceEpoch - t0) / span * size.width;
      final y = size.height - ((p.value - lo) / (hi - lo)) * size.height;
      return Offset(x.toDouble(), y.toDouble());
    }

    final path = Path()..moveTo(xy(points.first).dx, xy(points.first).dy);
    for (final p in points.skip(1)) {
      path.lineTo(xy(p).dx, xy(p).dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.35), color.withOpacity(0.02)],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // последняя точка -- кружок
    final last = xy(points.last);
    canvas.drawCircle(last, 3.4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points.length != points.length ||
      (points.isNotEmpty &&
          old.points.isNotEmpty &&
          points.last.time != old.points.last.time);
}
