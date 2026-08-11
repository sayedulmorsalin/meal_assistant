import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mess_management/services/database_service.dart';
import 'package:mess_management/services/auth_service.dart';
import 'package:mess_management/models/message_model.dart';
import 'package:mess_management/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerMessaging extends StatefulWidget {
  const ManagerMessaging({super.key});

  @override
  State<ManagerMessaging> createState() => _ManagerMessagingState();
}

class _ManagerMessagingState extends State<ManagerMessaging> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _messageController.addListener(() {
      setState(() {});
    });
  }

  void _loadUser() async {
    String? uid = _authService.currentUid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _user = UserModel.fromMap(doc.data()!);
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) async {
    if (text.isEmpty || _user == null || _user!.messId == null) return;
    
    final message = MessageModel(
      id: FirebaseFirestore.instance.collection('messes').doc().id,
      senderId: _user!.uid,
      senderName: _user!.name,
      text: text,
      timestamp: DateTime.now(),
    );

    await _dbService.sendMessage(_user!.messId!, message);
    _messageController.clear();
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _sendImage(ImageSource source) async {
    if (_user == null || _user!.messId == null) return;
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile == null) return;

      setState(() => _isLoading = true);
      String imageUrl = await _dbService.uploadChatImage(File(pickedFile.path), _user!.messId!);

      final message = MessageModel(
        id: FirebaseFirestore.instance.collection('messes').doc().id,
        senderId: _user!.uid,
        senderName: _user!.name,
        text: '',
        imageUrl: imageUrl,
        timestamp: DateTime.now(),
      );

      await _dbService.sendMessage(_user!.messId!, message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send image: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async => _sendImage(ImageSource.gallery);
  Future<void> _takePhoto() async => _sendImage(ImageSource.camera);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_user == null || _user!.messId == null) return const Scaffold(body: Center(child: Text("Error: Not in a mess")));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _dbService.getMessages(_user!.messId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("Start the conversation!"));
                }
                final messages = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(messages[index]);
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message) {
    final isMe = message.senderId == _user!.uid;
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
              color: isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                if (message.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    child: Image.network(
                      message.imageUrl!,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isMe ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7) : Theme.of(context).colorScheme.onSurfaceVariant,
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
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.outline),
            onPressed: _takePhoto, // Now functional
          ),
          IconButton(
            icon: Icon(Icons.image, color: Theme.of(context).colorScheme.outline),
            onPressed: _pickImage,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.send,
              color: _messageController.text.isEmpty
                  ? Theme.of(context).colorScheme.outline
                  : Theme.of(context).colorScheme.primary,
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

