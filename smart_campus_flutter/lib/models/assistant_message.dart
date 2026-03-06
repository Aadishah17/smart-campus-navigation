enum MessageRole { user, assistant }

class AssistantMessage {
  const AssistantMessage({required this.role, required this.content});

  final MessageRole role;
  final String content;
}
