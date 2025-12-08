import 'package:dio/dio.dart';
import 'dart:convert';
import 'state.dart';

class AiService {
  final Dio _dio = Dio();
  static const Duration _timeout = Duration(seconds: 60);
  AiService();

  Future<List<WizardDimension>> generateOptions({
    required String apiKey,
    required String baseUrl,
    required String userInstruction,
    required String model,
    List<String>? excludedTitles,
  }) async {
    final String finalUrl = _prepareUrl(baseUrl);

    String exclusionInstruction = "";
    if (excludedTitles != null && excludedTitles.isNotEmpty) {
      exclusionInstruction = """
      【严格限制 - 绝对禁止重复】
      以下维度标题已经存在，请**完全避开**，不要生成类似的内容：
      ${excludedTitles.map((e) => '"$e"').join(', ')}
      你必须开辟全新的思考角度，生成 3 个与上述列表**完全不同**的新维度。
      """;
    }

    final prompt = '''
    用户原始意图: "$userInstruction".
    $exclusionInstruction
    任务：
    1. 深入分析用户意图，寻找未被挖掘的细节。
    2. 识别出 3 个新的关键维度，用于向用户澄清需求。
    3. 为每个维度提供一个简短的问题标题和 3-4 个具体的选项。
    
    输出格式要求：
    严格输出一个包含 "dimensions" 键的 JSON 对象。不要输出 Markdown 标记，只输出纯 JSON 字符串。
    JSON 结构示例:
    { "dimensions": [ { "title": "维度?", "options": ["A", "B"] } ] }
    ''';

    try {
      final response = await _dio.post(
        '$finalUrl/chat/completions',
        options: _buildOptions(apiKey),
        data: {
          "model": model,
          "response_format": {"type": "json_object"},
          "messages": [
            {"role": "system", "content": "你是一个专业的 Prompt 顾问后端 API，只输出合法的 JSON 数据。"},
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.8,
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'].toString();
        final cleanedJson = _cleanJson(content);
        final Map<String, dynamic> jsonMap = jsonDecode(cleanedJson);

        if (jsonMap.containsKey('dimensions')) {
          final List<dynamic> list = jsonMap['dimensions'];
          return list.map((item) {
            return WizardDimension(
              title: item['title'].toString(),
              options: List<String>.from(item['options']),
            );
          }).toList();
        } else {
          throw Exception('API 返回数据格式错误: 缺少 dimensions 字段');
        }
      } else {
        throw Exception('服务器错误: ${response.statusCode}');
      }
    } catch (e) {
      // 这里的错误通常是 JSON 解析或网络问题，保留简单封装
      // print('API Error: $e');
      throw Exception('无法生成选项: $e');
    }
  }

  /// ✨ 整合最终 Prompt
  Future<String> synthesizePrompt({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String originalInstruction,
    required List<String> selectedOptions,
  }) async {
    final String finalUrl = _prepareUrl(baseUrl);

    const String systemRole = "你是一位资深的提示词工程师 (Prompt Engineer)。你的目标是根据用户的意图和选定的约束条件，编写一个结构清晰、逻辑严密、生产级的 System Prompt。";

    // 优化：更加结构化的 Prompt，防止自定义要求（可能包含特殊字符）破坏指令结构
    final prompt = '''
    # 任务指令
    根据以下信息编写高质量 System Prompt。
    
    ## 1. 用户原始意图
    "$originalInstruction"
    
    ## 2. 用户明确的约束与偏好 (必须严格遵守)
    ${selectedOptions.isEmpty ? "无额外约束" : selectedOptions.map((e) => "- $e").join('\n')}
    
    ## 编写要求
    1. 将上述约束条件自然地融合到 System Prompt 的设定中。
    2. 默认使用中文进行输出（除非用户意图明显是英文场景）。
    3. 使用专业的 Prompt 技巧（如角色扮演、思维链、分隔符等）。
    4. 仅输出最终的 System Prompt 文本，不需要任何解释、前言或 Markdown 代码块包裹。
    ''';

    try {
      final response = await _dio.post(
        '$finalUrl/chat/completions',
        options: _buildOptions(apiKey),
        data: {
          "model": model,
          "messages": [
            {"role": "system", "content": systemRole},
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.7,
        },
      );

      if (response.statusCode == 200) {
        return response.data['choices'][0]['message']['content'].toString().trim();
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.statusMessage}');
      }
    } catch (e) {
      // 移除 "整合失败" 前缀，直接抛出原始错误以便 UI 显示具体原因 (例如 400 Bad Request)
      if (e is DioException) {
        final msg = e.response?.data['error']?['message'] ?? e.message;
        throw Exception('API 请求失败: $msg');
      }
      throw Exception('$e');
    }
  }

  // === 内部辅助方法 ===
  String _prepareUrl(String baseUrl) {
    String finalUrl = baseUrl.isEmpty ? 'https://api.openai.com/v1' : baseUrl;
    if (finalUrl.endsWith('/')) finalUrl = finalUrl.substring(0, finalUrl.length - 1);
    return finalUrl;
  }

  Options _buildOptions(String apiKey) {
    return Options(
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      sendTimeout: _timeout,
      receiveTimeout: _timeout,
    );
  }

  String _cleanJson(String raw) {
    raw = raw.replaceAll(RegExp(r'^```json', multiLine: true), '');
    raw = raw.replaceAll(RegExp(r'^```', multiLine: true), '');
    return raw.trim();
  }
}
final aiServiceProvider = AiService();