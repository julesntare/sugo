class BudgetItem {
  final String id;
  final String name;

  /// Amount that repeats each month (e.g., rent, subscription). Optional.
  final double? monthlyAmount;

  /// One-time amount applied to a single month. Optional.
  final double? oneTimeAmount;

  /// Month key in format YYYY-MM when oneTimeAmount should be applied. Optional.
  final String? oneTimeMonth;

  BudgetItem({
    required this.id,
    required this.name,
    this.monthlyAmount,
    this.oneTimeAmount,
    this.oneTimeMonth,
  });

  BudgetItem copyWith({
    String? id,
    String? name,
    double? monthlyAmount,
    double? oneTimeAmount,
    String? oneTimeMonth,
  }) {
    return BudgetItem(
      id: id ?? this.id,
      name: name ?? this.name,
      monthlyAmount: monthlyAmount ?? this.monthlyAmount,
      oneTimeAmount: oneTimeAmount ?? this.oneTimeAmount,
      oneTimeMonth: oneTimeMonth ?? this.oneTimeMonth,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'monthlyAmount': monthlyAmount,
    'oneTimeAmount': oneTimeAmount,
    'oneTimeMonth': oneTimeMonth,
  };

  factory BudgetItem.fromJson(Map<String, dynamic> json) => BudgetItem(
    id: json['id'] as String,
    name: json['name'] as String,
    monthlyAmount: (json['monthlyAmount'] as num?)?.toDouble(),
    oneTimeAmount: (json['oneTimeAmount'] as num?)?.toDouble(),
    oneTimeMonth: json['oneTimeMonth'] as String?,
  );
}
