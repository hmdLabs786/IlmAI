import '../models/gemini_chat_payload.dart';

class GeminiChatPayloadBuilder {
  const GeminiChatPayloadBuilder();

  GeminiChatPayload build({
    required List<GeminiChatMessage> chatHistory,
    required String userPrompt,
    PaperContextBlock? paperContext,
    String model = 'gemini-2.5-flash',
  }) {
    final messages = <GeminiChatMessage>[];

    if (paperContext != null) {
      messages.add(
        GeminiChatMessage(
          role: 'user',
          text: paperContext.toSystemPrompt(),
        ),
      );
    }

    messages.addAll(chatHistory);
    messages.add(
      GeminiChatMessage(
        role: 'user',
        text: userPrompt,
      ),
    );

    return GeminiChatPayload(
      model: model,
      systemInstruction: paperContext == null
          ? 'You are IlmAI, a helpful Pakistani board exam tutor.'
          : null,
      messages: messages,
    );
  }
}
