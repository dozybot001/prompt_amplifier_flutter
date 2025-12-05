import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/ai_service.dart';
import '../../settings/providers/settings_provider.dart';

class WizardDimension {
  final String title; // 标题，例如 "您想爬取哪类数据？"
  final List<String> options; // 选项，例如 ["静态文本", "动态加载(Ajax)", "需要登录"]
  String? selected; // 用户选中的那个

  WizardDimension({required this.title, required this.options, this.selected});
}

// 1. 状态增加一个 isLoading 字段
// 修改 EditorState，增加 wizardDimensions 字段
class EditorState {
  final String role;
  final String task;
  final String context;
  final String format;
  final bool isLoading;
  final String? resultText;

  // 新增：AI 生成的引导选项列表
  final List<WizardDimension>? wizardSteps;

  EditorState({
    this.role = '',
    this.task = '',
    this.context = '',
    this.format = '',
    this.isLoading = false,
    this.resultText,
    this.wizardSteps,
  });

  EditorState copyWith({
    String? role,
    String? task,
    String? context,
    String? format,
    bool? isLoading,
    String? resultText,
    List<WizardDimension>? wizardSteps,
  }) {
    return EditorState(
      role: role ?? this.role,
      task: task ?? this.task,
      context: context ?? this.context,
      format: format ?? this.format,
      isLoading: isLoading ?? this.isLoading,
      resultText: resultText ?? this.resultText,
      wizardSteps: wizardSteps ?? this.wizardSteps,
    );
  }

  // 拼接预览文本：如果有 AI 结果则显示 AI 的，否则显示手动拼接的
  String get displayContent {
    if (resultText != null && resultText!.isNotEmpty) return resultText!;

    // 手动拼接逻辑
    if (role.isEmpty && task.isEmpty) return '请在左侧输入内容...';
    return '''
# Role
$role

# Task
$task

# Context
$context

# Output Format
$format
''';
  }
}

// 2. Notifier 增加调用 AI 的方法
class EditorNotifier extends StateNotifier<EditorState> {
  final Ref ref; // 需要 Ref 来读取 SettingsProvider

  EditorNotifier(this.ref) : super(EditorState());

  void updateRole(String val) => state = state.copyWith(role: val, resultText: null); // 修改输入时清空AI结果
  void updateTask(String val) => state = state.copyWith(task: val, resultText: null);
  void updateContext(String val) => state = state.copyWith(context: val, resultText: null);
  void updateFormat(String val) => state = state.copyWith(format: val, resultText: null);

  // 核心：调用 AI 放大
  Future<void> amplify() async {
    // 1. 读取配置
    final settings = ref.read(settingsProvider);
    if (settings.apiKey.isEmpty) {
      throw Exception('请先在设置页配置 API Key');
    }

    // 2. 设置加载状态
    state = state.copyWith(isLoading: true);

    try {
      // 3. 调用 API
      final result = await aiServiceProvider.amplifyPrompt(
        apiKey: settings.apiKey,
        baseUrl: settings.baseUrl,
        model: settings.modelName,
        originalPrompt: state.displayContent, // 把当前拼好的草稿发给 AI
      );

      // 4. 更新结果
      state = state.copyWith(resultText: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow; // 抛出错误给 UI 层处理
    }
  }

  // 1. 分析简单指令
  Future<void> analyzeInstruction(String instruction) async {
    if (instruction.isEmpty) return;

    final settings = ref.read(settingsProvider);
    state = state.copyWith(isLoading: true);

    try {
      // 这里的 generateOptions 需要你去 ai_service 实现，返回 List<Map>
      // 假设解析出来的数据结构如下：
      final rawOptions = await aiServiceProvider.generateOptions(
        apiKey: settings.apiKey,
        baseUrl: settings.baseUrl,
        userInstruction: instruction,
        model: settings.modelName,
      );

      // 转换为 WizardDimension 对象
      final steps = rawOptions.map((item) => WizardDimension(
        title: item['title'],
        options: List<String>.from(item['options']),
      )).toList();

      state = state.copyWith(isLoading: false, wizardSteps: steps);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      // 处理错误
    }
  }

  // 2. 用户点击选项
  void selectWizardOption(WizardDimension step, String option) {
    // 找到当前修改的步骤索引
    final newSteps = state.wizardSteps!.map((s) {
      if (s == step) {
        s.selected = option; // 直接修改对象(简单做法) 或者创建新对象
      }
      return s;
    }).toList();

    // 强制触发更新
    state = state.copyWith(wizardSteps: [...newSteps]);
  }

  // 3. 将选项填入表单 (生成结构化 Prompt)
  void applyWizardToForm() {
    if (state.wizardSteps == null) return;

    // 简单的拼接逻辑：把选中的选项组合成 Context 或 Task
    final selectedOptions = state.wizardSteps!
        .where((s) => s.selected != null)
        .map((s) => "${s.title}: ${s.selected}")
        .join("\n");

    state = state.copyWith(
      // 这里可以更智能，比如根据选项内容判断是填入 Context 还是 Task
      // 简单起见，先全部追加到 Context 中
      context: selectedOptions,
      // 清空向导，或者保留
      wizardSteps: null,
    );
  }
}

// 全局 Provider
final editorProvider = StateNotifierProvider<EditorNotifier, EditorState>((ref) {
  return EditorNotifier(ref);
});