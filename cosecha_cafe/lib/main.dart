import 'dart:io' show exit;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'datos.dart';
import 'graficas.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  final datos = Datos();
  await datos.cargar();
  runApp(CosechaApp(datos: datos));
}

final fmtPesos = NumberFormat('\$ #,##0', 'es_CO');
final fmtKg = NumberFormat('#,##0.#', 'es_CO');

double? leerNumero(String texto) {
  final limpio = texto.trim().replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(limpio);
}

double? leerKilos(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));

class CosechaApp extends StatelessWidget {
  final Datos datos;
  const CosechaApp({super.key, required this.datos});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cosecha de Café',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      home: PantallaPrincipal(datos: datos),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  final Datos datos;
  const PantallaPrincipal({super.key, required this.datos});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  DateTime lunes = lunesDe(DateTime.now());

  Datos get datos => widget.datos;

  void _cambiarSemana(int semanas) =>
      setState(() => lunes = DateTime(lunes.year, lunes.month, lunes.day + 7 * semanas));

  Future<void> _elegirFecha() async {
    final elegido = await showDatePicker(
      context: context,
      initialDate: lunes,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Elija un día de la semana',
    );
    if (elegido != null) setState(() => lunes = lunesDe(elegido));
  }

  // ---------------- Diálogos ----------------

