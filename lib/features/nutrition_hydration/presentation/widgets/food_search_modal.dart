import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/food_dao.dart';
import '../../../../core/services/open_food_facts_service.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import 'barcode_scanner_sheet.dart';
import 'food_detail_sheet.dart';

/// Buscador de alimentos estilo MyFitnessPal / Samsung Health.
///
/// Permite buscar por texto en la base local (FTS5 USDA) y Open Food Facts,
/// consultar detalles por alimento y abrir el escáner de código de barras.
class FoodSearchModal extends ConsumerStatefulWidget {
  const FoodSearchModal({
    super.key,
    required this.dateKey,
    this.mealType = 'lunch',
  });

  final String dateKey;
  final String mealType;

  static Future<bool?> show({
    required BuildContext context,
    required String dateKey,
    String mealType = 'lunch',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodSearchModal(dateKey: dateKey, mealType: mealType),
    );
  }

  @override
  ConsumerState<FoodSearchModal> createState() => _FoodSearchModalState();
}

class _FoodSearchModalState extends ConsumerState<FoodSearchModal> {
  final TextEditingController _queryController = TextEditingController();
  Timer? _debounceTimer;

  List<FoodItem> _results = [];
  bool _isLoading = false;
  String _searchedQuery = '';

  @override
  void initState() {
    super.initState();
    // Carga inicial con alimentos populares frecuentes
    unawaited(_searchFoods(''));
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_searchFoods(query.trim()));
    });
  }

  Future<void> _searchFoods(String query) async {
    setState(() {
      _isLoading = true;
      _searchedQuery = query;
    });

    final foodDao = ref.read(foodDaoProvider);
    final off = ref.read(openFoodFactsServiceProvider);

    // 1. Búsqueda local FTS5
    final List<FoodItem> localResults = await foodDao.searchFood(query, limit: 30);

    if (mounted) {
      setState(() {
        _results = localResults;
      });
    }

    // 2. Si hay consulta en línea y los resultados locales son limitados
    if (query.length >= 3) {
      try {
        final onlineResults = await off.searchOnlineFoods(query, pageSize: 12);
        if (mounted && _searchedQuery == query) {
          final Set<int> existingIds = _results.map((e) => e.id).toSet();
          final List<FoodItem> merged = List.of(_results);
          for (final item in onlineResults) {
            if (!existingIds.contains(item.id)) {
              merged.add(item);
            }
          }
          setState(() {
            _results = merged;
          });
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Map<String, String> mealNames = {
      'breakfast': 'Desayuno',
      'lunch': 'Almuerzo',
      'dinner': 'Cena',
      'snack': 'Snack',
    };

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: c.isFlat ? c.line2 : c.line, width: c.isFlat ? 1.5 : 1.0),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // Barra de arrastre
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.text3.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Título y botón cerrar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Buscar Alimento',
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Añadiendo a ${mealNames[widget.mealType] ?? "Comida"}',
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 13,
                      color: c.text2,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Campo de búsqueda + Botón de Escáner
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Ej. Manzana, avena, pechuga...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _queryController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _queryController.clear();
                              unawaited(_searchFoods(''));
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: _onQueryChanged,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.qr_code_scanner_rounded),
                tooltip: 'Escanear código de barras',
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(BarcodeScannerSheet.show(
                    context: context,
                    dateKey: widget.dateKey,
                    mealType: widget.mealType,
                  ));
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Indicador de Carga
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: LinearProgressIndicator(),
            ),

          // Lista de Resultados
          Expanded(
            child: _results.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: c.text3),
                        const SizedBox(height: 10),
                        Text(
                          'No se encontraron alimentos para "$_searchedQuery"',
                          style: TextStyle(fontFamily: ScFonts.ui, color: c.text2),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => Divider(color: c.line, height: 1),
                    itemBuilder: (context, index) {
                      final food = _results[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        title: Text(
                          food.name,
                          style: const TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          'P: ${food.proteinPer100g.toStringAsFixed(1)}g · C: ${food.carbsPer100g.toStringAsFixed(1)}g · G: ${food.fatPer100g.toStringAsFixed(1)}g'
                          '${food.brand != null && food.brand!.isNotEmpty ? " · ${food.brand}" : ""}',
                          style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12, color: c.text2),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: c.bg3,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${food.kcalPer100g.toInt()} kcal',
                            style: TextStyle(
                              fontFamily: ScFonts.display,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: c.accent,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          unawaited(FoodDetailSheet.show(
                            context: context,
                            foodItem: food,
                            dateKey: widget.dateKey,
                            initialMealType: widget.mealType,
                          ));
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
