import 'package:dio/dio.dart';
import 'dart:convert';

class AiService {
  final Dio _dio = Dio();

  // 构造函数里不需要任何代理配置
  AiService();

  Future<String> amplifyPrompt({
    required String apiKey,
    required String baseUrl,
    required String originalPrompt,
    required String model,
  }) async {
    // 1. 处理 Base URL (如果用户没填，默认 OpenAI，但你会填 SiliconFlow)
    String finalUrl = baseUrl.isEmpty ? 'https://api.openai.com/v1' : baseUrl;
    if (finalUrl.endsWith('/')) finalUrl = finalUrl.substring(0, finalUrl.length - 1);

    try {
      // 2. 发起请求
      final response = await _dio.post(
        '$finalUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          // SiliconFlow 速度很快，但为了保险还是给 60秒
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
        data: {
          "model": model, // 直接使用用户填写的模型名称
          "messages": [
            {
              "role": "system",
              "content": "You are a professional Prompt Engineer. Output ONLY the optimized prompt."
            },
            {
              "role": "user",
              "content": "Please amplify this prompt:\n$originalPrompt"
            }
          ],
          "temperature": 0.7,
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'];
        return content.toString().trim();
      } else {
        throw Exception('Failed with status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      // 捕获 Dio 错误，并尝试提取服务器返回的 JSON
      String errorMsg = e.message ?? '未知网络错误';

      if (e.response != null) {
        //这是最关键的：获取服务器返回的具体报错内容
        final serverData = e.response?.data;
        errorMsg = "状态码: ${e.response?.statusCode}\n错误详情: $serverData";
        print("🛑 API 报错详情: $serverData"); // 在控制台打印，方便你看
      }

      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('未知系统错误: $e');
    }
  }

  // ... 原有的 amplifyPrompt 方法保持不变

  // 新增：根据简单指令生成选项
  Future<List<Map<String, dynamic>>> generateOptions({
    required String apiKey,
    required String baseUrl,
    required String userInstruction, // 用户输入的简单指令，如"写个爬虫"
    required String model,
  }) async {
    String finalUrl = baseUrl.isEmpty ? 'https://api.openai.com/v1' : baseUrl;
    if (finalUrl.endsWith('/')) finalUrl = finalUrl.substring(0, finalUrl.length - 1);

    // 构造一个强制 JSON 格式的 Prompt
    final prompt = '''
    User wants to: "$userInstruction".
    Analyze this task and identify 3 critical aspects that need clarification to create a perfect prompt.
    For each aspect, provide a question and 3-4 professional options.
    
    RETURN ONLY JSON ARRAY with this structure (no markdown, no extra text):
    [
      {
        "title": "Question 1?",
        "options": ["Option A", "Option B", "Option C"]
      },
      ...
    ]
    ''';

    try {
      final response = await _dio.post(
        '$finalUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          "model": model,
          // 强制 JSON 模式 (DeepSeek/OpenAI 新版支持，如果报错可去掉 response_format)
          "response_format": {"type": "json_object"},
          "messages": [
            {"role": "system", "content": "You are a helpful assistant that outputs strict JSON."},
            {"role": "user", "content": prompt}
          ],
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'];
        // 这里需要引入 dart:convert 来解码
        // 简单处理：假设返回的是标准 JSON 字符串
        // 实际项目中建议加 try-catch 解析 JSON
        return List<Map<String, dynamic>>.from(jsonDecode(content)['dimensions'] ?? jsonDecode(content));
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Generate Options Failed: $e');
    }
  }
}

final aiServiceProvider = AiService();