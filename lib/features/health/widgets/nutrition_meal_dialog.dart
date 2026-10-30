import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:endurain/core/models/nutrition_models.dart';
import 'package:endurain/core/services/nutrition_service.dart';
import 'package:endurain/features/health/widgets/nutrition_scanner_dialog.dart';

/// Add/edit dialog for one meal-log row.
///
/// Fields: product name + per-portion nutrition; an Open Food Facts search
/// (and the barcode scanner) pre-fills them from the product's per-100 g
/// values scaled to the portion weight. Returns the resulting [MealLog],
/// or `null` when cancelled.
Future<MealLog?> showNutritionMealDialog(
  BuildContext context, {
  required String date,
  required String mealType,
  required String mealTitle,
  MealLog? existing,
}) {
  return showDialog<MealLog>(
    context: context,
    builder: (dialogContext) => NutritionMealDialog(
      date: date,
      mealType: mealType,
      mealTitle: mealTitle,
      existing: existing,
    ),
  );
}

class NutritionMealDialog extends StatefulWidget {
  const NutritionMealDialog({
    super.key,
    required this.date,
    required this.mealType,
    required this.mealTitle,
    this.existing,
  });

  final String date;
  final String mealType;
  final String mealTitle;
  final MealLog? existing;

  @override
  State<NutritionMealDialog> createState() => _NutritionMealDialogState();
}

class _NutritionMealDialogState extends State<NutritionMealDialog> {
  final NutritionService _service = NutritionService.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _portionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  Timer? _historyDebounce;
  List<OffProduct> _searchResults = const [];
  List<MealLog> _history = const [];
  bool _searching = false;
  String? _barcode;

  /// Shares one formatter instance across rebuilds.
  static final TextInputFormatter _decimalFormatter =
      TextInputFormatter.withFunction((oldValue, newValue) {
    final text = newValue.text.replaceAll(',', '.');
    final valid = RegExp(r'^\d{0,6}(\.\d{0,2})?$').hasMatch(text);
    return valid ? newValue : oldValue;
  });

