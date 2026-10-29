import '../../../core/database/app_database.dart';

/// Las bebidas (porción en "ml", como las de Alcohol y tabaco) se muestran en
/// mililitros; en ellas 1 g ≈ 1 ml, así que los totales no cambian.
extension FoodUnits on FoodItem? {
  bool get isMeasuredInMl {
    final String label = (this?.servingLabel ?? '').trim().toLowerCase();
    return label.endsWith(' ml') || label.endsWith('ml');
  }
}
