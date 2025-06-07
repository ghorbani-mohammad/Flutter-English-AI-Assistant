class ChatHistoryMessage {
  final int id;
  final String userName;
  final String displayContent;
  final String messageType; // 'text' or 'audio'
  final String senderType; // 'user' or 'ai'
  final String? audioFile;
  final double? audioDuration;
  final String formattedDate;
  final DateTime createdAt;

  ChatHistoryMessage({
    required this.id,
    required this.userName,
    required this.displayContent,
    required this.messageType,
    required this.senderType,
    this.audioFile,
    this.audioDuration,
    required this.formattedDate,
    required this.createdAt,
  });

  factory ChatHistoryMessage.fromJson(Map<String, dynamic> json) {
    return ChatHistoryMessage(
      id: json['id'],
      userName: json['user_name'],
      displayContent: json['display_content'],
      messageType: json['message_type'],
      senderType: json['sender_type'],
      audioFile: json['audio_file'],
      audioDuration: json['audio_duration']?.toDouble(),
      formattedDate: json['formatted_date'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_name': userName,
      'display_content': displayContent,
      'message_type': messageType,
      'sender_type': senderType,
      'audio_file': audioFile,
      'audio_duration': audioDuration,
      'formatted_date': formattedDate,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isUser => senderType == 'user';
  bool get isAi => senderType == 'ai';
  bool get isTextMessage => messageType == 'text';
  bool get isAudioMessage => messageType == 'audio';
}

class ChatHistoryResponse {
  final int count;
  final String? next;
  final String? previous;
  final List<ChatHistoryMessage> results;

  ChatHistoryResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory ChatHistoryResponse.fromJson(Map<String, dynamic> json) {
    return ChatHistoryResponse(
      count: json['count'],
      next: json['next'],
      previous: json['previous'],
      results: (json['results'] as List)
          .map((item) => ChatHistoryMessage.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'next': next,
      'previous': previous,
      'results': results.map((item) => item.toJson()).toList(),
    };
  }
} 