import 'package:flutter/material.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';
import 'package:smart_fridge_app/features/fridge/data/api_fridge_repository.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_data.dart';
import 'package:smart_fridge_app/features/fridge/domain/ingredient_stickers.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/ingredient_sticker_image.dart';
import 'package:smart_fridge_app/shared/widgets/action_button.dart';
import 'package:smart_fridge_app/shared/widgets/form_exit_guard.dart';

Future<void> showIngredientPicker(
  BuildContext context, {
  required List<FridgeZone> zones,
  required Future<void> Function(List<CatalogFoodInput>, String requestId)
  onSave,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  enableDrag: false,
  backgroundColor: AppColors.paper,
  constraints: const BoxConstraints(maxWidth: 840),
  builder: (context) => _IngredientPickerSheet(
    zones: {
      for (final zone in zones)
        if (zone.serverId != null) zone.id,
    },
    onSave: onSave,
  ),
);

enum _View { all, fresh, variable, freezer, selected }

class _IngredientPickerSheet extends StatefulWidget {
  const _IngredientPickerSheet({required this.zones, required this.onSave});

  final Set<FridgeZoneId> zones;
  final Future<void> Function(List<CatalogFoodInput>, String requestId) onSave;

  @override
  State<_IngredientPickerSheet> createState() => _IngredientPickerSheetState();
}

class _IngredientPickerSheetState extends State<_IngredientPickerSheet> {
  final _selection = <IngredientSticker, CatalogFoodInput>{};
  final _search = TextEditingController();
  String _query = '';
  _View _view = _View.all;
  String? _pendingRequestId;
  String? _error;
  bool _saving = false;

  bool get _canChange => !_saving && _pendingRequestId == null;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  FridgeZoneId _initialZone(IngredientSticker sticker) =>
      sticker.choiceOfStorage &&
          (_view == _View.freezer || !widget.zones.contains(sticker.zone))
      ? FridgeZoneId.freezer
      : sticker.zone;

  List<IngredientSticker> _visible() {
    final zone = switch (_view) {
      _View.fresh => FridgeZoneId.fresh,
      _View.variable => FridgeZoneId.variable,
      _View.freezer => FridgeZoneId.freezer,
      _ => null,
    };
    final items = _view == _View.selected
        ? _selection.keys
        : ingredientStickers;
    return items
        .where(
          (item) =>
              (zone == null ||
                  item.zone == zone ||
                  (zone == FridgeZoneId.freezer && item.choiceOfStorage)) &&
              (_query.isEmpty ||
                  item.name.contains(_query) ||
                  item.category.contains(_query) ||
                  (item.artwork?.contains(_query) ?? false)),
        )
        .toList(growable: false);
  }

  void _select(IngredientSticker sticker, bool checked) {
    setState(() {
      if (checked) {
        _selection[sticker] = CatalogFoodInput(
          sticker: sticker,
          zone: _initialZone(sticker),
          portions: 1,
        );
      } else {
        _selection.remove(sticker);
      }
    });
  }

  Future<void> _save() async {
    if (_saving || _selection.isEmpty) return;
    final inputs = List<CatalogFoodInput>.unmodifiable(_selection.values);
    final requestId = _pendingRequestId ?? newInventoryRequestId('add-foods');
    setState(() {
      _pendingRequestId = requestId;
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(inputs, requestId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('已入库 ${inputs.length} 种食材')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      final uncertain = error is ApiFailure && error.writeOutcomeUncertain;
      setState(() {
        _saving = false;
        if (!uncertain) _pendingRequestId = null;
        _error = uncertain ? '暂时无法确认入库结果，请重试本次添加。' : error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible();
    final total = _selection.values.fold<int>(
      0,
      (sum, item) => sum + item.portions,
    );
    return FormExitGuard(
      hasChanges: () => _selection.isNotEmpty,
      busy: () => _saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.9,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 400;
              final columns = constraints.maxWidth >= 650 ? 2 : 1;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '添加食材',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭添加',
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  if (!compact)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(18, 0, 18, 10),
                      child: Text(
                        '每份食材可用于一道菜。入库后可在库存详情修改到期提醒。',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: TextField(
                      key: const ValueKey('ingredient-picker-search'),
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                      decoration: InputDecoration(
                        labelText: '搜索食材或分类',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '清除搜索',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(() {
                                  _search.clear();
                                  _query = '';
                                }),
                              ),
                        isDense: true,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 5,
                      ),
                      children: [
                        for (final (view, label) in [
                          (_View.all, '全部'),
                          (_View.fresh, '冷藏'),
                          (_View.variable, '变温'),
                          (_View.freezer, '冷冻'),
                          (_View.selected, '已选 ${_selection.length}'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ChoiceChip(
                              label: Text(label),
                              showCheckmark: false,
                              selected: _view == view,
                              onSelected: (_) => setState(() {
                                _view = view;
                                if (view == _View.selected) {
                                  _search.clear();
                                  _query = '';
                                }
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(child: Text('没有符合条件的食材'))
                        : ListView.builder(
                            key: ValueKey((_view, _query)),
                            padding: const EdgeInsets.fromLTRB(18, 3, 18, 8),
                            itemCount: (items.length / columns).ceil(),
                            itemBuilder: (context, row) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (
                                    var column = 0;
                                    column < columns;
                                    column++
                                  ) ...[
                                    if (column > 0) const SizedBox(width: 8),
                                    Expanded(
                                      child:
                                          row * columns + column < items.length
                                          ? _tile(items[row * columns + column])
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                  ),
                  const Divider(height: 1),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: AppColors.rose),
                              ),
                            ),
                          AppFilledButton.icon(
                            key: const ValueKey('save-catalog-foods'),
                            onPressed: _selection.isEmpty || _saving
                                ? null
                                : _save,
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add, size: 19),
                            label: Text(
                              _saving
                                  ? '正在入库…'
                                  : _pendingRequestId != null
                                  ? '重试本次添加'
                                  : _selection.isEmpty
                                  ? '勾选食材后添加'
                                  : '添加 ${_selection.length} 种 · 共 $total 份',
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
        ),
      ),
    );
  }

  Widget _tile(IngredientSticker sticker) {
    final input = _selection[sticker];
    final zone = input?.zone ?? _initialZone(sticker);
    final available = widget.zones.contains(zone);
    final enabled = _canChange && available;
    return Material(
      color: input == null ? AppColors.paper : const Color(0xFFF0F4F6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: input == null ? AppColors.border : AppColors.terracotta,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            key: ValueKey('ingredient-${sticker.name}'),
            value: input != null,
            onChanged: enabled
                ? (checked) => _select(sticker, checked ?? false)
                : null,
            controlAffinity: ListTileControlAffinity.trailing,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 4,
            ),
            secondary: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFE8EEF2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: IngredientStickerImage(sticker: sticker, size: 45),
              ),
            ),
            title: Text(
              sticker.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${sticker.category} · ${available ? storageName(zone) : '分区不可用'}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          if (input != null) ...[
            const Divider(height: 1, indent: 10, endIndent: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 3, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('份量')),
                      IconButton(
                        tooltip: '减少${sticker.name}份量',
                        onPressed: enabled && input.portions > 1
                            ? () => _update(input, portions: input.portions - 1)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline, size: 21),
                      ),
                      Text('${input.portions} 份'),
                      IconButton(
                        tooltip: '增加${sticker.name}份量',
                        onPressed: enabled && input.portions < 999999999
                            ? () => _update(input, portions: input.portions + 1)
                            : null,
                        icon: const Icon(Icons.add_circle_outline, size: 21),
                      ),
                    ],
                  ),
                  if (sticker.choiceOfStorage)
                    Wrap(
                      spacing: 7,
                      children: [
                        for (final (target, label) in [
                          (FridgeZoneId.variable, '短期 · 变温'),
                          (FridgeZoneId.freezer, '长期 · 冷冻'),
                        ])
                          ChoiceChip(
                            label: Text(label),
                            showCheckmark: false,
                            selected: zone == target,
                            onSelected:
                                _canChange && widget.zones.contains(target)
                                ? (_) => _update(input, zone: target)
                                : null,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _update(CatalogFoodInput input, {int? portions, FridgeZoneId? zone}) {
    setState(() {
      _selection[input.sticker] = CatalogFoodInput(
        sticker: input.sticker,
        zone: zone ?? input.zone,
        portions: portions ?? input.portions,
      );
    });
  }
}
