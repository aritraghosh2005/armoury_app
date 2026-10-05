import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/component.dart';
import '../providers/theme_provider.dart';
import '../providers/viewmodels/media_viewmodel.dart';
import 'component_image_view.dart';
import 'status_badge.dart';
import 'terminal_button.dart';

class NewComponentSheet extends ConsumerStatefulWidget {
  final ComponentNamespace defaultNamespace;
  final Component? initialComponent;
  final Future<void> Function(Map<String, dynamic> data)? onRegister;
  final Future<void> Function(Component updated)? onUpdate;

  const NewComponentSheet({
    super.key,
    required this.defaultNamespace,
    this.initialComponent,
    this.onRegister,
    this.onUpdate,
  });

  static Future<void> show(
    BuildContext context, {
    required ComponentNamespace defaultNamespace,
    required Future<void> Function(Map<String, dynamic> data) onRegister,
  }) {
    final isLight = AppColors.isLight;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: isLight ? const Color(0x35000000) : const Color(0x90000000),
      builder: (_) => NewComponentSheet(
        defaultNamespace: defaultNamespace,
        onRegister: onRegister,
      ),
    );
  }

  static Future<void> showEdit(
    BuildContext context, {
    required Component component,
    required Future<void> Function(Component updated) onUpdate,
  }) {
    final isLight = AppColors.isLight;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: isLight ? const Color(0x35000000) : const Color(0x90000000),
      builder: (_) => NewComponentSheet(
        defaultNamespace: component.namespace,
        initialComponent: component,
        onUpdate: onUpdate,
      ),
    );
  }

  @override
  ConsumerState<NewComponentSheet> createState() => _NewComponentSheetState();
}

class _NewComponentSheetState extends ConsumerState<NewComponentSheet> {
  late ComponentNamespace _namespace;
  String _category = 'Electrical';
  final _nameCtrl = TextEditingController();
  final _subCatCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _descCtrl = TextEditingController();
  final _specsCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  String? _selectedImagePath;
  bool _isLoading = false;

  final List<String> _categories = ['Mechanical', 'Electrical', 'Others'];

