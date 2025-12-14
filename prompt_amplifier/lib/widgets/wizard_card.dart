import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models.dart';
import '../state.dart';
import '../app_strings.dart';

class WizardOptionCard extends StatefulWidget {
  final WizardDimension step;
  final EditorNotifier notifier;
  final String lang;
  final ThemeData theme;

  const WizardOptionCard({
    super.key,
    required this.step,
    required this.notifier,
    required this.lang,
    required this.theme,
  });

  @override
  State<WizardOptionCard> createState() => _WizardOptionCardState();
}

class _WizardOptionCardState extends State<WizardOptionCard> {
  late TextEditingController _customInputController;

  @override
  void initState() {
    super.initState();
    _customInputController = TextEditingController(text: widget.step.selected);
  }

  @override
  void didUpdateWidget(covariant WizardOptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当外部状态改变时（例如重置），同步更新输入框
    if (widget.step.selected == null || widget.step.selected!.isEmpty) {
      if (_customInputController.text.isNotEmpty) _customInputController.clear();
    }
  }

  @override
  void dispose() {
    _customInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final step = widget.step;
    final bool isCustomInput = step.selected != null && step.selected!.isNotEmpty && !step.options.contains(step.selected);

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(step.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
                IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.outline),
                  tooltip: AppStrings.get('deleteDimension', widget.lang),
                  onPressed: () => widget.notifier.removeDimension(step),
                  visualDensity: VisualDensity.compact,
                )
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: step.options.map((opt) {
                final isSelected = step.selected == opt;
                return FilterChip(
                  label: Text(opt),
                  selected: isSelected,
                  onSelected: (_) {
                    _customInputController.clear();
                    widget.notifier.selectWizardOption(step, opt);
                  },
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  selectedColor: theme.colorScheme.surfaceContainerHighest,
                  labelStyle: TextStyle(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline, width: isSelected ? 1.5 : 1),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _customInputController,
              onChanged: (val) => widget.notifier.selectWizardOption(step, val),
              decoration: InputDecoration(
                hintText: AppStrings.get('customOptionHint', widget.lang),
                hintStyle: TextStyle(color: theme.colorScheme.outline),
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: isCustomInput ? OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1)) : null,
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}