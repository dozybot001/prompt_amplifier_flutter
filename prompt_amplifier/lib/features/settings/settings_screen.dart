import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // 控制器用于绑定输入框
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 初始化时读取当前 Provider 的值
    final settings = ref.read(settingsProvider);
    _apiKeyController.text = settings.apiKey;
    _baseUrlController.text = settings.baseUrl;
    _modelController.text = settings.modelName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API 设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('模型配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // API Key
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'sk-xxxxxxxx',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key),
            ),
            obscureText: true, // 隐藏 Key
          ),
          const SizedBox(height: 16),

          // Base URL
          TextField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              labelText: 'Base URL (可选)',
              hintText: '默认: https://api.openai.com/v1',
              helperText: 'DeepSeek 用户请填: https://api.deepseek.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 16),

          // Model Name
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: '模型名称 (Model)',
              hintText: '默认: gpt-3.5-turbo',
              helperText: '例如: deepseek-chat, gpt-4o',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.smart_toy),
            ),
          ),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: () {
              // 保存到本地
              ref.read(settingsProvider.notifier).saveSettings(
                apiKey: _apiKeyController.text,
                baseUrl: _baseUrlController.text,
                modelName: _modelController.text,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('设置已保存 ✅')),
              );
            },
            icon: const Icon(Icons.save),
            label: const Text('保存配置'),
          ),
        ],
      ),
    );
  }
}