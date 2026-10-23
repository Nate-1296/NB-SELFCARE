import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/journal_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/local_ai_service.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/theme/theme_controller.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/section_head.dart';
import '../../../shared/widgets/top_bar.dart';

/// Pantalla dedicada al Perfil Vivo del Usuario ("Yo" / "Perfil").
///
/// Consolida identidad biométrica (edad dinámica calculada al vuelo),
/// metas adaptativas, diario reflexivo privado, selector de temas
/// (Samsung Health & NXTPAPER) y portabilidad SQLite total (VACUUM INTO).
class PerfilYoScreen extends ConsumerStatefulWidget {
  const PerfilYoScreen({super.key});

  @override
  ConsumerState<PerfilYoScreen> createState() => _PerfilYoScreenState();
}

class _PerfilYoScreenState extends ConsumerState<PerfilYoScreen> {
  final TextEditingController _journalController = TextEditingController();
  int _selectedMood = 4;
  final int _selectedEnergy = 4;
  final int _selectedStress = 2;
  bool _isSavingJournal = false;

  final List<String> _moodEmojis = const ['😞', '😐', '🙂', '😊', '🤩'];

  @override
  void dispose() {
    _journalController.dispose();
    super.dispose();
  }

  Future<void> _saveJournalEntry() async {
    final text = _journalController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSavingJournal = true);
    await HapticFeedback.lightImpact();

