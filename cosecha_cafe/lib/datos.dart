import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un trabajador recolector de café.
class Trabajador {
  final String id;
  String nombre;
  String cedula;

  Trabajador({required this.id, required this.nombre, required this.cedula});

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre, 'cedula': cedula};

  factory Trabajador.fromJson(Map<String, dynamic> j) =>
      Trabajador(id: j['id'], nombre: j['nombre'], cedula: j['cedula']);
}

/// Lunes de la semana a la que pertenece [d] (sin hora).
DateTime lunesDe(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Los 7 días (lunes a domingo) de la semana que empieza en [lunes].
List<DateTime> diasDeSemana(DateTime lunes) =>
    List.generate(7, (i) => DateTime(lunes.year, lunes.month, lunes.day + i));

String claveDia(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Guarda todos los datos de la app en el teléfono (shared_preferences).
class Datos extends ChangeNotifier {
  static const _clave = 'cosecha_cafe_v1';

  final List<Trabajador> trabajadores = [];

  /// Kilos por trabajador y día. Clave: "idTrabajador|yyyy-MM-dd".
  final Map<String, double> _pesos = {};

  /// Precio por kilo (COP) de cada semana. Clave: lunes "yyyy-MM-dd".
  final Map<String, double> _precios = {};

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final texto = prefs.getString(_clave);
    if (texto == null) return;
    final j = jsonDecode(texto) as Map<String, dynamic>;
    trabajadores
      ..clear()
      ..addAll((j['trabajadores'] as List).map((e) => Trabajador.fromJson(e)));
    _pesos
      ..clear()
      ..addAll((j['pesos'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())));
    _precios
      ..clear()
      ..addAll((j['precios'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())));
    notifyListeners();
  }

  Future<void> _guardar() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _clave,
      jsonEncode({
        'trabajadores': trabajadores.map((t) => t.toJson()).toList(),
        'pesos': _pesos,
        'precios': _precios,
      }),
    );
  }

  // ---------- Trabajadores ----------

  bool cedulaExiste(String cedula, {String? exceptoId}) =>
      trabajadores.any((t) => t.cedula == cedula && t.id != exceptoId);

  void agregarTrabajador(String nombre, String cedula) {
    trabajadores.add(Trabajador(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nombre: nombre,
      cedula: cedula,
    ));
    _guardar();
  }

  void editarTrabajador(Trabajador t, String nombre, String cedula) {
    t.nombre = nombre;
    t.cedula = cedula;
    _guardar();
  }

  void eliminarTrabajador(Trabajador t) {
    trabajadores.remove(t);
    _pesos.removeWhere((k, _) => k.startsWith('${t.id}|'));
    _guardar();
  }

  // ---------- Pesos ----------

  double? peso(Trabajador t, DateTime dia) => _pesos['${t.id}|${claveDia(dia)}'];

  void ponerPeso(Trabajador t, DateTime dia, double? kg) {
    final k = '${t.id}|${claveDia(dia)}';
    if (kg == null || kg <= 0) {
      _pesos.remove(k);
    } else {
      _pesos[k] = kg;
    }
    _guardar();
  }

  double kilosSemana(Trabajador t, DateTime lunes) =>
      diasDeSemana(lunes).fold(0.0, (s, d) => s + (peso(t, d) ?? 0));

  double kilosDia(DateTime dia) =>
      trabajadores.fold(0.0, (s, t) => s + (peso(t, dia) ?? 0));

  double kilosTotalesSemana(DateTime lunes) =>
      trabajadores.fold(0.0, (s, t) => s + kilosSemana(t, lunes));

  // ---------- Precio por kilo ----------

  /// Precio de la semana. Si esa semana no tiene precio propio,
  /// usa el último precio definido en una semana anterior.
  double precioSemana(DateTime lunes) {
    final clave = claveDia(lunes);
    if (_precios.containsKey(clave)) return _precios[clave]!;
    final anteriores = _precios.keys.where((k) => k.compareTo(clave) < 0).toList()..sort();
    return anteriores.isEmpty ? 0 : _precios[anteriores.last]!;
  }

  void ponerPrecio(DateTime lunes, double precio) {
    _precios[claveDia(lunes)] = precio;
    _guardar();
  }
}
