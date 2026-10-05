import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/component.dart';
import '../providers/theme_provider.dart';
import '../providers/viewmodels/armoury_viewmodel.dart';
import '../providers/viewmodels/search_viewmodel.dart';
import '../widgets/item_detail_sheet.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/new_component_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = ref.watch(themeProvider);
    final hasInventory = ref.watch(
      armouryViewModelProvider.select((state) => state.value != null),
    );
    final entryCount = ref.watch(
      armouryViewModelProvider.select(
        (state) => state.value?.items.length ?? 0,
      ),
    );
    final totalUnits = ref.watch(
      armouryViewModelProvider.select((state) => state.value?.totalUnits ?? 0),
    );
    final items = ref.watch(filteredComponentsProvider(null));

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (hasInventory)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.dividerLine)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatMetric(
                        label: 'ENTRIES',
                        value: '$entryCount',
                        isLight: isLight,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: AppColors.dividerLine,
                    ),
                    Expanded(
                      child: _StatMetric(
                        label: 'TOTAL UNITS',
                        value: '$totalUnits',
                        isLight: isLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (hasInventory && items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                '[NO COMPONENTS MATCH FILTER]',
                style: AppTypography.caption(color: AppColors.dim),
              ),
            ),
          )
        else if (hasInventory)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => _InventoryRow(
                key: ValueKey('${items[index].id}_$isLight'),
                item: items[index],
                isLight: isLight,
                onTap: () => _openDetails(context, ref, items[index]),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  void _openDetails(BuildContext context, WidgetRef ref, Component item) {
    final vm = ref.read(armouryViewModelProvider.notifier);
    ItemDetailSheet.show(
      context,
      component: item,
      onUpdate: (updated) => vm.updateComponent(item.id, updated.toJson()),
      onDelete: vm.delete,
      onOpenUpload: (component) =>
          MediaPickerSheet.show(context, component: component),
      onEdit: (component) => NewComponentSheet.showEdit(
        context,
        component: component,
        onUpdate: (updated) =>
            vm.updateComponent(component.id, updated.toJson()),
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  final Component item;
  final VoidCallback onTap;
  final bool isLight;

  const _InventoryRow({
    super.key,
    required this.item,
    required this.onTap,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: isLight ? const Color(0x12000000) : const Color(0x20FFFFFF),
      highlightColor: isLight ? const Color(0x0A000000) : const Color(0x10FFFFFF),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.dividerLine)),
        ),
        child: Row(
          children: [
            Text(
              '[${item.namespace.displayName}]',
              style: AppTypography.mono(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.dim,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subcategory.trim().isNotEmpty
                        ? '${item.id} · ${item.subcategory}'
                        : item.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(color: AppColors.dim),
                  ),
                ],
              ),
            ),
            Text(
              'QTY: ${item.qty}',
              style: AppTypography.mono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.fg,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 14, color: AppColors.dim),
          ],
        ),
      ),
    );
  }
}

class _StatMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool isLight;

  const _StatMetric({
    required this.label,
    required this.value,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: AppTypography.mono(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.fg,
        ),
      ),
      const SizedBox(height: 2),
      Text(label, style: AppTypography.caption(color: AppColors.dim)),
    ],
  );
}
