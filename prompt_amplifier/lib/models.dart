// lib/models.dart
class WizardDimension {
  final String title;
  final List<String> options;
  String? selected;

  WizardDimension({required this.title, required this.options, this.selected});

  WizardDimension copyWith({String? title, List<String>? options, String? selected}) {
    return WizardDimension(
      title: title ?? this.title,
      options: options ?? this.options,
      selected: selected ?? this.selected,
    );
  }
}

// lib/models.dart (追加到文件底部)

class HistoryRecord {
  final String id;
  final String instruction; // 原始指令
  final String result;      // 生成的 Prompt
  final int timestamp;
  final bool isFavorite;

  HistoryRecord({
    required this.id,
    required this.instruction,
    required this.result,
    required this.timestamp,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'instruction': instruction,
    'result': result,
    'timestamp': timestamp,
    'isFavorite': isFavorite,
  };

  factory HistoryRecord.fromJson(Map<String, dynamic> json) => HistoryRecord(
    id: json['id'] as String,
    instruction: json['instruction'] as String,
    result: json['result'] as String,
    timestamp: json['timestamp'] as int,
    isFavorite: json['isFavorite'] as bool? ?? false,
  );

  HistoryRecord copyWith({bool? isFavorite}) {
    return HistoryRecord(
      id: id,
      instruction: instruction,
      result: result,
      timestamp: timestamp,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}