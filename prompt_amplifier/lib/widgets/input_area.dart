import 'package:flutter/material.dart';
import '../app_strings.dart';

class InputArea extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final String lang;
  final VoidCallback onSend;

  const InputArea({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.lang,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: isLoading,
              decoration: InputDecoration(
                hintText: AppStrings.get('inputHint', lang),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: const TextStyle(fontSize: 18),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: isLoading ? null : onSend,
            icon: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                : const Icon(Icons.arrow_upward_rounded, size: 28),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.all(12),
              minimumSize: const Size(56, 56),
            ),
          ),
        ],
      ),
    );
  }
}