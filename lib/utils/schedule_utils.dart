import '../globals.dart';

bool isZimski(DateTime date) {
  // Objedinjena logika sa globals.dart da bi sve bilo sinhronizovano
  return isWinterDate(date);
}
