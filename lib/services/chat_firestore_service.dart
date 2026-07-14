import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class ChatSessionModel {
  final String id;
  final String title;
  final DateTime createdAt;

  ChatSessionModel({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  factory ChatSessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatSessionModel(
      id: doc.id,
      title: data['title'] ?? 'New Conversation',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ChatMessageModel {
  final String id;
  final String sender;
  final String text;
  final String? imageUrl;
  final DateTime timestamp;

  ChatMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    this.imageUrl,
    required this.timestamp,
  });

  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessageModel(
      id: doc.id,
      sender: data['sender'] ?? 'user',
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'] as String?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ChatFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> createChat(String userId, String title) async {
    final docRef = await _db.collection('chats').add({
      'userId': userId,
      'title': title,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> deleteChat(String chatId) async {
    final messages = await _db.collection('chats').doc(chatId).collection('messages').get();
    final batch = _db.batch();
    for (var doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('chats').doc(chatId));
    await batch.commit();
  }

  Stream<List<ChatSessionModel>> getChatsStream(String userId) {
    return _db
        .collection('chats')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => ChatSessionModel.fromFirestore(doc)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<ChatMessageModel>> getMessagesStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatMessageModel.fromFirestore(doc)).toList());
  }

  Future<void> addMessage(String chatId, String sender, String text, {String? imageUrl}) async {
    await _db.collection('chats').doc(chatId).collection('messages').add({
      'sender': sender,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateChatTitle(String chatId, String newTitle) async {
    await _db.collection('chats').doc(chatId).update({
      'title': newTitle,
    });
  }
}
