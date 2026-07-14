class GeminiChatMessage {
  final String role;
  final String text;

  const GeminiChatMessage({
    required this.role,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'parts': [
          {'text': text},
        ],
      };
}

class PaperContextBlock {
  final String paperText;
  final String? board;
  final String? className;
  final String? subject;
  final String? year;

  const PaperContextBlock({
    required this.paperText,
    this.board,
    this.className,
    this.subject,
    this.year,
  });

  String toSystemPrompt() {
    final metadata = <String>[
      if (board != null) 'Board: $board',
      if (className != null) 'Class: $className',
      if (subject != null) 'Subject: $subject',
      if (year != null) 'Year: $year',
    ].join(' | ');

    return '''
You are IlmAI, an expert virtual teacher specializing in the Pakistani Board Examination pattern. The user is asking a question directly grounded in the following reference paper text: [INSERT EXTRACTED PAST PAPER TEXT/METADATA].
${metadata.isEmpty ? '' : 'Metadata: $metadata'}
Reference Paper Text:
$paperText

Formulate a highly structured, accurate response prioritizing Section A (MCQs), Section B (Short Questions), or Section C (Long Detailed Answers) format as requested.
''';
  }
}

class GeminiChatPayload {
  final String model;
  final String? systemInstruction;
  final List<GeminiChatMessage> messages;

  const GeminiChatPayload({
    required this.model,
    required this.messages,
    this.systemInstruction,
  });

  Map<String, dynamic> toJson() => {
        'model': model,
        if (systemInstruction != null) 'system_instruction': {'parts': [{'text': systemInstruction}]},
        'contents': messages.map((message) => message.toJson()).toList(),
      };
}
