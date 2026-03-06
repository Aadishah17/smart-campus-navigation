import 'package:flutter/material.dart';

import '../models/assistant_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.text, required this.role, super.key});

  final String text;
  final MessageRole role;

  @override
  Widget build(BuildContext context) {
    final isUser = role == MessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 6, bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF152026),
                border: Border.all(color: const Color(0x445FD1C5)),
              ),
              child: const Icon(Icons.smart_toy_rounded, size: 14),
            ),
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              gradient: isUser
                  ? const LinearGradient(
                      colors: [Color(0xFF5FD1C5), Color(0xFF77E0D5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF15191D), Color(0xFF101417)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isUser
                    ? const Color(0xAA5FD1C5)
                    : const Color(0x30FFFFFF),
              ),
            ),
            child: Text(
              text,
              style: TextStyle(color: isUser ? Colors.black : Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
