import 'package:flutter/material.dart';
class Masseging extends StatefulWidget {
  const Masseging({super.key});

  @override
  State<Masseging> createState() => _MassegingState();
}

class _MassegingState extends State<Masseging> {
  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [
    Message(
      text: 'Hey, how are you?',
      sender: 'John',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    Message(
      text: 'I\'m doing great, thanks!',
      sender: 'me',
      timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
    ),
    Message(
      text: 'Any updates on the project?',
      sender: 'John',
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.isEmpty) return;
    setState(() {
      _messages.add(Message(
        text: text,
        sender: 'me',
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: false,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isMe = message.sender == 'me';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 10.0,
              horizontal: 16.0,
            ),
            decoration: BoxDecoration(
              color: isMe ? Colors.blue : Colors.grey[300],
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.grey),
            onPressed: () {
              // Implement camera functionality
              print('Open camera');
            },
          ),
          IconButton(
            icon: const Icon(Icons.image, color: Colors.grey),
            onPressed: () {
              // Implement image picker functionality
              print('Choose image');
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.send,
              color: _messageController.text.isEmpty
                  ? Colors.grey
                  : Colors.blue,
            ),
            onPressed: _messageController.text.isEmpty
                ? null
                : () => _sendMessage(_messageController.text),
          ),
        ],
      ),
    );
  }
}

class Message {
  final String text;
  final String sender;
  final DateTime timestamp;

  Message({
    required this.text,
    required this.sender,
    required this.timestamp,
  });
}

