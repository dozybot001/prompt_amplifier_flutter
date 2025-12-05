import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 定义设置数据模型
class AppSettings {
  final String apiKey;
  final String baseUrl;
  final String modelName;

  AppSettings({
    this.apiKey = '',
    this.baseUrl = '', // 例如 https://api.deepseek.com/v1
    this.modelName = '', // 例如 deepseek-chat
  });

  AppSettings copyWith({String? apiKey, String? baseUrl, String? modelName}) {
    return AppSettings(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      modelName: modelName ?? this.modelName,
    );
  }
}

// 状态通知器
class SettingsNotifier extends StateNotifier<AppSettings> {
  final _storage = const FlutterSecureStorage();

  SettingsNotifier() : super(AppSettings()) {
    _loadSettings();
  }

  // 加载设置
  Future<void> _loadSettings() async {
    final key = await _storage.read(key: 'api_key') ?? '';
    final url = await _storage.read(key: 'base_url') ?? '';
    final model = await _storage.read(key: 'model_name') ?? '';
    state = AppSettings(apiKey: key, baseUrl: url, modelName: model);
  }

  // 保存设置
  Future<void> saveSettings({String? apiKey, String? baseUrl, String? modelName}) async {
    if (apiKey != null) await _storage.write(key: 'api_key', value: apiKey);
    if (baseUrl != null) await _storage.write(key: 'base_url', value: baseUrl);
    if (modelName != null) await _storage.write(key: 'model_name', value: modelName);

    state = state.copyWith(apiKey: apiKey, baseUrl: baseUrl, modelName: modelName);
  }
}

// 全局 Provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});