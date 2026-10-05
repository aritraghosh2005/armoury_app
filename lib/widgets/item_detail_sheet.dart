import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/component.dart';
import '../providers/theme_provider.dart';
import 'component_image_view.dart';
import 'new_component_sheet.dart';
import 'terminal_button.dart';

/// The dedicated Item Window screen / inspector modal.
///
/// Features:
/// - Optical glass background container with specular bevels
/// - Clean square image frame with uncropped photo display
/// - Technical specification readout and tags
/// - Stock quantity controls
/// - Space reassignment actions and record purge
class ItemDetailSheet extends ConsumerWidget {
  final Component component;
  final ValueChanged<Component> onUpdate;
  final ValueChanged<String> onDelete;
  final ValueChanged<Component> onOpenUpload;
  final ValueChanged<Component>? onEdit;

  const ItemDetailSheet({
    super.key,
    required this.component,
    required this.onUpdate,
    required this.onDelete,
    required this.onOpenUpload,
    this.onEdit,
  });

  static Future<void> show(
    BuildContext context, {
    required Component component,
    required ValueChanged<Component> onUpdate,
    required ValueChanged<String> onDelete,
    required ValueChanged<Component> onOpenUpload,
    ValueChanged<Component>? onEdit,
  }) {
    final isLight = AppColors.isLight;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: isLight ? const Color(0x35000000) : const Color(0x90000000),
      builder: (_) => ItemDetailSheet(
        component: component,
        onUpdate: onUpdate,
        onDelete: onDelete,
        onOpenUpload: onOpenUpload,
        onEdit: onEdit,
      ),
    );
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
              Navigator.of(context).pop();
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
    final systemBottom = MediaQuery.of(context).viewPadding.bottom;
    final isButtonNav = systemBottom > 24.0;
    final bottomInset = isButtonNav
        ? systemBottom
        : (systemBottom > 0 ? systemBottom : 12.0);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: isLight
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFF8FAFC),
                    Color(0xFFF1F5F9),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xF606090D), // Smoked dark obsidian top
                    Color(0xFA020406), // Rich OLED dark crystal body
                    Color(0xFF000000), // Pure OLED black bottom
                  ],
                  stops: [0.0, 0.35, 1.0],
                ),
          border: Border(
            top: BorderSide(
              color: isLight ? const Color(0xFFCBD5E1) : const Color(0x60FFFFFF),
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: isLight ? const Color(0x20000000) : const Color(0xDD000000),
              blurRadius: 36,
              offset: const Offset(0, -8),
            ),
          ],
        ),
          padding: EdgeInsets.only(
            top: 14,
            left: 16,
            right: 16,
            bottom: bottomInset + 12,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '[${component.namespace.keyName.toUpperCase()}]',
                        style: AppTypography.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.dim,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        component.category.toUpperCase(),
                        style: AppTypography.caption(color: AppColors.dim),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        '[✕]',
                        style: AppTypography.mono(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.fg,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: AppColors.dividerLine),
              const SizedBox(height: 12),

              // Scrollable Content
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Square Image Frame
                    if (_hasImage) ...[
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 280,
                            maxHeight: 280,
                          ),
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: isLight ? const Color(0xFFF1F5F9) : const Color(0x12FFFFFF),
                                    border: Border.all(
                                      color: isLight ? const Color(0xFFCBD5E1) : const Color(0x40FFFFFF),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isLight ? const Color(0x15000000) : const Color(0x50000000),
                                        blurRadius: 14,
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
                      const SizedBox(height: 14),
                    ],
                    // Component Title & ID
                    Text(
                      component.name,
                      style: AppTypography.title(color: AppColors.fg),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      component.subcategory.trim().isNotEmpty
                          ? 'ID: ${component.id} · ${component.subcategory}'
                          : 'ID: ${component.id}',
                      style: AppTypography.caption(color: AppColors.dim),
                    ),
                    const SizedBox(height: 10),
                    Container(height: 1, color: AppColors.dividerLine),
                    const SizedBox(height: 10),

                    // Description (Hide if empty)
                    if (component.desc.trim().isNotEmpty) ...[
                      Text(
                        component.desc,
                        style: AppTypography.body(color: AppColors.fg),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Technical Specifications (Hide if empty)
                    if (component.specs.trim().isNotEmpty) ...[
                      Text(
                        'SPECIFICATION:',
                        style: AppTypography.caption(color: AppColors.dim),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        component.specs,
                        style: AppTypography.mono(
                          fontSize: 12,
                          color: AppColors.fg,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Location (Hide if empty) & Quantity Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (component.location.trim().isNotEmpty)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LOCATION:',
                                  style: AppTypography.caption(color: AppColors.dim),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  component.location,
                                  style: AppTypography.mono(
                                    fontSize: 12,
                                    color: AppColors.fg,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const Spacer(),
                        Row(
                          children: [
                            Text(
                              'QTY: ${component.qty}',
                              style: AppTypography.mono(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.fg,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TerminalButton(
                              label: '-',
                              compact: true,
                              onPressed: component.qty > 0
                                  ? () {
                                      onUpdate(component.copyWith(
                                        qty: component.qty - 1,
                                      ));
                                    }
                                  : null,
                            ),
                            const SizedBox(width: 4),
                            TerminalButton(
                              label: '+',
                              compact: true,
                              onPressed: () {
                                onUpdate(component.copyWith(
                                  qty: component.qty + 1,
                                ));
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Tags
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
                      const SizedBox(height: 14),
                    ],

                    Container(height: 1, color: AppColors.dividerLine),
                    const SizedBox(height: 12),

                    // Relocate & Purge Actions
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
                                Navigator.of(context).pop();
                              },
                            ),
                          );
                        }),
                        const Spacer(),
                        TerminalButton(
                          label: 'PURGE',
                          compact: true,
                          variant: TerminalButtonVariant.danger,
                          onPressed: () => _confirmDelete(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Modify Details Button
                    SizedBox(
                      width: double.infinity,
                      child: TerminalButton(
                        label: '✎ MODIFY COMPONENT DETAILS',
                        variant: TerminalButtonVariant.primary,
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (onEdit != null) {
                            onEdit!(component);
                          } else {
                            NewComponentSheet.showEdit(
                              context,
                              component: component,
                              onUpdate: (updated) async {
                                onUpdate(updated);
                              },
                            );
                          }
                        },
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
}
