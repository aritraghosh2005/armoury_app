import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/component.dart';
import '../providers/theme_provider.dart';
import '../providers/viewmodels/armoury_viewmodel.dart';
import '../providers/viewmodels/search_viewmodel.dart';
import '../widgets/component_card.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/new_component_sheet.dart';

class SpaceScreen extends ConsumerWidget {
  final ComponentNamespace namespace;

  const SpaceScreen({super.key, required this.namespace});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = ref.watch(themeProvider);
    final hasInventory = ref.watch(
      armouryViewModelProvider.select((state) => state.value != null),
    );
    final filtered = ref.watch(filteredComponentsProvider(namespace));
    final vm = ref.read(armouryViewModelProvider.notifier);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (hasInventory && filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                '[NO COMPONENTS IN ${namespace.displayName}]',
                style: AppTypography.caption(color: AppColors.dim),
              ),
            ),
          )
        else if (hasInventory)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            sliver: SliverList.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                return ComponentCard(
                  key: ValueKey('${item.id}_$isLight'),
                  component: item,
                  onUpdate: (updated) => vm.updateComponent(item.id, {
                    'qty': updated.qty,
                    'image': updated.image,
                    'status': updated.status.name,
                    'namespace': updated.namespace.keyName,
                  }),
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
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}
