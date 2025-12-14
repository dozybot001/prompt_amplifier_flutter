import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart'; // 必须引入 Dio 以使用 CancelToken
import 'api_service.dart';
import 'app_strings.dart';
import 'models.dart';
import 'history_service.dart';

// ==========================================
// 1. 设置模块 (Settings)
// ==========================================
class AppSettings {
  final String apiKey;
  final String baseUrl;
  final String modelName;
  final String language;

  AppSettings({
    this.apiKey = '',
    this.baseUrl = '',
    this.modelName = '',
    this.language = AppStrings.langCN,
  });

  AppSettings copyWith({String? apiKey, String? baseUrl, String? modelName, String? language}) {
    return AppSettings(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      modelName: modelName ?? this.modelName,
      language: language ?? this.language,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  final _storage = const FlutterSecureStorage();
  static const _kApiKey = 'api_key';
  static const _kBaseUrl = 'base_url';
  static const _kModelName = 'model_name';
  static const _kLanguage = 'language';

  // 构造函数保持纯净，不自动加载
  SettingsNotifier() : super(AppSettings());

  // 公开加载方法，供 main.dart 在启动前调用
  Future<void> loadSettings() async {
    final key = await _storage.read(key: _kApiKey) ?? '';
    final url = await _storage.read(key: _kBaseUrl) ?? '';
    final model = await _storage.read(key: _kModelName) ?? '';
    final lang = await _storage.read(key: _kLanguage) ?? AppStrings.langCN;
    state = AppSettings(apiKey: key, baseUrl: url, modelName: model, language: lang);
  }

  Future<void> saveSettings({String? apiKey, String? baseUrl, String? modelName, String? language}) async {
    if (apiKey != null) await _storage.write(key: _kApiKey, value: apiKey);
    if (baseUrl != null) await _storage.write(key: _kBaseUrl, value: baseUrl);
    if (modelName != null) await _storage.write(key: _kModelName, value: modelName);
    if (language != null) await _storage.write(key: _kLanguage, value: language);
    
    state = state.copyWith(
      apiKey: apiKey,
      baseUrl: baseUrl,
      modelName: modelName,
      language: language,
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier());


// ==========================================
// 2. 编辑器模块 (Editor)
// ==========================================

enum LoadingAction { none, analyzing, generatingMore, synthesizing }

class EditorState {
  final LoadingAction loadingAction;
  final String? resultText;
  final List<WizardDimension>? wizardSteps;

  bool get isLoading => loadingAction != LoadingAction.none;

  EditorState({
    this.loadingAction = LoadingAction.none,
    this.resultText,
    this.wizardSteps,
  });

  EditorState copyWith({LoadingAction? loadingAction, String? resultText, List<WizardDimension>? wizardSteps}) {
    return EditorState(
      loadingAction: loadingAction ?? this.loadingAction,
      resultText: resultText ?? this.resultText,
      wizardSteps: wizardSteps ?? this.wizardSteps,
    );
  }
}

class EditorNotifier extends StateNotifier<EditorState> {
  final Ref ref;
  
  // 用于控制请求取消的 Token
  CancelToken? _cancelToken;

  EditorNotifier(this.ref) : super(EditorState());

  // === 1. 分析指令 ===
  Future<void> analyzeInstruction(String instruction) async {
    if (instruction.trim().isEmpty) return;
    _checkApiKey();
    state = state.copyWith(loadingAction: LoadingAction.analyzing, wizardSteps: null, resultText: null);
    try {
      final steps = await _fetchOptions(instruction);
      state = state.copyWith(loadingAction: LoadingAction.none, wizardSteps: steps);
    } catch (e) {
      state = state.copyWith(loadingAction: LoadingAction.none);
      rethrow;
    }
  }

  // === 2. 选中选项 ===
  void selectWizardOption(WizardDimension step, String? option) {
    if (state.wizardSteps == null) return;
    final newSteps = state.wizardSteps!.map((s) {
      if (s.title == step.title) {
        // 如果是取消选中
        if (option == null || option.isEmpty) return s.copyWith(selected: null);
        // 如果点击的是已选中的 Tag，则反选
        if (s.options.contains(option) && s.selected == option) return s.copyWith(selected: null);
        // 选中新值
        return s.copyWith(selected: option);
      }
      return s;
    }).toList();
    state = state.copyWith(wizardSteps: newSteps);
  }

  // === 3. 生成更多维度 ===
  Future<void> generateMoreDimensions(String instruction) async {
    _checkApiKey();
    state = state.copyWith(loadingAction: LoadingAction.generatingMore);
    try {
      final currentSteps = state.wizardSteps ?? [];
      final List<String> existingTitles = currentSteps.map((e) => e.title).toList();
      final newSteps = await _fetchOptions(instruction, excludedTitles: existingTitles);

      final uniqueNewSteps = newSteps.where((newStep) {
        return !currentSteps.any((oldStep) => oldStep.title == newStep.title);
      }).toList();

      if (uniqueNewSteps.isEmpty) throw Exception("AI 未能发现更多新维度，请尝试修改原始指令");

      state = state.copyWith(loadingAction: LoadingAction.none, wizardSteps: [...currentSteps, ...uniqueNewSteps]);
    } catch (e) {
      state = state.copyWith(loadingAction: LoadingAction.none);
      rethrow;
    }
  }

  // === 4. 添加自定义字段 ===
  void addCustomDimension() {
    final currentSteps = state.wizardSteps ?? [];
    final newStep = WizardDimension(title: "自定义额外要求 ${currentSteps.length + 1}", options: [], selected: "");
    state = state.copyWith(wizardSteps: [...currentSteps, newStep]);
  }

  // === 5. 删除字段 ===
  void removeDimension(WizardDimension step) {
    if (state.wizardSteps == null) return;
    final newSteps = state.wizardSteps!.where((s) => s != step).toList();
    state = state.copyWith(wizardSteps: newSteps);
  }

  // === 6. 强制停止生成 ===
  void stopGeneration() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel("用户手动停止"); 
    }
    // 强制将 Loading 状态置空，UI 恢复可交互
    state = state.copyWith(loadingAction: LoadingAction.none);
  }

  // lib/state.dart -> EditorNotifier
  void restoreResult(String text) {
    state = state.copyWith(
      resultText: text,
      loadingAction: LoadingAction.none, // 确保不在 loading 状态
    );
  }
  
  // === 7. 合成 Prompt (流式 + 可取消) ===
  Future<void> synthesizeFinalResult(String instruction) async {
    if (state.wizardSteps == null) return;
    _checkApiKey();
    
    // 初始化 Token
    _cancelToken = CancelToken();
    
    // 状态更新：进入 synthesizing 状态
    state = state.copyWith(loadingAction: LoadingAction.synthesizing, resultText: ""); 
    
    try {
      final settings = ref.read(settingsProvider);

      final selectedOptions = state.wizardSteps!
          .where((s) => s.selected != null && s.selected!.trim().isNotEmpty)
          .map((s) {
        final cleanValue = s.selected!.replaceAll('\n', ' ').trim();
        return "${s.title}: $cleanValue";
      }).toList();

      // 调用流式 API，传入 CancelToken
      final stream = aiServiceProvider.synthesizePromptStream(
        apiKey: settings.apiKey,
        baseUrl: settings.baseUrl,
        model: settings.modelName,
        originalInstruction: instruction,
        selectedOptions: selectedOptions,
        cancelToken: _cancelToken, // 关键：传入 Token
      );

      // ... 前面的 stream 处理循环 ...
      await for (final chunk in stream) {
        final currentText = state.resultText ?? "";
        state = state.copyWith(resultText: currentText + chunk);
      }
      
      // ✅ 新增：生成完成后，自动保存到历史记录
      if (state.resultText != null && state.resultText!.isNotEmpty) {
        ref.read(historyProvider.notifier).addRecord(instruction, state.resultText!);
      }

      // 正常结束
      state = state.copyWith(loadingAction: LoadingAction.none);
      
    } catch (e) {
      // 修复：先判断是否为 DioException，再调用 isCancel
      if (e is DioException && CancelToken.isCancel(e)) {
        // 用户手动停止，不需要抛出错误，已经在 stopGeneration 里处理了状态
        return;
      }
      
      // 其他错误则抛出
      state = state.copyWith(loadingAction: LoadingAction.none);
      rethrow;
    } finally {
      // 清理 Token
      _cancelToken = null;
    }
  }
  
  // === 8. 重置 ===
  void reset() {
    stopGeneration(); // 重置时如果正在生成，先停止
    state = EditorState();
  }

  // === 内部辅助 ===
  void _checkApiKey() {
    final settings = ref.read(settingsProvider);
    if (settings.apiKey.isEmpty) throw Exception(AppStrings.get('apiKeyError', settings.language));
  }

  Future<List<WizardDimension>> _fetchOptions(String instruction, {List<String>? excludedTitles}) {
    final settings = ref.read(settingsProvider);
    return aiServiceProvider.generateOptions(
      apiKey: settings.apiKey,
      baseUrl: settings.baseUrl,
      userInstruction: instruction,
      model: settings.modelName,
      excludedTitles: excludedTitles,
    );
  }
}

final editorProvider = StateNotifierProvider<EditorNotifier, EditorState>((ref) => EditorNotifier(ref));