import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/features/fridge/application/food_search_provider.dart';
import 'package:smart_fridge_app/features/fridge/domain/food_filter.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/features/fridge/domain/ingredient_stickers.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/food_category_options.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/ingredient_sticker_image.dart';

class FoodSearchSheet extends ConsumerStatefulWidget {
  const FoodSearchSheet({
    super.key,
    required this.workspace,
    required this.onFoodTap,
  });
  final FridgeWorkspaceData workspace;
  final ValueChanged<FridgeFood> onFoodTap;

  @override
  ConsumerState<FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends ConsumerState<FoodSearchSheet> {
  final _query = TextEditingController();
  Timer? _typingDelay;
  String _category = '';
  int? _zoneId;
  String _expiry = 'ALL';
  FoodExpiryWindow _window = FoodExpiryWindow.all;
  String _sort = 'EXPIRES_ASC';
  late FoodSearchRequest _request = (
    fridgeId: widget.workspace.fridgeId,
    filter: const FoodFilter(),
  );

  @override
  void dispose() {
    _typingDelay?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onTextChanged(String _) {
    _typingDelay?.cancel();
    _typingDelay = Timer(const Duration(milliseconds: 250), _updateSearch);
  }

  void _updateSearch() {
    _typingDelay?.cancel();
    setState(
      () => _request = (
        fridgeId: widget.workspace.fridgeId,
        filter: FoodFilter(
          query: _query.text,
          category: _category,
          zoneId: _zoneId,
          expiryState: _expiry,
          sort: _sort,
        ),
      ),
    );
  }

  void _reset() {
    _query.clear();
    _category = '';
    _zoneId = null;
    _expiry = 'ALL';
    _window = FoodExpiryWindow.all;
    _sort = 'EXPIRES_ASC';
    _updateSearch();
  }

  List<Widget> _resultSlivers() {
    return ref
        .watch(foodSearchProvider(_request))
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const [
            SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (error, stack) => [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Text(error.toString()),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(foodSearchProvider(_request)),
                    child: const Text('重试查询'),
                  ),
                ],
              ),
            ),
          ],
          data: (results) {
            final foods = results
                .where(_window.includes)
                .toList(growable: false);
            return [
              SliverToBoxAdapter(child: Text('找到 ${foods.length} 份食材')),
              if (foods.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('没有符合条件的食材，可调整或重置筛选。'),
                  ),
                ),
              SliverList.builder(
                itemCount: foods.length,
                itemBuilder: (context, index) {
                  final food = foods[index];
                  return Card(
                    child: ListTile(
                      leading: IngredientStickerImage(
                        sticker: stickerForFood(food),
                        emoji: food.emoji,
                        size: 42,
                      ),
                      title: Text(food.name),
                      subtitle: Text(
                        '${food.category}${food.tags.isEmpty ? '' : ' · ${food.tags.join('、')}'}\n'
                        '${food.quantity} ${food.unit} · 到期 ${food.expiresOn ?? ''}',
                      ),
                      trailing: Text(
                        food.expiresInDays < 0
                            ? '已过期'
                            : '${food.expiresInDays} 天',
                      ),
                      onTap: () => widget.onFoodTap(food),
                    ),
                  );
                },
              ),
            ];
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final resultSlivers = _resultSlivers();
    final fields = <Widget>[
      TextField(
        controller: _query,
        maxLength: 80,
        onChanged: _onTextChanged,
        decoration: const InputDecoration(
          labelText: '食材名称',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      DropdownButtonFormField<String>(
        key: ValueKey('search-category-$_category'),
        initialValue: _category,
        isExpanded: true,
        decoration: const InputDecoration(labelText: '分类'),
        items: [
          const DropdownMenuItem(value: '', child: Text('全部分类')),
          for (final category in {
            ...foodCategoryOptions,
            // Keep existing inventory categories selectable without rewriting it.
            ...widget.workspace.foods
                .map((food) => food.category)
                .where((category) => category.trim().isNotEmpty),
          })
            DropdownMenuItem(value: category, child: Text(category)),
        ],
        onChanged: (value) {
          _category = value ?? '';
          _updateSearch();
        },
      ),
      DropdownButtonFormField<int>(
        key: ValueKey('search-zone-$_zoneId'),
        initialValue: _zoneId,
        decoration: const InputDecoration(labelText: '分区'),
        isExpanded: true,
        items: [
          const DropdownMenuItem<int>(child: Text('全部分区')),
          for (final zone in widget.workspace.zones)
            DropdownMenuItem(value: zone.serverId, child: Text(zone.name)),
        ],
        onChanged: (value) {
          _zoneId = value;
          _updateSearch();
        },
      ),
      DropdownButtonFormField<String>(
        key: ValueKey('search-expiry-$_expiry'),
        initialValue: _expiry,
        decoration: const InputDecoration(labelText: '到期状态'),
        isExpanded: true,
        items: const [
          DropdownMenuItem(value: 'ALL', child: Text('全部状态')),
          DropdownMenuItem(value: 'EXPIRED', child: Text('已过期')),
          DropdownMenuItem(value: 'EXPIRING', child: Text('临期（今天至 3 天内）')),
          DropdownMenuItem(value: 'FRESH', child: Text('新鲜（超过 3 天）')),
        ],
        onChanged: (value) {
          _expiry = value!;
          _updateSearch();
        },
      ),
      DropdownButtonFormField<FoodExpiryWindow>(
        key: ValueKey('search-window-$_window'),
        initialValue: _window,
        decoration: const InputDecoration(labelText: '到期期限'),
        isExpanded: true,
        items: [
          for (final window in FoodExpiryWindow.values)
            DropdownMenuItem(value: window, child: Text(window.label)),
        ],
        onChanged: (value) => setState(() => _window = value!),
      ),
      DropdownButtonFormField<String>(
        key: ValueKey('search-sort-$_sort'),
        initialValue: _sort,
        decoration: const InputDecoration(labelText: '排序'),
        isExpanded: true,
        items: const [
          DropdownMenuItem(value: 'EXPIRES_ASC', child: Text('最早到期优先')),
          DropdownMenuItem(value: 'EXPIRES_DESC', child: Text('最晚到期优先')),
          DropdownMenuItem(value: 'NAME_ASC', child: Text('名称升序')),
          DropdownMenuItem(value: 'CREATED_DESC', child: Text('最近添加优先')),
        ],
        onChanged: (value) {
          _sort = value!;
          _updateSearch();
        },
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(onPressed: _reset, child: const Text('重置')),
      ),
    ];
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '冰箱清单',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: '关闭清单',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
    final spacedFields = <Widget>[
      for (final field in fields.indexed) ...[
        if (field.$1 > 0) const SizedBox(height: 12),
        field.$2,
      ],
    ];
    return LayoutBuilder(
      builder: (context, size) {
        final bottom = 24 + MediaQuery.viewInsetsOf(context).bottom;
        if (size.maxWidth >= 760) {
          return SizedBox(
            height: MediaQuery.sizeOf(context).height * .88,
            child: Padding(
              padding: EdgeInsets.fromLTRB(26, 20, 26, bottom),
              child: Column(
                children: [
                  header,
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: spacedFields,
                            ),
                          ),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          child: CustomScrollView(
                            key: ValueKey((_request, _window)),
                            primary: false,
                            slivers: resultSlivers,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .9,
          minChildSize: .6,
          maxChildSize: .96,
          builder: (context, controller) => CustomScrollView(
            controller: controller,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, bottom),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          header,
                          ...spacedFields,
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    ...resultSlivers,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
