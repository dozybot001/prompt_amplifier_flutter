// lib/app_strings.dart

class AppStrings {
  static const String langCN = 'zh';
  static const String langEN = 'en';

  static const Map<String, Map<String, String>> _localizedValues = {
    'zh': {
      'appTitle': 'Prompt Amplifier',
      'appSubtitle': '把想法变成专业提示词',
      'inputHint': '输入简单指令 (例如: 写个贪吃蛇)',
      'settingsTooltip': 'API 设置',
      'moreOptions': '更多选项',
      'addCustomField': '添加自定义字段',
      'customOptionHint': '或输入自定义要求...',
      'generatePrompt': '生成最终 Prompt',
      'copySuccess': '已复制到剪贴板',
      'copy': '复制 Prompt',
      'reset': '重置',
      'analyzing': 'AI 正在分析需求...',
      'synthesizing': 'AI 正在撰写提示词...',
      'loadingDimensions': 'AI 正在生成更多维度...',
      'finalPromptTitle': '✨ 生产级 Prompt',
      'deleteDimension': '删除此项', // New

      // 设置页
      'settingsTitle': 'API 设置',
      'language': '语言 / Language',
      'apiKeyHint': '请输入 API Key',
      'baseUrlHint': 'Base URL (选填)',
      'modelHint': '模型名称 (例如 deepseek-chat)',
      'save': '保存配置',
      'saveSuccess': '设置已保存',
      'apiKeyError': '请先点击右上角设置 API Key',
    },
    'en': {
      'appTitle': 'Prompt Amplifier',
      'appSubtitle': 'Turn ideas into professional prompts',
      'inputHint': 'Enter instruction (e.g., Write a snake game)',
      'settingsTooltip': 'Settings',
      'moreOptions': 'More Options',
      'addCustomField': 'Add Custom Field',
      'customOptionHint': 'Or enter custom requirement...',
      'generatePrompt': 'Generate Prompt',
      'copySuccess': 'Copied to clipboard',
      'copy': 'Copy Prompt',
      'reset': 'Reset',
      'analyzing': 'AI is analyzing requirements...',
      'synthesizing': 'AI is drafting prompt...',
      'loadingDimensions': 'AI is generating more dimensions...',
      'finalPromptTitle': '✨ Production Prompt',
      'deleteDimension': 'Remove', // New

      // Settings Screen
      'settingsTitle': 'API Settings',
      'language': 'Language / 语言',
      'apiKeyHint': 'Enter API Key',
      'baseUrlHint': 'Base URL (Optional)',
      'modelHint': 'Model Name (e.g., gpt-4)',
      'save': 'Save Configuration',
      'saveSuccess': 'Settings Saved',
      'apiKeyError': 'Please configure API Key in settings first',
    },
  };

  static String get(String key, String langCode) {
    return _localizedValues[langCode]?[key] ?? _localizedValues['zh']![key]!;
  }
}