  Future<void> _dialogoTrabajador({Trabajador? t}) async {
    final nombreCtrl = TextEditingController(text: t?.nombre ?? '');
    final cedulaCtrl = TextEditingController(text: t?.cedula ?? '');
    final formKey = GlobalKey<FormState>();

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t == null ? 'Agregar trabajador' : 'Editar trabajador'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: nombreCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Escriba el nombre' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: cedulaCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Cédula', prefixIcon: Icon(Icons.badge)),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Escriba la cédula';
                if (datos.cedulaExiste(v.trim(), exceptoId: t?.id)) return 'Esa cédula ya existe';
                return null;
              },
            ),
          ]),
        ),
        actions: [
          if (t != null)
            TextButton(
              onPressed: () async {
                final borrar = await _confirmar(
                    '¿Eliminar a ${t.nombre}?', 'Se borrarán también todos sus pesos registrados.');
                if (borrar && ctx.mounted) {
                  datos.eliminarTrabajador(t);
                  Navigator.pop(ctx, false);
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (guardar == true) {
      final nombre = nombreCtrl.text.trim();
      final cedula = cedulaCtrl.text.trim();
      if (t == null) {
        datos.agregarTrabajador(nombre, cedula);
      } else {
        datos.editarTrabajador(t, nombre, cedula);
      }
    }
  }

  Future<void> _dialogoPrecio() async {
    final actual = datos.precioSemana(lunes);
    final ctrl = TextEditingController(text: actual > 0 ? actual.toStringAsFixed(0) : '');
    final precio = await showDialog<double>(
      context: context,
      builder: (ctx) {
        void aceptar() {
          final v = leerNumero(ctrl.text);
          if (v != null && v >= 0) Navigator.pop(ctx, v);
        }

        return AlertDialog(
          title: const Text('Precio por kilo'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Semana: ${_textoSemana()}'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Pesos colombianos por kilo',
                prefixText: '\$ ',
                suffixText: 'COP / kg',
              ),
              onSubmitted: (_) => aceptar(),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: aceptar, child: const Text('Guardar')),
          ],
        );
      },
    );
    if (precio != null) datos.ponerPrecio(lunes, precio);
  }

  Future<void> _dialogoPeso(Trabajador t, DateTime dia) async {
    final actual = datos.peso(t, dia);
    final ctrl = TextEditingController(text: actual == null ? '' : fmtKg.format(actual).replaceAll('.', ''));
    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) {
        void aceptar() => Navigator.pop(ctx, ctrl.text);
        return AlertDialog(
          title: Text(t.nombre),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(toBeginningOfSentenceCase(DateFormat("EEEE d 'de' MMMM", 'es').format(dia))),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: const InputDecoration(labelText: 'Kilos de café cogidos', suffixText: 'kg'),
              onSubmitted: (_) => aceptar(),
            ),
          ]),
          actions: [
            if (actual != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, ''),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Borrar'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: aceptar, child: const Text('Guardar')),
          ],
        );
      },
    );
    if (resultado == null) return;
    datos.ponerPeso(t, dia, resultado.trim().isEmpty ? null : leerKilos(resultado));
  }

  Future<bool> _confirmar(String titulo, String mensaje) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí')),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _salir() async {
    if (!await _confirmar('Salir', '¿Desea salir de la aplicación?')) return;
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('En el navegador cierre la pestaña para salir.')),
        );
      }
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  String _textoSemana() {
    final dom = DateTime(lunes.year, lunes.month, lunes.day + 6);
    final f = DateFormat("d 'de' MMM", 'es');
    return '${f.format(lunes)} al ${f.format(dom)} ${dom.year}';
  }

  // ---------------- Interfaz ----------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: datos,
      builder: (context, _) {
        final esEstaSemana = lunes == lunesDe(DateTime.now());
        final precio = datos.precioSemana(lunes);
        final totalKg = datos.kilosTotalesSemana(lunes);

        return Scaffold(
          appBar: AppBar(
            title: const Text('☕ Cosecha de Café'),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.tonalIcon(
                  onPressed: _salir,
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Salir'),
                  style: FilledButton.styleFrom(foregroundColor: Colors.red.shade800),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // ---- Navegación de semanas ----
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    Row(children: [
                      IconButton.filledTonal(
                        tooltip: 'Semana anterior',
                        onPressed: () => _cambiarSemana(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: _elegirFecha,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(children: [
                              Text(esEstaSemana ? 'Esta semana' : 'Semana',
                                  style: Theme.of(context).textTheme.labelMedium),
                              Text(_textoSemana(),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Semana siguiente',
                        onPressed: () => _cambiarSemana(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ]),
                    Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
                      TextButton.icon(
                        onPressed: () => _cambiarSemana(-1),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Semana anterior'),
                      ),
                      TextButton.icon(
                        onPressed: esEstaSemana ? null : () => setState(() => lunes = lunesDe(DateTime.now())),
                        icon: const Icon(Icons.today),
                        label: const Text('Esta semana'),
                      ),
                      TextButton.icon(
                        onPressed: _elegirFecha,
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Cambiar semana'),
                      ),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 8),

              // ---- Botones principales ----
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                    onPressed: () => _dialogoTrabajador(),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Agregar\ntrabajador', textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: Colors.green.shade700,
                    ),
                    onPressed: _dialogoPrecio,
                    icon: const Icon(Icons.attach_money),
                    label: Text(
                      precio > 0 ? 'Precio por kilo\n${fmtPesos.format(precio)}' : 'Precio por kilo\n(sin definir)',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // ---- Tabla ----
              _titulo('Pesos de la semana', 'Toque una casilla para escribir los kilos'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: datos.trabajadores.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('Todavía no hay trabajadores. Use "Agregar trabajador".')),
                      )
                    : SingleChildScrollView(scrollDirection: Axis.horizontal, child: _tabla(precio)),
              ),
              const SizedBox(height: 8),

              // ---- Resumen ----
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    alignment: WrapAlignment.spaceAround,
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _dato('Kilos de la semana', '${fmtKg.format(totalKg)} kg'),
                      _dato('Precio por kilo', fmtPesos.format(precio)),
                      _dato('Total a pagar', fmtPesos.format(totalKg * precio)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ---- Gráficas ----
              _titulo('Gráfica de todos los trabajadores', 'Kilos cogidos por día'),
              Card(child: GraficaTodos(datos: datos, lunes: lunes)),
              const SizedBox(height: 16),
              if (datos.trabajadores.isNotEmpty) ...[
                _titulo('Gráfica de cada trabajador', 'Kilos cogidos por día'),
                LayoutBuilder(builder: (context, c) {
                  final columnas = c.maxWidth > 900 ? 3 : (c.maxWidth > 600 ? 2 : 1);
                  final ancho = (c.maxWidth - 8 * (columnas - 1)) / columnas;
                  return Wrap(spacing: 8, runSpacing: 8, children: [
                    for (var i = 0; i < datos.trabajadores.length; i++)
                      SizedBox(
                        width: ancho,
                        child: GraficaTrabajador(
                          datos: datos,
                          lunes: lunes,
                          trabajador: datos.trabajadores[i],
                          color: colorDe(i),
                        ),
                      ),
                  ]);
                }),
              ],
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Hecho por Daniel Rojas Arevalo',
                  style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _titulo(String texto, String sub) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(texto, style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold)),
          Text(sub, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );

  Widget _dato(String etiqueta, String valor) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text(etiqueta, style: Theme.of(context).textTheme.labelMedium),
        Text(valor, style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold)),
      ]);

  Widget _tabla(double precio) {
    final dias = diasDeSemana(lunes);
    final hoy = claveDia(DateTime.now());
    const negrita = TextStyle(fontWeight: FontWeight.bold);
    final colorEncabezado = Theme.of(context).colorScheme.primaryContainer;

    return DataTable(
      headingRowColor: WidgetStatePropertyAll(colorEncabezado),
      columnSpacing: 18,
      horizontalMargin: 12,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 56,
      headingRowHeight: 56,
      columns: [
        const DataColumn(label: Text('Nombre', style: negrita)),
        const DataColumn(label: Text('Cédula', style: negrita)),
        for (final d in dias)
          DataColumn(
            numeric: true,
            label: Text(
              '${toBeginningOfSentenceCase(DateFormat.E('es').format(d))}\n${DateFormat('dd/MM').format(d)}',
              textAlign: TextAlign.center,
              style: negrita.copyWith(
                color: claveDia(d) == hoy ? Colors.red.shade800 : null,
              ),
            ),
          ),
        const DataColumn(numeric: true, label: Text('Total\nkg', textAlign: TextAlign.center, style: negrita)),
        const DataColumn(numeric: true, label: Text('A pagar', style: negrita)),
      ],
      rows: [
        for (var i = 0; i < datos.trabajadores.length; i++)
          _filaTrabajador(datos.trabajadores[i], colorDe(i), dias, precio),
        // Fila de totales
        DataRow(
          color: WidgetStatePropertyAll(Theme.of(context).colorScheme.secondaryContainer),
          cells: [
            const DataCell(Text('TOTAL', style: negrita)),
            const DataCell(Text('')),
            for (final d in dias) DataCell(Text(fmtKg.format(datos.kilosDia(d)), style: negrita)),
            DataCell(Text(fmtKg.format(datos.kilosTotalesSemana(lunes)), style: negrita)),
            DataCell(Text(fmtPesos.format(datos.kilosTotalesSemana(lunes) * precio), style: negrita)),
          ],
        ),
      ],
    );
  }

  DataRow _filaTrabajador(Trabajador t, Color color, List<DateTime> dias, double precio) {
    final kg = datos.kilosSemana(t, lunes);
    return DataRow(cells: [
      DataCell(
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(t.nombre),
          const SizedBox(width: 4),
          const Icon(Icons.edit, size: 14, color: Colors.black38),
        ]),
        onTap: () => _dialogoTrabajador(t: t),
      ),
      DataCell(Text(t.cedula)),
      for (final d in dias)
        DataCell(
          Container(
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.centerRight,
            child: Text(
              datos.peso(t, d) == null ? '—' : fmtKg.format(datos.peso(t, d)),
              style: TextStyle(color: datos.peso(t, d) == null ? Colors.black38 : null),
            ),
          ),
          onTap: () => _dialogoPeso(t, d),
        ),
      DataCell(Text(fmtKg.format(kg), style: const TextStyle(fontWeight: FontWeight.bold))),
      DataCell(Text(fmtPesos.format(kg * precio),
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800))),
    ]);
  }
}
