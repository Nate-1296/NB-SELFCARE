import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../application/food_catalog_service.dart';

/// Selector de ingredientes crudos desde el catálogo local para RecipeBuilderSheet.
class IngredientPickerSheet extends ConsumerStatefulWidget {
  const IngredientPickerSheet({super.key});

  @override
  ConsumerState<IngredientPickerSheet> createState() => _IngredientPickerSheetState();
}

class _IngredientPickerSheetState extends ConsumerState<IngredientPickerSheet> {
  final TextEditingController _ctrl = TextEditingController();
  List<FoodItem> _items = <FoodItem>[];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_search(''));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    final List<FoodItem> res = await ref
        .read(foodCatalogServiceProvider)
        .search(query: q, limit: 30);
    if (mounted) {
      setState(() {
        _items = res;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    // Material (no una caja decorada): los ListTile pintan su fondo y sus
    // ondas sobre él.
    return Material(
      color: c.bg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Flexible(
                  child: Text(
                    context.l10n.foodSeleccionarIngrediente,
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: c.text,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.close, color: c.text2),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.l10n.foodBuscarIngredienteEjPolloArroz,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? Center(
                      child: Text(
                        context.l10n.foodNoSeEncontraronAlimentos,
                        style: TextStyle(color: c.text2),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (BuildContext ctx, int i) {
                        final FoodItem f = _items[i];
                        return ListTile(
                          title: Text(
                            f.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                          ),
                          subtitle: Text(
                            context.l10n.foodKcal100gPCG(
                              NumberFormats.group(f.kcalPer100g),
                              NumberFormats.fixed(f.proteinPer100g, 1),
                              NumberFormats.fixed(f.carbsPer100g, 1),
                              NumberFormats.fixed(f.fatPer100g, 1),
                            ),
                            style: TextStyle(color: c.text2, fontSize: 11),
                          ),
                          trailing: Icon(Icons.add_circle_outline_rounded, color: c.accent),
                          onTap: () => Navigator.of(ctx).pop(f),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
