class BudgetItem {
  final String id;
  final String name;

  /// Frequency: 'once', 'weekly', 'monthly'
  final String frequency;

  /// Amount for repeating or one-time purchases. For 'once' this is oneTimeAmount; for monthly/weekly it's the recurring amount.
  final double? amount;

  /// ISO date string (yyyy-MM-dd) indicating when weekly/monthly frequency starts, or when a one-time purchase occurs.
  final String? startDate;

  BudgetItem({
    required this.id,
    required this.name,
    this.frequency = 'once',
    this.amount,
    this.startDate,
  });

  BudgetItem copyWith({
    String? id,
    String? name,
    String? frequency,
    double? amount,
    String? startDate,
  }) {
    return BudgetItem(
      id: id ?? this.id,
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      amount: amount ?? this.amount,
      startDate: startDate ?? this.startDate,
    );
  }

  // Convert to Map for SQLite
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'frequency': frequency,
    'amount': amount,
    'start_date': startDate,
  };

  // Create from SQLite row
  factory BudgetItem.fromMap(Map<String, dynamic> map) => BudgetItem(
    id: map['id'] as String,
    name: map['name'] as String,
    frequency: map['frequency'] as String? ?? 'once',
    amount: (map['amount'] as num?)?.toDouble(),
    startDate: map['start_date'] as String?,
  );

  // For backwards compatibility and JSON serialization
  Map<String, dynamic> toJson() => toMap();

  factory BudgetItem.fromJson(Map<String, dynamic> json) => BudgetItem(
    id: json['id'] as String,
    name: json['name'] as String,
    frequency: json['frequency'] as String? ?? 'once',
    amount: (json['amount'] as num?)?.toDouble(),
    startDate: json['startDate'] as String?,
  );
}