  /// Chosen product (per-100 g values) driving the auto-calculation.
  OffProduct? _product;
  bool _applyingPortion = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController.text = existing?.productName ?? '';
    _caloriesController.text = _num(existing?.calories);
    _proteinController.text = _num(existing?.protein);
    _carbsController.text = _num(existing?.carbs);
    _fatController.text = _num(existing?.fat);
    _portionController.text = _num(existing?.portionG);
    _barcode = existing?.offBarcode;
  }

  String _num(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
  }

  double? _parse(TextEditingController c) {
    final raw = c.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _historyDebounce?.cancel();
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _portionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double? _portionGrams() {
    final value = _parse(_portionController);
    if (value == null || value <= 0) return null;
    return value;
  }

  /// Recomputes absolute nutrition from the chosen product for the portion.
  void _applyProductValues({double? portion}) {
    if (_product == null) return;
    final grams = portion ?? _portionGrams() ?? 100;
    _applyingPortion = true;
    _portionController.text = _num(grams);
    _caloriesController.text = _scaled(_product!.calories100g, grams);
    _proteinController.text = _scaled(_product!.protein100g, grams);
    _carbsController.text = _scaled(_product!.carbs100g, grams);
    _fatController.text = _scaled(_product!.fat100g, grams);
    _applyingPortion = false;
  }

  String _scaled(double? per100, double grams) {
    if (per100 == null) return '';
    return _num(per100 * grams / 100);
  }

  void _applyProduct(OffProduct product) {
    setState(() {
      _product = product;
      _barcode = product.barcode.isNotEmpty ? product.barcode : _barcode;
      if (_nameController.text.trim().isEmpty) {
        final brands = product.brands;
        _nameController.text = brands == null || brands.isEmpty
            ? product.productName
            : '${product.productName} ($brands)';
      }
    });
    _applyProductValues(portion: _portionGrams() ?? 100);
  }

  void _onManualMacroEdit() {
    if (_applyingPortion) return;
    // Manual edit breaks the auto-calc link with the product.
    if (_product != null) setState(() => _product = null);
  }

  void _scheduleSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _runSearch(query),
    );
  }

  /// History-first autocomplete: instant local lookup while typing.
  void _scheduleHistory(String query) {
    _historyDebounce?.cancel();
    _historyDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _runHistory(query),
    );
  }

  Future<void> _runHistory(String query) async {
    final results = await _service.recentFoods(query);
    if (!mounted) return;
    setState(() => _history = results);
  }

  /// Fills the whole form from a history row (repeat meal in one tap).
  void _applyHistory(MealLog log) {
    setState(() {
      _product = null;
      _barcode = log.offBarcode;
      _nameController.text = log.productName;
      _caloriesController.text = _num(log.calories);
      _proteinController.text = _num(log.protein);
      _carbsController.text = _num(log.carbs);
      _fatController.text = _num(log.fat);
      _portionController.text = _num(log.portionG);
      _history = const [];
      _searchResults = const [];
    });
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final results = await _service.searchOff(q);
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _searching = false;
    });
  }

  Future<void> _scanBarcode() async {
    final barcode = await showNutritionBarcodeScanner(context);
    if (barcode == null || !mounted) return;
    setState(() => _searching = true);
    final product = await _service.fetchOffProduct(barcode);
    if (!mounted) return;
    setState(() => _searching = false);
    if (product == null || product.productName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Продукт со штрихкодом $barcode не найден')),
      );
      return;
    }
    _applyProduct(product);
  }

  MealLog? _buildResult() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите название продукта')),
      );
      return null;
    }
    final first = widget.existing;
    return MealLog(
      id: first?.id,
      localId: first?.localId,
      synced: first?.synced ?? true,
      date: first?.date ?? widget.date,
      mealType: first?.mealType ?? widget.mealType,
      productName: name,
      calories: _parse(_caloriesController),
      protein: _parse(_proteinController),
      carbs: _parse(_carbsController),
      fat: _parse(_fatController),
      portionG: _portionGrams(),
      offBarcode: _barcode,
    );
  }

  void _save() {
    final result = _buildResult();
    if (result == null) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit
                    ? 'Изменить приём — ${widget.mealTitle}'
                    : 'Добавить — ${widget.mealTitle}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              // --- Open Food Facts search ---
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Поиск продукта (Open Food Facts)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      onChanged: _scheduleSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Сканер штрихкода',
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _searching ? null : _scanBarcode,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildSearchList(theme),

              // --- main fields ---
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Продукт *',
                  isDense: true,
                ),
                onChanged: _scheduleHistory,
              ),
              const SizedBox(height: 6),
              _buildHistoryList(theme),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _portionController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_decimalFormatter],
                      decoration: const InputDecoration(
                        labelText: 'Порция, г',
                        isDense: true,
                      ),
                      onChanged: (value) {
                        if (_applyingPortion) return;
                        if (_product != null) {
                          _applyProductValues(portion: _portionGrams());
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _caloriesController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_decimalFormatter],
                      decoration: const InputDecoration(
                        labelText: 'Ккал',
                        isDense: true,
                      ),
                      onChanged: (_) => _onManualMacroEdit(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _proteinController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_decimalFormatter],
                      decoration: const InputDecoration(
                        labelText: 'Белки, г',
                        isDense: true,
                      ),
                      onChanged: (_) => _onManualMacroEdit(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _carbsController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_decimalFormatter],
                      decoration: const InputDecoration(
                        labelText: 'Углеводы, г',
                        isDense: true,
                      ),
                      onChanged: (_) => _onManualMacroEdit(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _fatController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_decimalFormatter],
                      decoration: const InputDecoration(
                        labelText: 'Жиры, г',
                        isDense: true,
                      ),
                      onChanged: (_) => _onManualMacroEdit(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_product != null)
                Text(
                  'Значения пересчитаны из ${_product!.productName} '
                  'на 100 г × порция.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _save,
                child: Text(_isEdit ? 'Сохранить' : 'Добавить'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Отмена'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "My foods" suggestions: repeat meals from local history in one tap.
  Widget _buildHistoryList(ThemeData theme) {
    if (_history.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                'Вы уже ели — тап для подстановки',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _history.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = _history[index];
                  final kcal = log.calories;
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history, size: 20),
                    title: Text(
                      log.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        if (log.portionG != null) '${_num(log.portionG)} г',
                        if (kcal != null) '${_num(kcal)} ккал',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _applyHistory(log),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchList(ThemeData theme) {
    if (_searching && _searchResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_searchResults.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _searchResults.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final product = _searchResults[index];
            final kcal = product.calories100g;
            return ListTile(
              dense: true,
              title: Text(
                product.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${product.brands ?? ''}'
                ' · ${kcal != null ? '${_num(kcal)} ккал/100г' : 'нет данных'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _applyProduct(product),
            );
          },
        ),
      ),
    );
  }
}
