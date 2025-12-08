import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';
import 'app_strings.dart';
import 'models.dart'; 

// ==========================================
// 1. 设置模块 (Settings)
// ==========================================
class AppSettings {
  final String apiKey;
  final String baseUrl;
  final String modelName;
  final String language;
  AppSettings({this.apiKey = '', this.baseUrl = '', this.modelName = '', this.language = AppStrings.langCN});
  AppSettings copyWith({String? apiKey, String? baseUrl, String? modelName, String? language}) {
    return AppSettings(apiKey: apiKey ?? this.apiKey, baseUrl: baseUrl ?? this.baseUrl, modelName: modelName ?? this.modelName, language: language ?? this.language);
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  final _storage = const FlutterSecureStorage();
  static const _kApiKey = 'api_key';
  static const _kBaseUrl = 'base_url';
  static const _kModelName = 'model_name';
  static const _kLanguage = 'language';

  SettingsNotifier() : super(AppSettings()) { _loadSettings(); }

  Future<void> _loadSettings() async {
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
    state = state.copyWith(apiKey: apiKey, baseUrl: baseUrl, modelName: modelName, language: language);
  }
}
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier());


// ==========================================
// 2. 编辑器模块 (Editor)
// ==========================================

// 注意：WizardDimension 类已被移除，现在通过 import 'models.dart' 引入

enum LoadingAction { none, analyzing, generatingMore, synthesizing }

class EditorState {
  final LoadingAction loadingAction;
  final String? resultText;
  final List<WizardDimension>? wizardSteps;

  bool get isLoading => loadingAction != LoadingAction.none;

  EditorState({this.loadingAction = LoadingAction.none, this.resultText, this.wizardSteps});

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

  EditorNotifier(this.ref) : super(EditorState());

  // 1. 分析指令
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

  // 2. 选中选项
  void selectWizardOption(WizardDimension step, String? option) {
    if (state.wizardSteps == null) return;
    final newSteps = state.wizardSteps!.map((s) {
      if (s.title == step.title) {
        if (option == null || option.isEmpty) return s.copyWith(selected: null);
        if (s.options.contains(option) && s.selected == option) return s.copyWith(selected: null);
        return s.copyWith(selected: option);
      }
      return s;
    }).toList();
    state = state.copyWith(wizardSteps: newSteps);
  }

  // 3. 生成更多维度
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

  // 4. 添加自定义字段
  void addCustomDimension() {
    final currentSteps = state.wizardSteps ?? [];
    final newStep = WizardDimension(title: "自定义额外要求 ${currentSteps.length + 1}", options: [], selected: "");
    state = state.copyWith(wizardSteps: [...currentSteps, newStep]);
  }

  // 5. 删除字段
  void removeDimension(WizardDimension step) {
    if (state.wizardSteps == null) return;
    final newSteps = state.wizardSteps!.where((s) => s != step).toList();
    state = state.copyWith(wizardSteps: newSteps);
  }

  // 6. 合成 Prompt
  Future<void> synthesizeFinalResult(String instruction) async {
    if (state.wizardSteps == null) return;
    _checkApiKey();
    state = state.copyWith(loadingAction: LoadingAction.synthesizing, resultText: null);
    try {
      final settings = ref.read(settingsProvider);

      final selectedOptions = state.wizardSteps!
          .where((s) => s.selected != null && s.selected!.trim().isNotEmpty)
          .map((s) {
        final cleanValue = s.selected!.replaceAll('\n', ' ').trim();
        return "${s.title}: $cleanValue";
      })
          .toList();

      final finalPrompt = await aiServiceProvider.synthesizePrompt(
        apiKey: settings.apiKey,
        baseUrl: settings.baseUrl,
        model: settings.modelName,
        originalInstruction: instruction,
        selectedOptions: selectedOptions,
      );
      state = state.copyWith(loadingAction: LoadingAction.none, resultText: finalPrompt);
    } catch (e) {
      state = state.copyWith(loadingAction: LoadingAction.none);
      rethrow;
    }
  }

  // 7. 重置
  void reset() {
    state = EditorState();
  }

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