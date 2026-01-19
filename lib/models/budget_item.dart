import 'sub_item.dart';

class BudgetItem {
  final String id;
  final String name;

  /// Frequency: 'once', 'weekly', 'monthly'
  final String frequency;

  /// Amount for repeating or one-time purchases. For 'once' this is oneTimeAmount; for monthly/weekly it's the recurring amount.
  final double? amount;

  /// ISO date string (yyyy-MM-dd) indicating when weekly/monthly frequency starts, or when a one-time purchase occurs.
  final String? startDate;

  /// Whether this budget item supports sub-items
  final bool hasSubItems;

  /// Whether this item is a saving (retained money) rather than an expense (consumed money)
  /// Savings are not deducted from the budget but tracked separately
  final bool isSaving;

  /// List of sub-items for this budget item
  List<SubItem> subItems;

  BudgetItem({
    required this.id,
    required this.name,
    this.frequency = 'once',
    this.amount,
    this.startDate,
    this.hasSubItems = false,
    this.isSaving = false,
    List<SubItem>? subItems,
  }) : subItems = List<SubItem>.from(subItems ?? <SubItem>[]);

  BudgetItem copyWith({
    String? id,
    String? name,
    String? frequency,
    double? amount,
    String? startDate,
    bool? hasSubItems,
    bool? isSaving,
    List<SubItem>? subItems,
  }) {
    return BudgetItem(
      id: id ?? this.id,
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      amount: amount ?? this.amount,
      startDate: startDate ?? this.startDate,
      hasSubItems: hasSubItems ?? this.hasSubItems,
      isSaving: isSaving ?? this.isSaving,
      subItems: subItems ?? this.subItems,
    );
  }

  // Convert to Map for SQLite
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'frequency': frequency,
    'amount': amount,
    'start_date': startDate,
    'has_sub_items': hasSubItems ? 1 : 0,
    'is_saving': isSaving ? 1 : 0,
  };

  // Create from SQLite row
  factory BudgetItem.fromMap(Map<String, dynamic> map) => BudgetItem(
    id: map['id'] as String,
    name: map['name'] as String,
    frequency: map['frequency'] as String? ?? 'once',
    amount: (map['amount'] as num?)?.toDouble(),
    startDate: map['start_date'] as String?,
    hasSubItems: (map['has_sub_items'] as int?) == 1,
    isSaving: (map['is_saving'] as int?) == 1,
    subItems: [], // Sub-items will be loaded separately
  );

  // For backwards compatibility and JSON serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'frequency': frequency,
    'amount': amount,
    'start_date': startDate,
    'has_sub_items': hasSubItems,
    'is_saving': isSaving,
    'subItems': subItems.map((e) => e.toJson()).toList(),
  };

  factory BudgetItem.fromJson(Map<String, dynamic> json) => BudgetItem(
    id: json['id'] as String,
    name: json['name'] as String,
    frequency: json['frequency'] as String? ?? 'once',
    amount: (json['amount'] as num?)?.toDouble(),
    startDate: json['start_date'] as String?,
    hasSubItems: json['has_sub_items'] as bool? ?? false,
    isSaving: json['is_saving'] as bool? ?? false,
    subItems:
        (json['subItems'] as List<dynamic>?)
            ?.map((e) => SubItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        <SubItem>[],
  );
}