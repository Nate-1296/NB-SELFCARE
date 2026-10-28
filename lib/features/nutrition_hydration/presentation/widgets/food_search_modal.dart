import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/services/open_food_facts_service.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/chip_pill.dart';
import '../../application/food_catalog_service.dart';
import '../../application/food_logging_service.dart';
import 'barcode_scanner_sheet.dart';
import 'custom_food_sheet.dart';
import 'food_detail_sheet.dart';
import 'food_search_parts.dart';
import 'meal_slot_selector.dart';

/// Subpágina de búsqueda instantánea FTS5 con registro rápido en 1 toque (+ porción base)
/// o apertura de detalle completo al tocar el alimento.
class FoodSearchModal extends ConsumerStatefulWidget {
  const FoodSearchModal({super.key, required this.initialMealType, required this.targetDateKey});

  final MealType initialMealType;
  final String targetDateKey;

  @override
  ConsumerState<FoodSearchModal> createState() => _FoodSearchModalState();
}

enum _CatalogFilter { all, favorites, custom }

class _FoodSearchModalState extends ConsumerState<FoodSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  late MealType _activeMealType;
  List<FoodItem> _results = <FoodItem>[];
  bool _isLoading = true;
  _CatalogFilter _filter = _CatalogFilter.all;
  String? _quickAddedNotice;
  Timer? _noticeTimer;
  bool _isSearchingOff = false;

  @override
  void initState() {
    super.initState();
    _activeMealType = widget.initialMealType;
    unawaited(_performSearch(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _noticeTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 90), () {
      unawaited(_performSearch(value));
    });
  }

  Future<void> _performSearch([String? rawQuery]) async {
    if (!mounted) return;
    if (!_isLoading) {
      setState(() => _isLoading = true);
    }

    try {
      final String q = rawQuery ?? _searchController.text;
      final List<FoodItem> items = await ref
          .read(foodCatalogServiceProvider)
          .search(
            query: q,
            onlyFavorites: _filter == _CatalogFilter.favorites,
            onlyCustom: _filter == _CatalogFilter.custom,
            limit: 45,
          );
      if (!mounted) return;
      setState(() {
        _results = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchOpenFoodFacts() async {
    final String q = _searchController.text.trim();
    if (q.isEmpty || _isSearchingOff) return;

    setState(() => _isSearchingOff = true);
    unawaited(HapticFeedback.lightImpact());

    try {
      final List<FoodItem> offItems = await ref
          .read(openFoodFactsServiceProvider)
          .searchProducts(q);
      if (!mounted) return;

      if (offItems.isNotEmpty) {
        final Set<int> existingIds = _results.map((FoodItem e) => e.id).toSet();
        final List<FoodItem> combined = <FoodItem>[..._results];
        for (final FoodItem item in offItems) {
          if (!existingIds.contains(item.id)) {
            combined.add(item);
            existingIds.add(item.id);
          }
        }
        setState(() {
          _results = combined;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.foodSeEncontraronEImportaronProductos(offItems.length.toString()),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.foodNoSeHallaronResultadosEn)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.foodErrorAlConsultarOpenFood((e).toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingOff = false);
      }
    }
  }

  Future<void> _toggleFavorite(FoodItem food) async {
    unawaited(HapticFeedback.selectionClick());
    await ref.read(foodCatalogServiceProvider).setFavorite(food, favorite: !food.isFavorite);
    await _performSearch();
  }

  Future<void> _quickAddDefaultServing(FoodItem food) async {
    unawaited(HapticFeedback.mediumImpact());
    final double grams = food.defaultServingGrams > 0 ? food.defaultServingGrams : 100.0;

    await ref
        .read(foodLoggingServiceProvider)
        .logPortion(
          food: food,
          grams: grams,
          mealType: _activeMealType,
          dateKey: widget.targetDateKey,
        );

    if (!mounted) return;
    final MealSlotMeta slot = MealSlotMeta.of(_activeMealType);
    _noticeTimer?.cancel();
    setState(() {
      _quickAddedNotice = context.l10n.foodAnadidoGEn(
        food.name.toString(),
        NumberFormats.group(grams),
        slot.title(context.l10n).toString(),
      );
    });
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _quickAddedNotice = null);
      }
    });
  }

  Future<void> _openFoodDetail(FoodItem food) async {
    final bool? logged = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodDetailSheet(
        food: food,
        initialMealType: _activeMealType,
        targetDateKey: widget.targetDateKey,
      ),
    );

    if (logged == true && mounted) {
      Navigator.of(context).pop(true);
    } else if (mounted) {
      await _performSearch();
    }
  }

  Future<void> _openCustomFoodCreator([String? initialName]) async {
    final FoodItem? created = await showModalBottomSheet<FoodItem>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomFoodSheet(initialName: initialName),
    );

    if (created != null && mounted) {
      await _performSearch();
      if (mounted) {
        await _openFoodDetail(created);
      }
    }
  }

  Future<void> _openBarcodeScanner() async {
    Navigator.of(context).pop();
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BarcodeScannerSheet(
        initialMealType: _activeMealType,
        targetDateKey: widget.targetDateKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Container(
      height: MediaQuery.of(context).size.height * 0.91,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: c.isFlat ? Border(top: BorderSide(color: c.line2, width: 1.5)) : null,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: c.line2, borderRadius: BorderRadius.circular(2)),
            ),

            // 1. Encabezado limpio
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.l10n.foodAnadirAlimento,
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.foodTocaParaPorcionRapidaO,
                          softWrap: true,
                          style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12, color: c.text2),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.foodCerrarBuscador,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(AppIcons.close, color: c.text2),
                  ),
                ],
              ),
            ),

            // 2. Selector 2×2 compacto de comida destino
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: MealSlotSelectorGrid(
                selectedMealType: _activeMealType,
                compact: true,
                onSelected: (MealType nextMeal) {
                  setState(() => _activeMealType = nextMeal);
                },
              ),
            ),

            // Aviso en línea de adición rápida (visible sobre el modal)
            if (_quickAddedNotice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.isFlat ? c.bg3 : c.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: c.isFlat ? c.line2 : c.success,
                      width: c.isFlat ? 1.4 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(AppIcons.check, size: 17, color: c.isFlat ? c.text : c.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _quickAddedNotice!,
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        child: Text(context.l10n.foodListo),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // 3. Barra de búsqueda instantánea + botón EAN-13
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: _onQueryChanged,
                      style: TextStyle(fontFamily: ScFonts.ui, fontSize: 14.5, color: c.text),
                      decoration: InputDecoration(
                        hintText: context.l10n.foodBuscarIngredientePlatoOMarca,
                        prefixIcon: Icon(AppIcons.search, color: c.text2),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                tooltip: context.l10n.foodLimpiarTexto,
                                icon: Icon(AppIcons.close, size: 18, color: c.text3),
                                onPressed: () {
                                  _searchController.clear();
                                  _onQueryChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: c.bg2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: c.isFlat ? c.line2 : c.line,
                            width: c.isFlat ? 1.5 : 1.0,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: c.isFlat ? c.line2 : c.line,
                            width: c.isFlat ? 1.5 : 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: c.bg2,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _openBarcodeScanner,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: c.isFlat ? c.line2 : c.line,
                            width: c.isFlat ? 1.5 : 1.0,
                          ),
                        ),
                        child: Icon(AppIcons.barcode, color: c.accent),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 4. Píldoras de filtro + acceso a creación propia
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: <Widget>[
                  ChipPill(
                    label: context.l10n.foodTodos,
                    active: _filter == _CatalogFilter.all,
                    onTap: () {
                      setState(() => _filter = _CatalogFilter.all);
                      unawaited(_performSearch());
                    },
                  ),
                  const SizedBox(width: 8),
                  ChipPill(
                    label: context.l10n.foodFavoritos,
                    icon: AppIcons.starFilled,
                    iconColor: c.carbs,
                    active: _filter == _CatalogFilter.favorites,
                    onTap: () {
                      setState(() => _filter = _CatalogFilter.favorites);
                      unawaited(_performSearch());
                    },
                  ),
                  const SizedBox(width: 8),
                  ChipPill(
                    label: context.l10n.foodMisCreados,
                    icon: Icons.soup_kitchen_outlined,
                    active: _filter == _CatalogFilter.custom,
                    onTap: () {
                      setState(() => _filter = _CatalogFilter.custom);
                      unawaited(_performSearch());
                    },
                  ),
                  const SizedBox(width: 8),
                  ChipPill(
                    label: context.l10n.foodCrearNuevo,
                    icon: AppIcons.add,
                    iconColor: c.accent,
                    onTap: () => unawaited(_openCustomFoodCreator(_searchController.text.trim())),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 5. Lista de resultados sin truncamiento (sin spinner infinito para E-Ink)
            Expanded(
              child: (_isLoading && _results.isEmpty)
                  ? Center(
                      child: Text(
                        context.l10n.foodConsultandoCatalogoLocal,
                        style: TextStyle(fontFamily: ScFonts.ui, fontSize: 13.5, color: c.text2),
                      ),
                    )
                  : _results.isEmpty
                  ? EmptySearchState(
                      query: _searchController.text.trim(),
                      isSearchingOff: _isSearchingOff,
                      onSearchOff: _searchOpenFoodFacts,
                      onCreateCustom: () =>
                          unawaited(_openCustomFoodCreator(_searchController.text.trim())),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                      itemCount: _searchController.text.trim().isNotEmpty
                          ? _results.length + 1
                          : _results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        if (index == _results.length) {
                          return SearchOpenFoodFactsTile(
                            query: _searchController.text.trim(),
                            isSearching: _isSearchingOff,
                            onSearch: _searchOpenFoodFacts,
                          );
                        }
                        final FoodItem item = _results[index];
                        return FoodSearchItemCard(
                          food: item,
                          onTapDetail: () => _openFoodDetail(item),
                          onQuickAdd: () => _quickAddDefaultServing(item),
                          onToggleFavorite: () => _toggleFavorite(item),
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
