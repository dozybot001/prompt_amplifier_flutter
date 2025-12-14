// lib/widgets/history_drawer.dart (建议新建文件，或者放在 home_screen.dart 底部)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // 需在 pubspec.yaml 添加 intl
import '../history_service.dart';

class HistoryDrawer extends ConsumerWidget {
  final Function(String) onRestore;
  const HistoryDrawer({super.key, required this.onRestore});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final theme = Theme.of(context);

    // 分离收藏和普通记录，或者直接混合排序
    // 这里简单处理：直接列表
    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text("历史记录", style: theme.textTheme.titleLarge),
                ],
              ),
            ),
          ),
          Expanded(
            child: history.isEmpty
                ? Center(child: Text("暂无记录", style: TextStyle(color: theme.colorScheme.outline)))
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      final dateStr = DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(item.timestamp));
                      
                      return Dismissible(
                        key: Key(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: theme.colorScheme.errorContainer,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
                        ),
                        onDismissed: (_) {
                          ref.read(historyProvider.notifier).deleteRecord(item.id);
                        },
                        child: ListTile(
                          title: Text(
                            item.instruction, 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            dateStr,
                            style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
                          ),
                          leading: IconButton(
                            icon: Icon(
                              item.isFavorite ? Icons.star : Icons.star_border,
                              color: item.isFavorite ? Colors.orange : theme.colorScheme.outline,
                            ),
                            onPressed: () => ref.read(historyProvider.notifier).toggleFavorite(item.id),
                          ),
                          onTap: () {
                            onRestore(item.result); // 恢复 Prompt
                            Navigator.pop(context); // 关闭抽屉
                          },
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextButton.icon(
              onPressed: () {
                 // 确认清空逻辑可以加在这里
                 ref.read(historyProvider.notifier).clearAll();
              }, 
              icon: const Icon(Icons.delete_sweep), 
              label: const Text("清空历史")
            ),
          )
        ],
      ),
    );
  }
}