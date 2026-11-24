import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'datos.dart';

const coloresTrabajadores = [
  Color(0xFF2E7D32),
  Color(0xFF1565C0),
  Color(0xFFC62828),
  Color(0xFFEF6C00),
  Color(0xFF6A1B9A),
  Color(0xFF00838F),
  Color(0xFF795548),
  Color(0xFFAD1457),
  Color(0xFF558B2F),
  Color(0xFF283593),
];

Color colorDe(int i) => coloresTrabajadores[i % coloresTrabajadores.length];

final _fmtKg = NumberFormat('#,##0.#', 'es_CO');

double _techo(double max) {
  if (max <= 0) return 10;
  final paso = max <= 20 ? 5.0 : (max <= 100 ? 20.0 : 50.0);
  return (max * 1.15 / paso).ceil() * paso;
}

FlTitlesData _titulos(List<DateTime> dias, double maxY) {
  final intervalo = maxY / 5;
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      axisNameWidget: const Text('kg', style: TextStyle(fontSize: 12)),
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        interval: intervalo,
        getTitlesWidget: (v, meta) => SideTitleWidget(
          meta: meta,
          child: Text(_fmtKg.format(v), style: const TextStyle(fontSize: 11)),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 42,
        interval: 1,
        getTitlesWidget: (v, meta) {
          final i = v.round();
          if (i < 0 || i > 6 || v != i) return const SizedBox.shrink();
          final d = dias[i];
          return SideTitleWidget(
            meta: meta,
            child: Text(
              '${DateFormat.E('es').format(d)}\n${d.day}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          );
        },
      ),
    ),
  );
}

/// Gráfica con todos los trabajadores juntos: una línea por trabajador.
class GraficaTodos extends StatelessWidget {
  final Datos datos;
  final DateTime lunes;
  const GraficaTodos({super.key, required this.datos, required this.lunes});

  @override
  Widget build(BuildContext context) {
    final dias = diasDeSemana(lunes);
    final ts = datos.trabajadores;
    if (ts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Agregue trabajadores para ver la gráfica.')),
      );
    }
    var maxKg = 0.0;
    for (final t in ts) {
      for (final d in dias) {
        maxKg = max(maxKg, datos.peso(t, d) ?? 0);
      }
    }
    final maxY = _techo(maxKg);

    return Column(
      children: [
        SizedBox(
          height: 280,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 16, 4),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxY,
                titlesData: _titulos(dias, maxY),
                gridData: FlGridData(horizontalInterval: maxY / 5, verticalInterval: 1),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.black26)),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.white,
                    tooltipBorder: const BorderSide(color: Colors.black26),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              '${ts[s.barIndex].nombre}: ${_fmtKg.format(s.y)} kg',
                              TextStyle(color: colorDe(s.barIndex), fontWeight: FontWeight.bold, fontSize: 12),
                            ))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  for (var i = 0; i < ts.length; i++)
                    LineChartBarData(
                      spots: [
                        for (var x = 0; x < 7; x++) FlSpot(x.toDouble(), datos.peso(ts[i], dias[x]) ?? 0),
                      ],
                      color: colorDe(i),
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                ],
              ),
            ),
          ),
        ),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < ts.length; i++)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 14, height: 14, color: colorDe(i)),
                const SizedBox(width: 6),
                Text(ts[i].nombre),
              ]),
          ],
        ),
      ],
    );
  }
}

/// Gráfica de barras de un solo trabajador.
class GraficaTrabajador extends StatelessWidget {
  final Datos datos;
  final DateTime lunes;
  final Trabajador trabajador;
  final Color color;
  const GraficaTrabajador({
    super.key,
    required this.datos,
    required this.lunes,
    required this.trabajador,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dias = diasDeSemana(lunes);
    final kilos = [for (final d in dias) datos.peso(trabajador, d) ?? 0];
    final maxY = _techo(kilos.reduce(max));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text(
                '${trabajador.nombre} · ${_fmtKg.format(datos.kilosSemana(trabajador, lunes))} kg en la semana',
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: maxY,
                  titlesData: _titulos(dias, maxY),
                  gridData: FlGridData(drawVerticalLine: false, horizontalInterval: maxY / 5),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.black26)),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.white,
                      tooltipBorder: const BorderSide(color: Colors.black26),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (g, _, rod, _) => BarTooltipItem(
                        '${_fmtKg.format(rod.toY)} kg',
                        TextStyle(color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var x = 0; x < 7; x++)
                      BarChartGroupData(x: x, barRods: [
                        BarChartRodData(
                          toY: kilos[x],
                          color: color,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
