import 'package:drift/drift.dart';

import '../domain/enums.dart';

/// Persiste un [DbEnum] como su texto estable. Los valores desconocidos (datos
/// importados de versiones antiguas o editados a mano) se leen como [fallback]
/// en lugar de romper el stream.
class DbEnumConverter<T extends DbEnum> extends TypeConverter<T, String> {
  const DbEnumConverter(this.values, this.fallback);

  final List<T> values;
  final T fallback;

  @override
  T fromSql(String fromDb) => enumFromDb(values, fromDb, fallback);

  @override
  String toSql(T value) => value.dbValue;
}

const DbEnumConverter<BiologicalSex> biologicalSexConverter =
    DbEnumConverter<BiologicalSex>(BiologicalSex.values, BiologicalSex.male);

const DbEnumConverter<DietPhase> dietPhaseConverter =
    DbEnumConverter<DietPhase>(DietPhase.values, DietPhase.deficit);

const DbEnumConverter<DietArchetype> dietArchetypeConverter =
    DbEnumConverter<DietArchetype>(DietArchetype.values, DietArchetype.flexible);

const DbEnumConverter<MealType> mealTypeConverter =
    DbEnumConverter<MealType>(MealType.values, MealType.snack);

const DbEnumConverter<WorkoutCategory> workoutCategoryConverter =
    DbEnumConverter<WorkoutCategory>(WorkoutCategory.values, WorkoutCategory.weights);

const DbEnumConverter<RpeIntensity> rpeIntensityConverter =
    DbEnumConverter<RpeIntensity>(RpeIntensity.values, RpeIntensity.moderate);

const DbEnumConverter<MeasurementSource> measurementSourceConverter =
    DbEnumConverter<MeasurementSource>(MeasurementSource.values, MeasurementSource.manual);

const DbEnumConverter<FoodSource> foodSourceConverter =
    DbEnumConverter<FoodSource>(FoodSource.values, FoodSource.userCustom);

const DbEnumConverter<ReminderType> reminderTypeConverter =
    DbEnumConverter<ReminderType>(ReminderType.values, ReminderType.hydration);
