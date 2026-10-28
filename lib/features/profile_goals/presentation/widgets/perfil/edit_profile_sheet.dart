import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/clock/clock.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/utils/number_formats.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../application/profile_service.dart';

/// Hoja modal rediseñada para editar datos personales con recálculo dinámico de edad.
class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key, required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late BiologicalSex _sex;
  late DateTime _birthDate;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.name);
    _heightCtrl = TextEditingController(
      text: NumberFormats.input(widget.profile.heightCm, maxDigits: 0),
    );
    _weightCtrl = TextEditingController(
      text: NumberFormats.input(widget.profile.targetWeightKg, maxDigits: 1),
    );
    _sex = widget.profile.biologicalSex;
    _birthDate = widget.profile.birthDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double dynamicAge =
        ref.read(clockProvider).now().difference(_birthDate).inDays / 365.25;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(child: Text(
                context.l10n.perfilEditarDatosPersonales,
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: c.text,
                ),
              )),
              IconButton(
                icon: Icon(AppIcons.close, color: c.text2),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            maxLength: AppConstants.maxProfileNameLength,
            decoration: InputDecoration(
              labelText: context.l10n.perfilNombreOAlias,
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<BiologicalSex>(
              segments: <ButtonSegment<BiologicalSex>>[
                ButtonSegment<BiologicalSex>(
                  value: BiologicalSex.male,
                  label: Text(context.l10n.perfilHombre),
                  icon: const Icon(Icons.male_rounded),
                ),
                ButtonSegment<BiologicalSex>(
                  value: BiologicalSex.female,
                  label: Text(context.l10n.perfilMujer),
                  icon: const Icon(Icons.female_rounded),
                ),
              ],
              selected: <BiologicalSex>{_sex},
              onSelectionChanged: (Set<BiologicalSex> set) =>
                  setState(() => _sex = set.first),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: c.isFlat ? c.line2 : c.line),
            ),
            title: Text(
              context.l10n.perfilFechaDeNacimiento,
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              context.l10n.perfilAnosCalculados(_birthDate.day.toString(), _birthDate.month.toString(), _birthDate.year.toString(), dynamicAge.floor().toString()),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: const Icon(Icons.calendar_today_rounded, size: 20),
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                confirmText: context.l10n.commonAccept,
                initialDate: _birthDate,
                firstDate: DateTime(1920),
                lastDate: ref.read(clockProvider).now(),
              );
              if (picked != null) {
                setState(() => _birthDate = picked);
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.perfilAltura,
                    suffixText: 'cm',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: context.l10n.perfilPesoMeta,
                    suffixText: 'kg',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () async {
                final String newName = _nameCtrl.text.trim();
                final double newHeight = double.tryParse(
                      _heightCtrl.text.replaceAll(',', '.'),
                    ) ??
                    widget.profile.heightCm;
                final double newWeight = double.tryParse(
                      _weightCtrl.text.replaceAll(',', '.'),
                    ) ??
                    widget.profile.targetWeightKg;

                if (newName.isNotEmpty) {
                  await ref.read(profileServiceProvider).update(
                        UserProfilesCompanion(
                          name: drift.Value(newName),
                          biologicalSex: drift.Value(_sex),
                          birthDate: drift.Value(_birthDate),
                          heightCm: drift.Value(newHeight),
                          targetWeightKg: drift.Value(newWeight),
                        ),
                      );
                }

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text(
                context.l10n.perfilGuardarCambios,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.commonCancel),
            ),
          ),
        ],
      ),
    );
  }
}
