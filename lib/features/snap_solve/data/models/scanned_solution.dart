import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class ScannedSolution {
  final String id;
  final String imageUrl;
  final String extractedText;
  final String aiSolution;
  final String subject;
  final Timestamp timestamp;
  final String userId;

  ScannedSolution({
    String? id,
    required this.imageUrl,
    required this.extractedText,
    required this.aiSolution,
    required this.subject,
    required this.timestamp,
    required this.userId,
  }) : id = id ?? const Uuid().v4();

  factory ScannedSolution.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScannedSolution(
      id: doc.id,
      imageUrl: data['imageUrl'] as String? ?? '',
      extractedText: data['extractedText'] as String? ?? '',
      aiSolution: data['aiSolution'] as String? ?? '',
      subject: data['subject'] as String? ?? 'General',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      userId: data['userId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl,
      'extractedText': extractedText,
      'aiSolution': aiSolution,
      'subject': subject,
      'timestamp': timestamp,
      'userId': userId,
    };
  }

  ScannedSolution copyWith({
    String? id,
    String? imageUrl,
    String? extractedText,
    String? aiSolution,
    String? subject,
    Timestamp? timestamp,
    String? userId,
  }) {
    return ScannedSolution(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      extractedText: extractedText ?? this.extractedText,
      aiSolution: aiSolution ?? this.aiSolution,
      subject: subject ?? this.subject,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
    );
  }
}