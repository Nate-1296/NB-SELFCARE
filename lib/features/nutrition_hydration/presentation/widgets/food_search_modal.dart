import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/food_dao.dart';
import '../../../../core/database/daos/pet_dao.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/chip_pill.dart';
import 'barcode_scanner_sheet.dart';
import 'custom_food_sheet.dart';
import 'food_detail_sheet.dart';
import 'meal_slot_selector.dart';

/// Subpágina de búsqueda instantánea FTS5 con registro rápido en 1 toque (+ porción base)
/// o apertura de detalle completo al tocar el alimento.
class FoodSearchModal extends ConsumerStatefulWidget {
  const FoodSearchModal({
    super.key,
    required this.initialMealType,
    required this.targetDateKey,
  });

  final String initialMealType;
  final String targetDateKey;

  @override
  ConsumerState<FoodSearchModal> createState() => _FoodSearchModalState();
}

enum _CatalogFilter { all, favorites, custom }

class _FoodSearchModalState extends ConsumerState<FoodSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  late String _activeMealType;
  List<FoodItem> _results = <FoodItem>[];
  bool _isLoading = true;
  _CatalogFilter _filter = _CatalogFilter.all;
  String? _quickAddedNotice;
  Timer? _noticeTimer;

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
      final FoodDao foodDao = ref.read(foodDaoProvider);
      final String q = rawQuery ?? _searchController.text;
      final List<FoodItem> items = await foodDao.filterCatalog(
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

  Future<void> _toggleFavorite(FoodItem food) async {
    unawaited(HapticFeedback.selectionClick());
    await ref.read(foodDaoProvider).toggleFavorite(food.id, !food.isFavorite);
    await _performSearch();
  }

  Future<void> _quickAddDefaultServing(FoodItem food) async {
    unawaited(HapticFeedback.mediumImpact());
    final double grams =
        food.defaultServingGrams > 0 ? food.defaultServingGrams : 100.0;
    final FoodDao foodDao = ref.read(foodDaoProvider);
    final PetDao petDao = ref.read(petDaoProvider);

    await foodDao.logFoodItemPortion(
      food: food,
      grams: grams,
      dateKey: widget.targetDateKey,
      mealType: _activeMealType,
    );

    await petDao.grantDailyReward(
      dateKey: widget.targetDateKey,
      actionType: 'meal_log_$_activeMealType',
      baseAmount: AppConstants.coinsMealLog,
    );

    if (!mounted) return;
    final MealSlotMeta slot = MealSlotMeta.of(_activeMealType);
    _noticeTimer?.cancel();
    setState(() {
      _quickAddedNotice =
          'Añadido: ${food.name} (${grams.round()} g) en ${slot.title}';
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
        border: c.isFlat
            ? Border(top: BorderSide(color: c.line2, width: 1.5))
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.line2,
                borderRadius: BorderRadius.circular(2),
              ),
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
                          'Añadir alimento',
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Toca + para porción rápida o abre el alimento para ajustar gramos',
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 12,
                            color: c.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar buscador',
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
                onSelected: (String nextMeal) {
                  setState(() => _activeMealType = nextMeal);
                },
              ),
            ),

            // Aviso en línea de adición rápida (visible sobre el modal)
            if (_quickAddedNotice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.isFlat
                        ? c.bg3
                        : c.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: c.isFlat ? c.line2 : c.success,
                      width: c.isFlat ? 1.4 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        AppIcons.check,
                        size: 17,
                        color: c.isFlat ? c.text : c.success,
                      ),
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
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Listo'),
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
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 14.5,
                        color: c.text,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar ingrediente, plato o marca...',
                        prefixIcon: Icon(AppIcons.search, color: c.text2),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Limpiar texto',
                                icon: Icon(
                                  AppIcons.close,
                                  size: 18,
                                  color: c.text3,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _onQueryChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: c.bg2,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
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
                    label: 'Todos',
                    active: _filter == _CatalogFilter.all,
                    onTap: () {
                      setState(() => _filter = _CatalogFilter.all);
                      unawaited(_performSearch());
                    },
                  ),
                  const SizedBox(width: 8),
                  ChipPill(
                    label: 'Favoritos',
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
                    label: 'Mis creados',
                    icon: Icons.soup_kitchen_outlined,
                    active: _filter == _CatalogFilter.custom,
                    onTap: () {
                      setState(() => _filter = _CatalogFilter.custom);
                      unawaited(_performSearch());
                    },
                  ),
                  const SizedBox(width: 8),
                  ChipPill(
                    label: 'Crear nuevo',
                    icon: AppIcons.add,
                    iconColor: c.accent,
                    onTap: () => unawaited(
                      _openCustomFoodCreator(_searchController.text.trim()),
                    ),
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
                        'Consultando catálogo local...',
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 13.5,
                          color: c.text2,
                        ),
                      ),
                    )
                  : _results.isEmpty
                      ? _EmptySearchState(
                          query: _searchController.text.trim(),
                          onCreateCustom: () => unawaited(
                            _openCustomFoodCreator(
                              _searchController.text.trim(),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                          itemCount: _results.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (BuildContext context, int index) {
                            final FoodItem item = _results[index];
                            return _FoodSearchItemCard(
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

class _FoodSearchItemCard extends StatelessWidget {
  const _FoodSearchItemCard({
    required this.food,
    required this.onTapDetail,
    required this.onQuickAdd,
    required this.onToggleFavorite,
  });

  final FoodItem food;
  final VoidCallback onTapDetail;
  final VoidCallback onQuickAdd;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double servingG =
        food.defaultServingGrams > 0 ? food.defaultServingGrams : 100.0;
    final double ratio = servingG / 100.0;
    final int servingKcal = (food.kcalPer100g * ratio).round();
    final double p = food.proteinPer100g * ratio;
    final double carbs = food.carbsPer100g * ratio;
    final double fat = food.fatPer100g * ratio;

    return Material(
      color: c.bg2,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTapDetail,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: c.isFlat ? c.line2 : c.line,
              width: c.isFlat ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      food.name,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                        height: 1.2,
                      ),
                    ),
                    if ((food.brand != null && food.brand!.trim().isNotEmpty) ||
                        (food.nutriScore != null &&
                            food.nutriScore!.trim().isNotEmpty)) ...<Widget>[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          if (food.brand != null &&
                              food.brand!.trim().isNotEmpty)
                            Text(
                              food.brand!.trim(),
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: c.text2,
                              ),
                            ),
                          if (food.nutriScore != null &&
                              food.nutriScore!.trim().isNotEmpty)
                            NutriScoreBadge(grade: food.nutriScore!),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${servingG.round()} g · $servingKcal kcal  •  '
                      'P ${p.toStringAsFixed(0)}g · '
                      'C ${carbs.toStringAsFixed(0)}g · '
                      'G ${fat.toStringAsFixed(0)}g',
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: food.isFavorite
                    ? 'Quitar de favoritos'
                    : 'Marcar como favorito',
                visualDensity: VisualDensity.compact,
                onPressed: onToggleFavorite,
                icon: Icon(
                  food.isFavorite ? AppIcons.starFilled : AppIcons.star,
                  size: 20,
                  color: food.isFavorite ? c.carbs : c.text3,
                ),
              ),
              const SizedBox(width: 2),
              Material(
                color: c.isFlat ? c.bg3 : c.accent.withValues(alpha: 0.16),
                shape: CircleBorder(
                  side: BorderSide(
                    color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.5),
                    width: c.isFlat ? 1.4 : 1.0,
                  ),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onQuickAdd,
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(
                      AppIcons.add,
                      size: 20,
                      color: c.isFlat ? c.text : c.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({
    required this.query,
    required this.onCreateCustom,
  });

  final String query;
  final VoidCallback onCreateCustom;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.restaurant_menu_rounded, size: 42, color: c.text3),
            const SizedBox(height: 12),
            Text(
              query.isEmpty
                  ? 'Aún no hay alimentos en este filtro'
                  : 'No encontramos "$query" en tu catálogo',
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Puedes crearlo en segundos y quedará disponible offline para siempre.',
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 13,
                color: c.text2,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreateCustom,
              icon: const Icon(AppIcons.add),
              label: const Text('Crear alimento propio'),
            ),
          ],
        ),
      ),
    );
  }
}
