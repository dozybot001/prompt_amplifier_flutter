import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/editor_state.dart';

class PromptInputForm extends ConsumerStatefulWidget {
  const PromptInputForm({super.key});

  @override
  ConsumerState<PromptInputForm> createState() => _PromptInputFormState();
}

class _PromptInputFormState extends ConsumerState<PromptInputForm> {
  final _magicController = TextEditingController(); // 简单指令输入框

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(editorProvider.notifier);
    final state = ref.watch(editorProvider); // 监听状态以显示生成的选项

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // === 新增：魔法向导区域 ===
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('✨ 魔法向导 (不知道怎么填？)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _magicController,
                      decoration: const InputDecoration(
                        hintText: '输入简单指令，如：帮我做个PPT / 写个爬虫',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () {
                      // TODO: 调用生成选项的逻辑
                      notifier.analyzeInstruction(_magicController.text);
                    },
                    icon: state.isLoading
                        ? const SizedBox(width:16, height:16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_fix_high),
                    tooltip: '分析并生成选项',
                  ),
                ],
              ),

              // === 如果生成了选项，显示在这里 ===
              if (state.wizardSteps != null) ...[
                const Divider(height: 24),
                ...state.wizardSteps!.map((step) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Wrap(
                        spacing: 8,
                        children: step.options.map((opt) {
                          final isSelected = step.selected == opt;
                          return FilterChip(
                            label: Text(opt),
                            selected: isSelected,
                            onSelected: (val) {
                              notifier.selectWizardOption(step, opt);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }),
                // 应用选项按钮
                Center(
                  child: TextButton.icon(
                    onPressed: () => notifier.applyWizardToForm(),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('填入下方表单'),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Text('手动微调 (Expert Mode)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // 角色 (Role)
        _buildTextField(
          label: '角色 (Role)',
          hint: '例如：资深 Python 工程师',
          icon: Icons.person_outline,
          onChanged: notifier.updateRole,
        ),
        const SizedBox(height: 16),

        // 任务 (Task)
        _buildTextField(
          label: '任务 (Task)',
          hint: '例如：编写一个爬虫脚本',
          icon: Icons.task_alt,
          maxLines: 3,
          onChanged: notifier.updateTask,
        ),
        const SizedBox(height: 16),

        // 背景 (Context)
        _buildTextField(
          label: '背景 (Context)',
          hint: '例如：目标网站有反爬机制，需要使用 Selenium',
          icon: Icons.info_outline,
          maxLines: 3,
          onChanged: notifier.updateContext,
        ),
        const SizedBox(height: 16),

        // 格式 (Format)
        _buildTextField(
          label: '输出格式 (Format)',
          hint: '例如：Markdown 代码块，包含注释',
          icon: Icons.output,
          onChanged: notifier.updateFormat,
        ),
      ],
    );
  }

  // 封装一个通用的输入框构建方法
  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    required Function(String) onChanged,
    int maxLines = 1,
  }) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        alignLabelWithHint: true, // 让 Label 在多行输入时居顶
      ),
      maxLines: maxLines,
      onChanged: onChanged,
    );
  }
}