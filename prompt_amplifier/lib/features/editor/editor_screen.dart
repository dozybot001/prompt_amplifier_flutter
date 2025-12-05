import 'package:flutter/material.dart';
import 'widgets/prompt_input_form.dart';
import 'widgets/prompt_preview_area.dart';

class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用 LayoutBuilder 获取当前可用的宽度
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prompt Amplifier'),
        centerTitle: false,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.history), tooltip: '历史记录'),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 断点设为 700，大于它就是桌面/平板模式
          if (constraints.maxWidth > 700) {
            return const _DesktopLayout();
          } else {
            return const _MobileLayout();
          }
        },
      ),
    );
  }
}

// 桌面端布局：左右分栏
class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        // 左侧输入区 (占 50% 或固定宽度)
        Expanded(
          flex: 5,
          child: PromptInputForm(),
        ),
        VerticalDivider(width: 1),
        // 右侧预览区 (占 50%)
        Expanded(
          flex: 5,
          child: PromptPreviewArea(),
        ),
      ],
    );
  }
}

// 移动端布局：使用 Tab 切换
class _MobileLayout extends StatelessWidget {
  const _MobileLayout();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '编辑 (Input)'),
              Tab(text: '预览 (Preview)'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                PromptInputForm(),
                PromptPreviewArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}