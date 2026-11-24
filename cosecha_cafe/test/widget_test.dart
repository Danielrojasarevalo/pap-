import 'package:cosecha_cafe/datos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('kilos y precio de la semana', () async {
    SharedPreferences.setMockInitialValues({});
    final datos = Datos();
    final lunes = lunesDe(DateTime(2026, 11, 25)); // miércoles -> lunes 23
    expect(lunes, DateTime(2026, 11, 23));

    datos.agregarTrabajador('Pedro', '123');
    final t = datos.trabajadores.first;
    datos.ponerPeso(t, DateTime(2026, 11, 23), 40);
    datos.ponerPeso(t, DateTime(2026, 11, 24), 35.5);
    datos.ponerPeso(t, DateTime(2026, 11, 30), 99); // otra semana
    datos.ponerPrecio(lunes, 1200);

    expect(datos.kilosSemana(t, lunes), 75.5);
    expect(datos.precioSemana(lunes), 1200);
    // La semana siguiente hereda el último precio
    expect(datos.precioSemana(DateTime(2026, 11, 30)), 1200);
  });
}
