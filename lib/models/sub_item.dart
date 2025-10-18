class SubItem {
  final String id;
  final String name;
  final double amount;
  final String? description;
  final bool isCompleted;
  final String frequency; // 'once', 'weekly', 'monthly'
  final String? startDate; // ISO date string (yyyy-MM-dd) indicating when the sub-item starts

  SubItem({
    required this.id,
    required this.name,
    required this.amount,
    this.description,
    this.isCompleted = false,
    this.frequency = 'once',
    this.startDate,
  });

  SubItem copyWith({
    String? id,
    String? name,
    double? amount,
    String? description,
    bool? isCompleted,
    String? frequency,
    String? startDate,
  }) {
    return SubItem(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
    );
  }

  // Convert to Map for storage
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'description': description,
    'is_completed': isCompleted ? 1 : 0, // Store as integer in SQLite
    'frequency': frequency,
    'start_date': startDate,
  };

  // Create from Map
  factory SubItem.fromMap(Map<String, dynamic> map) => SubItem(
    id: map['id'] as String,
    name: map['name'] as String,
    amount: (map['amount'] as num).toDouble(),
    description: map['description'] as String?,
    isCompleted: (map['is_completed'] as int) == 1,
    frequency: map['frequency'] as String? ?? 'once',
    startDate: map['start_date'] as String?,
  );

  // For JSON serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'description': description,
    'isCompleted': isCompleted,
    'frequency': frequency,
    'start_date': startDate,
  };

  factory SubItem.fromJson(Map<String, dynamic> json) => SubItem(
    id: json['id'] as String,
    name: json['name'] as String,
    amount: (json['amount'] as num).toDouble(),
    description: json['description'] as String?,
    isCompleted: json['isCompleted'] as bool? ?? false,
    frequency: json['frequency'] as String? ?? 'once',
    startDate: json['start_date'] as String?,
  );
}
