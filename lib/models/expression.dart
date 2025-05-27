class Expression {
  final int id;
  final String title;
  final String description;
  final DateTime createdAt;

  Expression({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  factory Expression.fromJson(Map<String, dynamic> json) {
    return Expression(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class ExpressionResponse {
  final int count;
  final String? next;
  final String? previous;
  final List<Expression> results;

  ExpressionResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory ExpressionResponse.fromJson(Map<String, dynamic> json) {
    return ExpressionResponse(
      count: json['count'],
      next: json['next'],
      previous: json['previous'],
      results: (json['results'] as List)
          .map((item) => Expression.fromJson(item))
          .toList(),
    );
  }
} 