    try {
      final now = DateTime.now();
      final localAi = ref.read(localAiServiceProvider);
      final analysis = await localAi.analyzeJournal(text);

      final companion = JournalEntriesCompanion(
        dateKey: drift.Value(now.dateKey),
        createdAt: drift.Value(now),
        content: drift.Value(text),
        moodScore: drift.Value(_selectedMood),
        energyLevel: drift.Value(_selectedEnergy),
        stressLevel: drift.Value(_selectedStress),
        tagsJson: drift.Value('["${analysis.tags.join('","')}"]'),
      );

      final journalDao = ref.read(journalDaoProvider);
      await journalDao.insertEntry(companion);

      _journalController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Reflexión registrada! Ganaste +10 Monedas Nibi 🪙'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingJournal = false);
      }
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (image == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final ext = p.extension(image.path).isEmpty ? '.jpg' : p.extension(image.path);
      final savedFile = File(p.join(appDir.path, 'profile_avatar$ext'));
      await File(image.path).copy(savedFile.path);

      await ref.read(userProfileDaoProvider).updateProfile(
        UserProfilesCompanion(
          avatarPath: drift.Value(savedFile.path),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Foto de perfil actualizada! 📸')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar la imagen: $e')),
        );
      }
    }
  }

  void _showEditProfileSheet(BuildContext context, UserProfile profile) {
    final nameCtrl = TextEditingController(text: profile.name);
    final heightCtrl = TextEditingController(text: profile.heightCm.toStringAsFixed(0));
    final weightCtrl = TextEditingController(text: profile.targetWeightKg.toStringAsFixed(1));
    String sex = profile.biologicalSex;
    DateTime birthDate = profile.birthDate;

    unawaited(showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.sc.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final c = ctx.sc;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final double dynamicAge = DateTime.now().difference(birthDate).inDays / 365.25;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Editar Datos Personales',
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: c.text,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: c.text2),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        filled: true,
                        fillColor: c.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'male', label: Text('Hombre')),
                              ButtonSegment(value: 'female', label: Text('Mujer')),
                            ],
                            selected: {sex},
                            onSelectionChanged: (set) => setSheetState(() => sex = set.first),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: c.line),
                      ),
                      tileColor: c.bg,
                      title: const Text('Fecha de Nacimiento', style: TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${birthDate.day}/${birthDate.month}/${birthDate.year} (${dynamicAge.floor()} años)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: birthDate,
                          firstDate: DateTime(1930),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setSheetState(() => birthDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: heightCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Altura',
                              suffixText: 'cm',
                              filled: true,
                              fillColor: c.bg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: weightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Peso Meta',
                              suffixText: 'kg',
                              filled: true,
                              fillColor: c.bg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: c.accent,
                          foregroundColor: c.ink,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          final newName = nameCtrl.text.trim();
                          final newHeight = double.tryParse(heightCtrl.text) ?? profile.heightCm;
                          final newWeight = double.tryParse(weightCtrl.text) ?? profile.targetWeightKg;

                          if (newName.isNotEmpty) {
                            await ref.read(userProfileDaoProvider).updateProfile(
                              UserProfilesCompanion(
                                name: drift.Value(newName),
                                biologicalSex: drift.Value(sex),
                                birthDate: drift.Value(birthDate),
                                heightCm: drift.Value(newHeight),
                                targetWeightKg: drift.Value(newWeight),
                              ),
                            );
                          }

                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                        },
                        child: const Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ));
  }

  void _showEditGoalsSheet(BuildContext context, UserProfile profile) {
    final weightController =
        TextEditingController(text: profile.targetWeightKg.toStringAsFixed(1));
    final waterController =
        TextEditingController(text: profile.dailyWaterGoalMl.toString());
    final stepsController =
        TextEditingController(text: profile.dailyStepsGoal.toString());
    final sleepController =
        TextEditingController(text: profile.dailySleepGoalHours.toStringAsFixed(1));

    unawaited(showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.sc.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final c = ctx.sc;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ajustar Metas Personales',
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: c.text,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: c.text2),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Peso Objetivo (kg)',
                  labelStyle: TextStyle(color: c.text2),
                  filled: true,
                  fillColor: c.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: waterController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Meta Diaria de Agua (ml)',
                  labelStyle: TextStyle(color: c.text2),
                  filled: true,
                  fillColor: c.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stepsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Meta Diaria de Pasos',
                  labelStyle: TextStyle(color: c.text2),
                  filled: true,
                  fillColor: c.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sleepController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Meta Diaria de Sueño (horas)',
                  labelStyle: TextStyle(color: c.text2),
                  filled: true,
                  fillColor: c.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.ink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final targetWeight = double.tryParse(weightController.text) ?? profile.targetWeightKg;
                    final water = int.tryParse(waterController.text) ?? profile.dailyWaterGoalMl;
                    final steps = int.tryParse(stepsController.text) ?? profile.dailyStepsGoal;
                    final sleep = double.tryParse(sleepController.text) ?? profile.dailySleepGoalHours;

                    final userProfileDao = ref.read(userProfileDaoProvider);
                    await userProfileDao.updateProfile(
                      UserProfilesCompanion(
                        targetWeightKg: drift.Value(targetWeight),
                        dailyWaterGoalMl: drift.Value(water),
                        dailyStepsGoal: drift.Value(steps),
                        dailySleepGoalHours: drift.Value(sleep),
                      ),
                    );

                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('Guardar Metas', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AsyncValue<UserProfile?> profileAsync = ref.watch(userProfileStreamProvider);
    final String currentThemeKey = ref.watch(themeControllerProvider);
    final journalDao = ref.watch(journalDaoProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            TopBar(
              title: 'Perfil',
              avatarText: profileAsync.value?.name.isNotEmpty == true
                  ? profileAsync.value!.name[0].toUpperCase()
                  : '👤',
              avatarFoto: (profileAsync.value?.avatarPath != null &&
                      File(profileAsync.value!.avatarPath!).existsSync())
                  ? FileImage(File(profileAsync.value!.avatarPath!))
                  : null,
              trailing: IconButton(
                icon: Icon(Icons.share_rounded, color: c.text),
                tooltip: 'Exportar Respaldo SQLite',
                onPressed: () async {
                  await HapticFeedback.selectionClick();
                  final backupService = ref.read(backupServiceProvider);
                  await backupService.shareDatabaseBackup();
                },
              ),
            ),
            Expanded(
              child: profileAsync.when(
                data: (profile) {
                  if (profile == null) {
                    return const Center(child: Text('Perfil no encontrado'));
                  }

                  // 1. Cálculo dinámico de edad según reglas de arquitectura
                  final double ageYears =
                      DateTime.now().difference(profile.birthDate).inDays / 365.25;
                  final String sexLabel =
                      profile.biologicalSex == 'male' ? 'Hombre' : 'Mujer';

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    children: <Widget>[
                      // 1. Tarjeta Hero de Identidad Personal (Samsung Health Style)
                      HealthCard(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _pickProfilePhoto,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: c.accent.withValues(alpha: 0.15),
                                      border: Border.all(color: c.accent, width: 2),
                                      image: profile.avatarPath != null &&
                                              File(profile.avatarPath!).existsSync()
                                          ? DecorationImage(
                                              image: FileImage(File(profile.avatarPath!)),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: profile.avatarPath != null &&
                                            File(profile.avatarPath!).existsSync()
                                        ? null
                                        : Center(
                                            child: Text(
                                              profile.name.isNotEmpty
                                                  ? profile.name[0].toUpperCase()
                                                  : 'U',
                                              style: TextStyle(
                                                fontFamily: ScFonts.display,
                                                fontSize: 26,
                                                fontWeight: FontWeight.bold,
                                                color: c.accent,
                                              ),
                                            ),
                                          ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: c.accent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.camera_alt, size: 14, color: c.ink),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          profile.name,
                                          style: TextStyle(
                                            fontFamily: ScFonts.display,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: c.text,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined, size: 20, color: c.accent),
                                        tooltip: 'Editar Datos',
                                        onPressed: () => _showEditProfileSheet(context, profile),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${ageYears.floor()} años • $sexLabel • ${profile.heightCm.toStringAsFixed(0)} cm',
                                    style: TextStyle(
                                      fontFamily: ScFonts.ui,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: c.text2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.verified_user_rounded,
                                          size: 14, color: c.accent),
                                      const SizedBox(width: 4),
                                      Text(
                                        '100% Offline-First',
                                        style: TextStyle(
                                          fontFamily: ScFonts.ui,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: c.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 2. Metas y TDEE Adaptativo
                      SectionHead(
                        title: 'Metas y Gasto Calórico',
                        actionLabel: 'Ajustar',
                        onAction: () => _showEditGoalsSheet(context, profile),
                      ),
                      const SizedBox(height: 8),
                      HealthCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _MetricGoalItem(
                                    icon: AppIcons.cuerpo,
                                    color: c.accent,
                                    label: 'Peso Objetivo',
                                    value: '${profile.targetWeightKg.toStringAsFixed(1)} kg',
                                    subtext: '${profile.weeklyGoalRateKg >= 0 ? '+' : ''}${profile.weeklyGoalRateKg.toStringAsFixed(1)} kg/sem',
                                  ),
                                ),
                                Container(width: 1, height: 44, color: c.line),
                                Expanded(
                                  child: _MetricGoalItem(
                                    icon: AppIcons.fuego,
                                    color: c.calories,
                                    label: 'TDEE Adaptativo',
                                    value: '${profile.currentAdaptiveTdeeKcal} kcal',
                                    subtext: 'Auto-calibrado (14d)',
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(color: c.line, height: 1),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _MetricGoalItem(
                                    icon: AppIcons.gota,
                                    color: c.water,
                                    label: 'Meta de Agua',
                                    value: '${profile.dailyWaterGoalMl} ml',
                                    subtext: 'Hidratación activa',
                                  ),
                                ),
                                Container(width: 1, height: 44, color: c.line),
                                Expanded(
                                  child: _MetricGoalItem(
                                    icon: AppIcons.pasos,
                                    color: c.steps,
                                    label: 'Meta Pasos',
                                    value: '${profile.dailyStepsGoal}',
                                    subtext: 'Movimiento NEAT',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 3. Aspecto y Pantalla (Modo Dual / TCL NXTPAPER)
                      const SectionHead(
                        title: 'Aspecto y Pantalla',
                        subtitle: 'Material You, OLED y Modos Papel NXTPAPER',
                      ),
                      const SizedBox(height: 8),
                      HealthCard(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        child: Column(
                          children: [
                            for (final themeDef in kScThemes)
                              _ThemeListTile(
                                def: themeDef,
                                isSelected: themeDef.key == currentThemeKey,
                                onSelect: () async {
                                  await HapticFeedback.selectionClick();
                                  await ref
                                      .read(themeControllerProvider.notifier)
                                      .selectTheme(themeDef.key);
                                },
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 4. Diario Personal & Reflexiones de Bienestar
                      const SectionHead(
                        title: 'Diario de Reflexión',
                        subtitle: 'Privado y analizado con IA local determinista',
                      ),
                      const SizedBox(height: 8),
                      HealthCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Selector de Estado de Ánimo
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '¿Cómo te sientes hoy?',
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: c.text,
                                  ),
                                ),
                                Row(
                                  children: [
                                    for (int i = 0; i < _moodEmojis.length; i++)
                                      GestureDetector(
                                        onTap: () => setState(() => _selectedMood = i + 1),
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 3),
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: _selectedMood == (i + 1)
                                                ? c.accent.withValues(alpha: 0.2)
                                                : Colors.transparent,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: _selectedMood == (i + 1) ? c.accent : Colors.transparent,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(
                                            _moodEmojis[i],
                                            style: const TextStyle(fontSize: 18),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _journalController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Escribe un pensamiento, aprendizaje o gratitud...',
                                hintStyle: TextStyle(fontFamily: ScFonts.ui, fontSize: 13, color: c.text3),
                                filled: true,
                                fillColor: c.bg,
                                contentPadding: const EdgeInsets.all(12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: c.line),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: c.line),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: c.accent,
                                  foregroundColor: c.ink,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: _isSavingJournal ? null : _saveJournalEntry,
                                icon: _isSavingJournal
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.send_rounded, size: 16),
                                label: const Text('Guardar (+10 🪙)'),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Lista de Entradas Recientes del Diario
                      StreamBuilder<List<JournalEntry>>(
                        stream: journalDao.watchRecentEntries(limit: 5),
                        builder: (context, snapshot) {
                          final entries = snapshot.data ?? [];
                          if (entries.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final entry in entries)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: HealthCard(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              entry.dateKey,
                                              style: TextStyle(
                                                fontFamily: ScFonts.ui,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: c.text3,
                                              ),
                                            ),
                                            Text(
                                              _moodEmojis[((entry.moodScore ?? 3) - 1).clamp(0, 4)],
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          entry.content,
                                          style: TextStyle(
                                            fontFamily: ScFonts.ui,
                                            fontSize: 13,
                                            color: c.text,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // 5. Hardware y Báscula Xiaomi Mi Scale 2
                      const SectionHead(
                        title: 'Dispositivos y Conectividad',
                        subtitle: 'Lectura BLE directa y Health Connect',
                      ),
                      const SizedBox(height: 8),
                      HealthCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: c.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(AppIcons.bascula, color: c.accent, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Xiaomi Mi Body Composition Scale 2',
                                        style: TextStyle(
                                          fontFamily: ScFonts.ui,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: c.text,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        profile.scaleMacAddress != null
                                            ? 'Vinculada: ${profile.scaleMacAddress}'
                                            : 'Disponible para escanear en pestaña Cuerpo',
                                        style: TextStyle(
                                          fontFamily: ScFonts.ui,
                                          fontSize: 11,
                                          color: c.text2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.bluetooth_connected_rounded,
                                    size: 20, color: c.accent),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 6. Respaldo SQLite y Privacidad Radical
                      const SectionHead(
                        title: 'Portabilidad y Respaldo Local',
                        subtitle: 'Tus datos son 100% tuyos (Cero Nube)',
                      ),
                      const SizedBox(height: 8),
                      HealthCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Copia Atómica SQLite (VACUUM INTO)',
                              style: TextStyle(
                                fontFamily: ScFonts.display,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: c.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Exporta un archivo .sqlite atómico y limpio sin bloquear lecturas activas. Puedes compartirlo o respaldarlo donde desees.',
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 12,
                                color: c.text2,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: c.accent),
                                  foregroundColor: c.accent,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.file_download_outlined, size: 20),
                                label: const Text('Exportar y Compartir .sqlite',
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  await HapticFeedback.selectionClick();
                                  final backupService = ref.read(backupServiceProvider);
                                  await backupService.shareDatabaseBackup();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGoalItem extends StatelessWidget {
  const _MetricGoalItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.subtext,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String subtext;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.text3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: c.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 10,
              color: c.text2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeListTile extends StatelessWidget {
  const _ThemeListTile({
    required this.def,
    required this.isSelected,
    required this.onSelect,
  });

  final ScThemeDef def;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: def.colors.bg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? def.colors.accent : def.colors.line2,
                  width: isSelected ? 2.5 : 1.5,
                ),
              ),
              child: Center(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: def.colors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    def.label,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? c.accent : c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    def.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 11,
                      color: c.text3,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: c.accent, size: 20)
            else
              Icon(Icons.radio_button_unchecked, color: c.text3, size: 18),
          ],
        ),
      ),
    );
  }
}

