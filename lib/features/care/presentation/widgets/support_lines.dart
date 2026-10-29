import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/platform/device_gateway.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/widgets/sheet.dart';

/// Líneas de apoyo emocional en Colombia. Pulsar abre el marcador con el número
/// escrito: nunca llama por sí solo.
class SupportLines extends ConsumerWidget {
  const SupportLines({super.key});

  static Future<void> show(BuildContext context) => mostrarHojaMenu<void>(
    context,
    builder: (_) => const Padding(
      padding: EdgeInsets.fromLTRB(ScSpace.xl - 4, 0, ScSpace.xl - 4, ScSpace.xl),
      child: SupportLines(),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<({String title, String hint, String number})> lines =
        <({String title, String hint, String number})>[
          (title: l10n.supportLine192, hint: l10n.supportLine192Hint, number: '192'),
          (title: l10n.supportLine106, hint: l10n.supportLine106Hint, number: '106'),
          (title: l10n.supportLine123, hint: l10n.supportLine123Hint, number: '123'),
        ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(l10n.supportTitle, style: context.text.titleLarge),
        const SizedBox(height: ScSpace.xs),
        Text(l10n.supportBody, style: context.type.caption.copyWith(color: c.text2)),
        const SizedBox(height: ScSpace.s),
        for (final ({String title, String hint, String number}) line in lines)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.phone_in_talk_outlined, color: c.isFlat ? c.text : c.accent),
            title: Text(line.title),
            subtitle: Text(line.hint),
            trailing: TextButton(
              onPressed: () => unawaited(ref.read(deviceGatewayProvider).dial(line.number)),
              child: Text(l10n.supportCall),
            ),
          ),
        Text(l10n.supportNote, style: context.type.caption.copyWith(color: c.text3)),
      ],
    );
  }
}
