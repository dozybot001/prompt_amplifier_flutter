import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:async';
import 'models.dart';
import 'prompts.dart'; // 引入 Prompt 模板
import 'exceptions.dart';

class AiService {
  final Dio _dio = Dio();
  static const Duration _timeout = Duration(seconds: 180);
  AiService();

  // 1. 生成维度选项
  Future<List<WizardDimension>> generateOptions({
    required String apiKey,
    required String baseUrl,
    required String userInstruction,
    required String model,
    List<String>? excludedTitles,
  }) async {
    final String finalUrl = _prepareUrl(baseUrl);

    // 构建排除指令
    String exclusionInstruction = "";
    if (excludedTitles != null && excludedTitles.isNotEmpty) {
      exclusionInstruction = """
      【严格限制 - 绝对禁止重复】
      以下维度标题已经存在，请**完全避开**，不要生成类似的内容：
      ${excludedTitles.map((e) => '"$e"').join(', ')}
      你必须开辟全新的思考角度，生成 3 个及以上与上述列表**完全不同**的新维度。
      """;
    }

    // 使用 AppPrompts 生成 Prompt
    final prompt = AppPrompts.generateAnalysisPrompt(userInstruction, exclusionInstruction);

    try {
      final response = await _dio.post(
        '$finalUrl/chat/completions',
        options: _buildOptions(apiKey),
        data: {
          "model": model,
          "response_format": {"type": "json_object"},
          "messages": [
            {"role": "system", "content": AppPrompts.analysisSystemPrompt},
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.85, 
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'].toString();
        // 使用更安全的 cleanJson
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
      throw _handleDioError(e);
    }
  }

  // 2. 流式生成最终 Prompt
  Stream<String> synthesizePromptStream({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String originalInstruction,
    required List<String> selectedOptions,
    CancelToken? cancelToken, // ✅ 新增参数
  }) async* {
    final String finalUrl = _prepareUrl(baseUrl);
    
    // 使用 AppPrompts 生成 Prompt
    final prompt = AppPrompts.generateSynthesisPrompt(originalInstruction, selectedOptions);

    try {
      final response = await _dio.post(
        '$finalUrl/chat/completions',
        options: _buildOptions(apiKey).copyWith(responseType: ResponseType.stream),
        cancelToken: cancelToken, // ✅ 传入 CancelToken
        data: {
          "model": model,
          "messages": [
            {"role": "system", "content": AppPrompts.synthesisSystemRole},
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.7,
          "stream": true,
        },
      );

      // ... 前面的代码不变 ...

      final stream = response.data.stream
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .transform(const LineSplitter());

      await for (final String line in stream) {
        // [Debug] 打印原始数据，看看是不是一行行出来的
        // print('raw line: $line'); 

        if (line.trim().isEmpty) continue;
        
        // 1. 放宽判断：只要以 data: 开头就行，不管后面有没有空格
        if (!line.startsWith('data:')) continue;
        
        // 2. 去掉前缀 'data:' (5个字符)，然后去空格
        String data = line.substring(5).trim();
        
        if (data == '[DONE]') break;

        try {
          final json = jsonDecode(data);
          final delta = json['choices']?[0]['delta'];
          final content = delta?['content'];
          
          if (content != null) {
            // [Debug] 确认我们捕获到了内容
            print('[Stream] 收到片段: $content'); 
            yield content.toString();
          }
        } catch (e) {
          print('JSON 解析忽略: $data'); // 忽略非标准数据
          continue;
        }
      }
    } catch (e) {
      throw _handleDioError(e);
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

  /// 安全性优化：更强健的 JSON 清洗
  String _cleanJson(String raw) {
    // 1. 移除 Markdown 代码块标记 (```json 和 ```)
    raw = raw.replaceAll(RegExp(r'^```json', multiLine: true), '');
    raw = raw.replaceAll(RegExp(r'^```', multiLine: true), '');
    
    // 2. 尝试提取第一个 { 到最后一个 } 之间的内容
    final int start = raw.indexOf('{');
    final int end = raw.lastIndexOf('}');
    
    if (start != -1 && end != -1 && end > start) {
      return raw.substring(start, end + 1);
    }
    
    // 3. 如果找不到大括号，只能返回原始文本试运气
    return raw.trim();
  }

  // 将此方法添加到 AiService 类底部
  Exception _handleDioError(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        return NetworkException("请求超时，请稍后重试");
      }
      
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) {
        return AuthException();
      }
      
      final msg = e.response?.data['error']?['message'] ?? e.message;
      return ApiException("API 错误 ($statusCode): $msg");
    }
    return ApiException(e.toString());
  }
}
final aiServiceProvider = AiService();