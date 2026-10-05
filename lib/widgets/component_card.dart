import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/component.dart';
import '../providers/theme_provider.dart';
import 'component_image_view.dart';
import 'terminal_button.dart';

class ComponentCard extends ConsumerWidget {
  final Component component;
  final ValueChanged<Component> onUpdate;
  final ValueChanged<String> onDelete;
  final ValueChanged<Component> onOpenUpload;
  final ValueChanged<Component>? onEdit;

  const ComponentCard({
    super.key,
    required this.component,
    required this.onUpdate,
    required this.onDelete,
    required this.onOpenUpload,
    this.onEdit,
  });

  String _formatNamespace(ComponentNamespace ns) {
    switch (ns) {
      case ComponentNamespace.crate:
        return '[▣ CRATE]';
      case ComponentNamespace.toolkit:
        return '[⌧ TOOLKIT]';
      case ComponentNamespace.cupboard:
        return '[≡ CUPBOARD]';
    }
  }

  bool get _hasImage =>
      component.image != null &&
      component.image!.isNotEmpty &&
      component.image!.toLowerCase() != 'none';

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.borderSubtle, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        title: Text(
          'PURGE RECORD',
          style: AppTypography.heading(color: AppColors.fg),
        ),
        content: Text(
          'Delete component ${component.id} (${component.name}) from offline repository?',
          style: AppTypography.body(color: AppColors.dim),
        ),
        actions: [
          TerminalButton(
            label: 'CANCEL',
            compact: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TerminalButton(
            label: 'PURGE',
            compact: true,
            variant: TerminalButtonVariant.danger,
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete(component.id);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = ref.watch(themeProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.dividerLine, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Bar: Namespace + Category (No status badge)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatNamespace(component.namespace),
                style: AppTypography.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dim,
                ),
              ),
              Text(
                component.category.toUpperCase(),
                style: AppTypography.caption(color: AppColors.dim),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. Square Image Frame / Attachment Placeholder
          if (_hasImage) ...[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isLight ? const Color(0xFFF1F5F9) : const Color(0x10FFFFFF),
                          border: Border.all(
                            color: isLight ? const Color(0xFFCBD5E1) : const Color(0x40FFFFFF),
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: isLight ? const Color(0x15000000) : const Color(0x50000000),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: ComponentImageView(
                            imageSource: component.image,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                      // HUD Quick Action Buttons
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          children: [
                            TerminalButton(
                              label: '↑',
                              compact: true,
                              variant: TerminalButtonVariant.secondary,
                              onPressed: () => onOpenUpload(component),
                            ),
                            const SizedBox(width: 4),
                            TerminalButton(
                              label: '✕',
                              compact: true,
                              variant: TerminalButtonVariant.secondary,
                              onPressed: () {
                                onUpdate(component.copyWith(image: 'none'));
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // 3. Name & Subcategory (Hide subcategory if not filled)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      component.name,
                      style: AppTypography.heading(color: AppColors.fg),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      component.subcategory.trim().isNotEmpty
                          ? 'ID: ${component.id} · ${component.subcategory}'
                          : 'ID: ${component.id}',
                      style: AppTypography.caption(color: AppColors.dim),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 4. Description & Specs (Hide if not filled)
          if (component.desc.trim().isNotEmpty) ...[
            Text(
              component.desc,
              style: AppTypography.body(color: AppColors.dim),
            ),
            const SizedBox(height: 6),
          ],
          if (component.specs.trim().isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'SPEC: ${component.specs}',
                style: AppTypography.mono(
                  fontSize: 11,
                  color: AppColors.dim,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],

          // 5. Metadata Row: Location (if filled) & Qty Controller
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (component.location.trim().isNotEmpty)
                Expanded(
                  child: Text(
                    'LOC: ${component.location}',
                    style: AppTypography.caption(color: AppColors.dim),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'QTY: ${component.qty}',
                    style: AppTypography.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.fg,
                    ),
                  ),
                  const SizedBox(width: 6),
                  TerminalButton(
                    label: '-',
                    compact: true,
                    onPressed: component.qty > 0
                        ? () {
                            onUpdate(
                              component.copyWith(qty: component.qty - 1),
                            );
                          }
                        : null,
                  ),
                  const SizedBox(width: 4),
                  TerminalButton(
                    label: '+',
                    compact: true,
                    onPressed: () {
                      onUpdate(
                        component.copyWith(qty: component.qty + 1),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 6. Tags
          if (component.tags.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: component.tags.map((tag) {
                return Text(
                  '#$tag',
                  style: AppTypography.caption(color: AppColors.dim),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],

          // 7. Footer: Move to other spaces, Edit & Purge
          Row(
            children: [
              Text(
                'MOVE:',
                style: AppTypography.caption(color: AppColors.dim),
              ),
              const SizedBox(width: 6),
              ...ComponentNamespace.values
                  .where((ns) => ns != component.namespace)
                  .map((ns) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: TerminalButton(
                    label: ns.keyName.toUpperCase(),
                    compact: true,
                    variant: TerminalButtonVariant.subtle,
                    onPressed: () {
                      onUpdate(component.copyWith(namespace: ns));
                    },
                  ),
                );
              }),
              const Spacer(),
              if (onEdit != null) ...[
                TerminalButton(
                  label: '✎ EDIT',
                  compact: true,
                  variant: TerminalButtonVariant.secondary,
                  onPressed: () => onEdit!(component),
                ),
                const SizedBox(width: 6),
              ],
              TerminalButton(
                label: 'PURGE',
                compact: true,
                variant: TerminalButtonVariant.danger,
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
