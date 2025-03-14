import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';

class ChatBubble extends StatefulWidget {
  final String userRole;
  final String username;

  const ChatBubble({
    required this.userRole,
    required this.username,
    Key? key
  }) : super(key: key);

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool isExpanded = false;
  final List<types.Message> _messages = [];
  final _user = const types.User(id: '1');

  void _handleSendPressed(types.PartialText message) {
    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text,
    );

    setState(() {
      _messages.insert(0, textMessage);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (isExpanded)
          Positioned(
            right: 20,
            bottom: 80,
            child: Container(
              width: 350,
              height: 500,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Lab Assistant',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.white),
                          onPressed: () => setState(() => isExpanded = false),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Chat(
                      messages: _messages,
                      onSendPressed: _handleSendPressed,
                      user: _user,
                      theme: const DefaultChatTheme(
                        primaryColor: Colors.blue,
                        backgroundColor: Colors.white,
                        inputBackgroundColor: Color(0xFFEEEEEE),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            onPressed: () => setState(() => isExpanded = !isExpanded),
            backgroundColor: Colors.blue,
            child: const Icon(Icons.chat_bubble_outline),
          ),
        ),
      ],
    );
  }
}