  bool get isEditing => widget.initialComponent != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialComponent != null) {
      final comp = widget.initialComponent!;
      _namespace = comp.namespace;
      _category = _categories.contains(comp.category)
          ? comp.category
          : 'Electrical';
      _nameCtrl.text = comp.name;
      _subCatCtrl.text = comp.subcategory;
      _qtyCtrl.text = comp.qty.toString();
      _locCtrl.text = comp.location;
      _specsCtrl.text = comp.specs;
      _descCtrl.text = comp.desc;
      _tagsCtrl.text = comp.tags.join(', ');
      _selectedImagePath =
          (comp.image != null && comp.image != 'none' && comp.image!.isNotEmpty)
          ? comp.image
          : null;
    } else {
      _namespace = widget.defaultNamespace;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subCatCtrl.dispose();
    _qtyCtrl.dispose();
    _descCtrl.dispose();
    _specsCtrl.dispose();
    _locCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleCaptureCamera() async {
    try {
      final path = await ref
          .read(mediaViewModelProvider.notifier)
          .captureDraft();
      if (path != null && mounted) {
        setState(() => _selectedImagePath = path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.cardBgElevated,
            content: Text(
              'PHOTO STORED IN DCIM/Armoury & LINKED',
              style: TextStyle(color: AppColors.fg, fontFamily: 'monospace'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.cardBgElevated,
            content: Text(
              'FAILED TO CAPTURE PHOTO: $e',
              style: TextStyle(
                color: AppColors.fg,
                fontFamily: 'monospace',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handlePickGallery() async {
    try {
      final path = await ref.read(mediaViewModelProvider.notifier).pickDraft();
      if (path != null && mounted) {
        setState(() => _selectedImagePath = path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.cardBgElevated,
            content: Text(
              'FAILED TO PICK IMAGE: $e',
              style: TextStyle(
                color: AppColors.fg,
                fontFamily: 'monospace',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a component name.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
      final status = qty == 0
          ? 'depleted'
          : qty < 5
          ? 'low'
          : 'available';

      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      if (isEditing) {
        final comp = widget.initialComponent!;
        final updated = comp.copyWith(
          namespace: _namespace,
          category: _category,
          subcategory: _subCatCtrl.text.trim(),
          name: name,
          qty: qty,
          desc: _descCtrl.text.trim(),
          specs: _specsCtrl.text.trim(),
          location: _locCtrl.text.trim(),
          status: ComponentStatusType.fromString(status),
          tags: tags,
          image: _selectedImagePath ?? 'none',
        );
        if (widget.onUpdate != null) {
          await widget.onUpdate!(updated);
        }
      } else {
        final generatedId = 'COMP-${1000 + Random().nextInt(9000)}';
        final data = {
          'id': generatedId,
          'namespace': _namespace.keyName,
          'category': _category,
          'subcategory': _subCatCtrl.text.trim(),
          'name': name,
          'qty': qty,
          'desc': _descCtrl.text.trim(),
          'specs': _specsCtrl.text.trim(),
          'location': _locCtrl.text.trim(),
          'status': status,
          'tags': tags,
          'pic': '',
          if (_selectedImagePath != null) 'image': _selectedImagePath,
        };

        if (widget.onRegister != null) {
          await widget.onRegister!(data);
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.bg,
            title: Text(
              'REGISTRATION FAILED',
              style: AppTypography.heading(color: AppColors.fg),
            ),
            content: Text(
              e.toString(),
              style: AppTypography.body(color: AppColors.dim),
            ),
            actions: [
              TerminalButton(
                label: 'OK',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption(color: AppColors.dim)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.cardBgElevated,
            border: Border.all(color: AppColors.borderSubtle, width: 1),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: AppTypography.mono(fontSize: 12.5, color: AppColors.fg),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.mono(
                fontSize: 12,
                color: AppColors.dimmer,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCapturingMedia = ref.watch(
      mediaViewModelProvider.select((state) => state.isLoading),
    );
    final isLight = ref.watch(themeProvider);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final systemBottom = MediaQuery.of(context).viewPadding.bottom;
    final isButtonNav = systemBottom > 24.0;
    final navInset = isButtonNav
        ? systemBottom
        : (systemBottom > 0 ? systemBottom : 10.0);
    final bottomInset = keyboardInset > 0
        ? keyboardInset + 8.0
        : navInset + 10.0;

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
            bottom: bottomInset,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing
                        ? '[✎ MODIFY COMPONENT DETAILS]'
                        : '[+ REGISTER NEW COMPONENT]',
                    style: AppTypography.heading(color: AppColors.fg),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(
                      '[✕]',
                      style: AppTypography.mono(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.fg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView(
                  children: [
                    // 1. Namespace Selector
                    Text(
                      'TARGET SPACE:',
                      style: AppTypography.caption(color: AppColors.dim),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: ComponentNamespace.values.map((ns) {
                        final isSel = _namespace == ns;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _namespace = ns),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? AppColors.fg
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSel
                                      ? AppColors.fg
                                      : AppColors.borderSubtle,
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '[${ns.displayName}]',
                                  style: AppTypography.mono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSel ? AppColors.bg : AppColors.fg,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // 2. Category Selector
                    Text(
                      'ENGINEERING DOMAIN:',
                      style: AppTypography.caption(color: AppColors.dim),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: _categories.map((cat) {
                        final isSel = _category == cat;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _category = cat),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? AppColors.fg
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSel
                                      ? AppColors.fg
                                      : AppColors.borderSubtle,
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '[${cat.toUpperCase()}]',
                                  style: AppTypography.mono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSel ? AppColors.bg : AppColors.fg,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // 3. Hardware Media / Photo Upload Section
                    Text(
                      'COMPONENT PHOTO / SCHEMATIC (OPTIONAL):',
                      style: AppTypography.caption(color: AppColors.dim),
                    ),
                    const SizedBox(height: 6),
                    if (_selectedImagePath != null) ...[
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 240,
                            maxHeight: 240,
                          ),
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
                                      width: 1,
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
                                      imageSource: _selectedImagePath,
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
                                        label: 'RETAKE',
                                        compact: true,
                                        variant:
                                            TerminalButtonVariant.secondary,
                                        onPressed: _handleCaptureCamera,
                                      ),
                                      const SizedBox(width: 4),
                                      TerminalButton(
                                        label: '✕',
                                        compact: true,
                                        variant: TerminalButtonVariant.secondary,
                                        onPressed: () => setState(
                                          () => _selectedImagePath = null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.cardBgElevated,
                          border: Border.all(
                            color: AppColors.borderSubtle,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            if (isCapturingMedia) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.fg,
                                ),
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: TerminalButton(
                                      label: '◉ CAMERA',
                                      compact: true,
                                      variant: TerminalButtonVariant.primary,
                                      onPressed: _handleCaptureCamera,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TerminalButton(
                                      label: '↑ GALLERY',
                                      compact: true,
                                      variant: TerminalButtonVariant.secondary,
                                      onPressed: _handlePickGallery,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // 4. Input Fields
                    _buildField(
                      label: 'COMPONENT NAME *',
                      controller: _nameCtrl,
                      hint: 'e.g. STM32 Nucleo-F446RE',
                    ),
                    _buildField(
                      label: 'SUBCATEGORY',
                      controller: _subCatCtrl,
                      hint: 'e.g. Microcontroller Dev Board',
                    ),
                    _buildField(
                      label: 'INITIAL QUANTITY',
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      hint: '1',
                    ),
                    _buildField(
                      label: 'STORAGE LOCATION',
                      controller: _locCtrl,
                      hint: 'e.g. Rack A - Shelf 3 - Bin 12',
                    ),
                    _buildField(
                      label: 'TECHNICAL SPECIFICATIONS',
                      controller: _specsCtrl,
                      hint: 'e.g. 180MHz ARM Cortex-M4, 512KB Flash',
                    ),
                    _buildField(
                      label: 'DESCRIPTION / NOTES',
                      controller: _descCtrl,
                      maxLines: 2,
                      hint: 'Operational notes, pinout info, etc.',
                    ),
                    _buildField(
                      label: 'TAGS (COMMA SEPARATED)',
                      controller: _tagsCtrl,
                      hint: 'arm, stm32, uart, spi, dev',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              // Footer Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TerminalButton(
                      label: 'CANCEL',
                      variant: TerminalButtonVariant.subtle,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TerminalButton(
                      label: _isLoading
                          ? (isEditing ? 'SAVING...' : 'REGISTERING...')
                          : (isEditing
                                ? 'SAVE MODIFICATIONS'
                                : '+ REGISTER COMPONENT'),
                      variant: TerminalButtonVariant.primary,
                      onPressed: _isLoading ? null : _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
  }
}

