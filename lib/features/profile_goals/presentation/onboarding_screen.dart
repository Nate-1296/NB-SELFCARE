import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../shared/widgets/nxtpaper_card.dart';

/// Pantalla de bienvenida y configuración de perfil biométrico inicial.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _heightController = TextEditingController(text: '175');
  final _targetWeightController = TextEditingController(text: '70.0');

  DateTime _birthDate = DateTime.now().subtract(const Duration(days: 365 * 25));
  String _biologicalSex = 'male';
  double _weeklyGoalRateKg = -0.5;
  int _dailyWaterGoalMl = 2500;
  int _dailyStepsGoal = 8000;
  final double _dailySleepGoalHours = 7.5;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose() ;
    _heightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  double get _derivedAge {
    return DateTime.now().difference(_birthDate).inDays / 365.25;
  }

  Future<void> _pickBirthDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Selecciona tu fecha de nacimiento',
      confirmText: 'Aceptar',
      cancelText: 'Cancelar',
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final String currentTheme = ref.read(themeEngineProvider);
      final double heightCm = double.parse(_heightController.text.trim());
      final double targetWeightKg = double.parse(_targetWeightController.text.trim());

      final companion = UserProfilesCompanion(
        name: drift.Value(_nameController.text.trim()),
        birthDate: drift.Value(_birthDate),
        biologicalSex: drift.Value(_biologicalSex),
        heightCm: drift.Value(heightCm),
        targetWeightKg: drift.Value(targetWeightKg),
        weeklyGoalRateKg: drift.Value(_weeklyGoalRateKg),
        dailyWaterGoalMl: drift.Value(_dailyWaterGoalMl),
        dailyStepsGoal: drift.Value(_dailyStepsGoal),
        dailySleepGoalHours: drift.Value(_dailySleepGoalHours),
        themeMode: drift.Value(currentTheme),
        currentAdaptiveTdeeKcal: const drift.Value(2000),
      );

      final dao = ref.read(userProfileDaoProvider);
      await dao.createProfile(companion);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear perfil: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String currentEngine = ref.watch(themeEngineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bienvenido a NB Selfcare'),
        actions: [
          IconButton(
            tooltip: currentEngine == 'nxtpaper_eink'
                ? 'Cambiar a Material You'
                : 'Cambiar a Modo Papel NXTPAPER',
            icon: Icon(
              currentEngine == 'nxtpaper_eink'
                  ? Icons.palette_outlined
                  : Icons.menu_book_outlined,
            ),
            onPressed: () {
              ref.read(themeEngineProvider.notifier).toggle();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            children: [
              // Encabezado
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.spa_rounded,
                      size: 64.0,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      'Tu Santuario de Autocuidado',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      '100% Offline-First · Cero Cuentas · Privacidad Absoluta',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),

              // Selector de Motor Visual
              NxtpaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.display_settings_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          'Motor Visual de Pantalla',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Selecciona según la tecnología de tu dispositivo (optimizado para TCL NXTPAPER).',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12.0),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'material_you',
                          icon: Icon(Icons.palette_outlined),
                          label: Text('Material You'),
                        ),
                        ButtonSegment(
                          value: 'nxtpaper_eink',
                          icon: Icon(Icons.menu_book_outlined),
                          label: Text('Papel E-Ink'),
                        ),
                      ],
                      selected: {currentEngine},
                      onSelectionChanged: (selection) {
                        if (selection.first != currentEngine) {
                          ref.read(themeEngineProvider.notifier).toggle();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),

              // Datos Personales
              NxtpaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          'Perfil Biométrico',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),

                    // Nombre
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '¿Cómo te llamas?',
                        hintText: 'Tu nombre o apodo',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingresa tu nombre';
                        }
                        if (value.trim().length > 60) {
                          return 'Máximo 60 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // Fecha de Nacimiento y Edad al vuelo
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.cake_outlined),
                      title: const Text('Fecha de Nacimiento'),
                      subtitle: Text(
                        '${_birthDate.year}-${_birthDate.month.toString().padLeft(2, '0')}-${_birthDate.day.toString().padLeft(2, '0')} (${_derivedAge.toStringAsFixed(1)} años calculados)',
                      ),
                      trailing: OutlinedButton(
                        onPressed: _pickBirthDate,
                        child: const Text('Cambiar'),
                      ),
                    ),
                    const SizedBox(height: 12.0),

                    // Sexo Biológico (requerido para BIA y Katch-McArdle)
                    Text(
                      'Sexo Biológico (requerido para fórmulas metabólicas BIA)',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6.0),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'male',
                          icon: Icon(Icons.male_rounded),
                          label: Text('Masculino'),
                        ),
                        ButtonSegment(
                          value: 'female',
                          icon: Icon(Icons.female_rounded),
                          label: Text('Femenino'),
                        ),
                      ],
                      selected: {_biologicalSex},
                      onSelectionChanged: (set) {
                        setState(() => _biologicalSex = set.first);
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // Altura (cm)
                    TextFormField(
                      controller: _heightController,
                      decoration: const InputDecoration(
                        labelText: 'Altura (cm)',
                        hintText: 'Ej. 175',
                        prefixIcon: Icon(Icons.height_rounded),
                        suffixText: 'cm',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        final val = double.tryParse(value ?? '');
                        if (val == null || val < 100 || val > 250) {
                          return 'Ingresa una altura válida (100 - 250 cm)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // Peso Objetivo (kg)
                    TextFormField(
                      controller: _targetWeightController,
                      decoration: const InputDecoration(
                        labelText: 'Peso Objetivo (kg)',
                        hintText: 'Ej. 70.0',
                        prefixIcon: Icon(Icons.flag_outlined),
                        suffixText: 'kg',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        final val = double.tryParse(value ?? '');
                        if (val == null || val < 30 || val > 300) {
                          return 'Ingresa un peso objetivo válido (30 - 300 kg)';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),

              // Metas de Hábitos
              NxtpaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.track_changes_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          'Metas Diarias de Autocuidado',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),

                    // Ritmo de cambio semanal
                    Text(
                      'Objetivo semanal: ${_weeklyGoalRateKg == 0.0 ? 'Mantenimiento' : '${_weeklyGoalRateKg > 0 ? '+' : ''}${_weeklyGoalRateKg.toStringAsFixed(2)} kg/semana'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Slider(
                      value: _weeklyGoalRateKg,
                      min: -1.0,
                      max: 0.5,
                      divisions: 6,
                      label: '${_weeklyGoalRateKg.toStringAsFixed(2)} kg',
                      onChanged: (val) => setState(() => _weeklyGoalRateKg = val),
                    ),
                    const SizedBox(height: 8.0),

                    // Meta de Agua
                    Text(
                      'Meta de hidratación: $_dailyWaterGoalMl ml (${(_dailyWaterGoalMl / 250).toStringAsFixed(0)} vasos)',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Slider(
                      value: _dailyWaterGoalMl.toDouble(),
                      min: 1500,
                      max: 4000,
                      divisions: 10,
                      label: '$_dailyWaterGoalMl ml',
                      onChanged: (val) => setState(() => _dailyWaterGoalMl = val.toInt()),
                    ),
                    const SizedBox(height: 8.0),

                    // Meta de Pasos
                    Text(
                      'Meta de pasos (NEAT): $_dailyStepsGoal pasos',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Slider(
                      value: _dailyStepsGoal.toDouble(),
                      min: 4000,
                      max: 16000,
                      divisions: 12,
                      label: '$_dailyStepsGoal',
                      onChanged: (val) => setState(() => _dailyStepsGoal = val.toInt()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),

              // Botón de Inicio
              FilledButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  _isSaving ? 'Guardando en SQLite local...' : 'Comenzar mi Santuario',
                  style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54.0),
                ),
              ),
              const SizedBox(height: 32.0),
            ],
          ),
        ),
      ),
    );
  }
}
