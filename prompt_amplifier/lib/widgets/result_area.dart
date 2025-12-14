import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_strings.dart';

class ResultArea extends StatelessWidget {
  final String resultText;
  final String lang;

  const ResultArea({
    super.key,
    required this.resultText,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 48),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.get('finalPromptTitle', lang),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          SelectableText(
            resultText,
            style: const TextStyle(fontSize: 16, height: 1.6, fontFamily: 'Microsoft YaHei'),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.98, 0.98));
  }
}