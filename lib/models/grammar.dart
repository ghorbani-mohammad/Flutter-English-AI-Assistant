class Grammar {
  final int id;
  final String title;
  final String description;
  final DateTime createdAt;

  Grammar({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  factory Grammar.fromJson(Map<String, dynamic> json) {
    return Grammar(
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

class GrammarResponse {
  final int count;
  final String? next;
  final String? previous;
  final List<Grammar> results;

  GrammarResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory GrammarResponse.fromJson(Map<String, dynamic> json) {
    return GrammarResponse(
      count: json['count'],
      next: json['next'],
      previous: json['previous'],
      results: (json['results'] as List)
          .map((item) => Grammar.fromJson(item))
          .toList(),
    );
  }
} 