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