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

  // Convert to Map for SQLite
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'monthly_amount': monthlyAmount,
    'one_time_amount': oneTimeAmount,
    'one_time_month': oneTimeMonth,
  };

  // Create from SQLite row
  factory BudgetItem.fromMap(Map<String, dynamic> map) => BudgetItem(
    id: map['id'] as String,
    name: map['name'] as String,
    monthlyAmount: (map['monthly_amount'] as num?)?.toDouble(),
    oneTimeAmount: (map['one_time_amount'] as num?)?.toDouble(),
    oneTimeMonth: map['one_time_month'] as String?,
  );

  // For backwards compatibility and JSON serialization
  Map<String, dynamic> toJson() => toMap();

  factory BudgetItem.fromJson(Map<String, dynamic> json) => BudgetItem(
    id: json['id'] as String,
    name: json['name'] as String,
    monthlyAmount: (json['monthlyAmount'] as num?)?.toDouble(),
    oneTimeAmount: (json['oneTimeAmount'] as num?)?.toDouble(),
    oneTimeMonth: json['oneTimeMonth'] as String?,
  );
}
