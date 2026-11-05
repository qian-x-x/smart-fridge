import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/shared/widgets/action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/features/fridge/application/food_search_provider.dart';
import 'package:smart_fridge_app/features/fridge/domain/food_filter.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/features/fridge/presentation/widgets/food_category_options.dart';

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
  final _form = GlobalKey<FormState>();
  final _query = TextEditingController();
  String _category = '';
  final _tags = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  int? _zoneId;
  String _expiry = 'ALL';
  String _sort = 'EXPIRES_ASC';
  late FoodSearchRequest _request = (
    fridgeId: widget.workspace.fridgeId,
    filter: const FoodFilter(),
  );

  @override
  void dispose() {
    for (final controller in [_query, _tags, _from, _to]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _dateError(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = text.trim();
    final date = DateTime.tryParse(value);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
        date == null ||
        date.toIso8601String().substring(0, 10) != value) {
      return '请输入有效日期 YYYY-MM-DD';
    }
    return null;
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    setState(
      () => _request = (
        fridgeId: widget.workspace.fridgeId,
        filter: FoodFilter(
          query: _query.text,
          category: _category,
          tags: _tags.text
              .split(RegExp('[,，]'))
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toSet()
              .toList(),
          zoneId: _zoneId,
          expiryState: _expiry,
          expiresFrom: _from.text.trim(),
          expiresTo: _to.text.trim(),
          sort: _sort,
        ),
      ),
    );
  }

  void _reset() {
    // Reset old FormField values before setting our defaults: dropdown reset
    // invokes onChanged with its previous initialValue.
    _form.currentState!.reset();
    for (final controller in [_query, _tags, _from, _to]) {
      controller.clear();
    }
    setState(() {
      _category = '';
      _zoneId = null;
      _expiry = 'ALL';
      _sort = 'EXPIRES_ASC';
    });
    _apply();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(foodSearchProvider(_request));
    final fields = <Widget>[
      TextFormField(
        controller: _query,
        maxLength: 80,
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
        onChanged: (value) => setState(() => _category = value ?? ''),
      ),
      TextFormField(
        controller: _tags,
        decoration: const InputDecoration(labelText: '标签（逗号分隔）'),
        validator: (value) {
          final tags = (value ?? '')
              .split(RegExp('[,，]'))
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList();
          return tags.length > 20 || tags.any((tag) => tag.length > 40)
              ? '最多 20 个标签，每个不超过 40 字符'
              : null;
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
        onChanged: (value) => setState(() => _zoneId = value),
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
        onChanged: (value) => setState(() => _expiry = value!),
      ),
      TextFormField(
        controller: _from,
        decoration: const InputDecoration(labelText: '到期起日 YYYY-MM-DD'),
        validator: _dateError,
      ),
      TextFormField(
        controller: _to,
        decoration: const InputDecoration(labelText: '到期止日 YYYY-MM-DD'),
        validator: (value) {
          final error = _dateError(value);
          if (error != null) return error;
          if (_dateError(_from.text) == null &&
              _from.text.trim().isNotEmpty &&
              (value ?? '').trim().isNotEmpty &&
              _from.text.trim().compareTo(value!.trim()) > 0) {
            return '止日不能早于起日';
          }
          return null;
        },
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
        onChanged: (value) => setState(() => _sort = value!),
      ),
      Row(
        children: [
          Expanded(
            child: AppFilledButton(
              onPressed: _apply,
              child: const Text('应用筛选'),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(onPressed: _reset, child: const Text('重置')),
        ],
      ),
    ];
    final result = results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Column(
        children: [
          Text(error.toString()),
          TextButton(
            onPressed: () => ref.invalidate(foodSearchProvider(_request)),
            child: const Text('重试查询'),
          ),
        ],
      ),
      data: (foods) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('找到 ${foods.length} 份食材'),
          if (foods.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('没有符合条件的食材，可调整或重置筛选。'),
            ),
          for (final food in foods)
            Card(
              child: ListTile(
                leading: Text(food.emoji, style: const TextStyle(fontSize: 26)),
                title: Text(food.name),
                subtitle: Text(
                  '${food.category} · ${food.tags.join('、')}\n${food.quantity} ${food.unit} · 到期 ${food.expiresOn ?? ''}',
                ),
                trailing: Text(
                  food.expiresInDays < 0 ? '已过期' : '${food.expiresInDays} 天',
                ),
                onTap: () => widget.onFoodTap(food),
              ),
            ),
        ],
      ),
    );
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
        const SizedBox(height: 6),
        const Text(
          '组合筛选仅影响此清单；多个标签需同时满足。',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 20),
      ],
    );
    final spacedFields = <Widget>[
      for (final field in fields.indexed) ...[
        if (field.$1 > 0) const SizedBox(height: 12),
        field.$2,
      ],
    ];
    Widget form(BuildContext context, ScrollController? controller) => Form(
      key: _form,
      child: LayoutBuilder(
        builder: (context, size) {
          final bottom = 24 + MediaQuery.viewInsetsOf(context).bottom;
          if (size.maxWidth >= 760) {
            return Padding(
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
                            controller: controller,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: spacedFields,
                            ),
                          ),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          child: ListView(primary: false, children: [result]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(20, 18, 20, bottom),
            children: [
              header,
              ...spacedFields,
              const SizedBox(height: 24),
              result,
            ],
          );
        },
      ),
    );
    return LayoutBuilder(
      builder: (context, size) {
        if (size.maxWidth >= 760) {
          return SizedBox(
            height: MediaQuery.sizeOf(context).height * .88,
            child: form(context, null),
          );
        }
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .9,
          minChildSize: .6,
          maxChildSize: .96,
          builder: (context, controller) => form(context, controller),
        );
      },
    );
  }
}
