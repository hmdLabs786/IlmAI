import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/smart_text.dart';
import '../../../../core/subscription/subscription_gate_manager.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/student_profile.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/config.dart';
import '../../../../services/chat_firestore_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatFirestoreService _chatService = ChatFirestoreService();
  final ImagePicker _imagePicker = ImagePicker();

  StreamSubscription<List<ChatMessageModel>>? _messagesSubscription;
  String? _currentChatId;
  bool _isGenerating = false;
  String _streamingText = '';
  List<ChatMessageModel> _messages = [];
  File? _selectedImage;

  static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  String get _geminiApiKey {
    if (AppConfig.geminiApiKey.isNotEmpty && AppConfig.geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE') {
      return AppConfig.geminiApiKey;
    }
    return _envApiKey;
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _selectChat(String chatId) {
    _messagesSubscription?.cancel();
    setState(() {
      _currentChatId = chatId;
      _messages = [];
      _streamingText = '';
    });
    _messagesSubscription = _chatService.getMessagesStream(chatId).listen((messages) {
      if (!mounted) return;
      setState(() => _messages = messages);
      _scrollToBottom();
    });
  }

  Future<void> _startNewChat(String userId) async {
    final title = 'New Chat ${TimeOfDay.now().format(context)}';
    final chatId = await _chatService.createChat(userId, title);
    _selectChat(chatId);
  }

  String _levelLabel(StudentLevel level) {
    switch (level) {
      case StudentLevel.developing: return 'Weak';
      case StudentLevel.average: return 'Average';
      case StudentLevel.advanced: return 'Intelligent';
    }
  }

  String _buildTutorPrompt(StudentProfile profile, String userText) {
    final dollar = '\$';
    return '''
You are IlmAI, a polished academic assistant for Pakistani board students.

Student profile:
- Class: ${profile.studentClass}
- Board: ${profile.boardName}
- Level: ${_levelLabel(profile.level)}

Instructions:
- DO NOT start with greetings like "Hello" or "Hi". Begin the answer directly.
- Answer the student's question in a structured, complete, and polished form.
- Match the explanation depth to the student's level.
- Use proper Markdown formatting: ## for headings, **bold** for emphasis.
- Prefer short sections, bullet points, examples, and exam-focused tips.
- Keep the tone supportive and clear.
- If the topic needs assumptions, state them briefly.
- When writing mathematical expressions, formulas, or equations, ALWAYS use LaTeX notation with ${dollar}...${dollar} for inline math and ${dollar}${dollar}...${dollar}${dollar} for displayed equations.
- NEVER use plain text for math symbols like using the word 'theta' or plain dollar signs for variables.
- At the end of your response, suggest 2-3 follow-up questions the student might ask next. Format them as a numbered list under a "## Follow-up Questions" heading.

Student question:
$userText
''';
  }

  bool _isPastPaperRequest(String text) {
    final keywords = [
      'past paper', 'past papers', 'pastpaper', 'solved paper', 'solution paper',
      'exam paper', 'board paper', 'previous year', 'model paper', 'guess paper',
      'solve this paper', 'check my paper', 'mark my exam', 'exam solution',
      'upload paper', 'check paper', 'paper correction', 'exam sheet',
      'past paper solution',
    ];
    final lower = text.toLowerCase();
    return keywords.any((kw) => lower.contains(kw));
  }

  void _showUpgradePrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Upgrade Required'),
          content: const Text(
            'Past paper solutions and exam sheet checking are premium features. '
            'Please upgrade your subscription to access them.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Upgrade'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go('/subscription');
              },
            ),
          ],
        );
      },
    );
  }

  String _buildTitleFromText(String text) {
    final cleaned = text.trim().replaceAll('\n', ' ');
    if (cleaned.length <= 28) return cleaned;
    return '${cleaned.substring(0, 25)}...';
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<String> _saveImageLocally(File imageFile) async {
    final dir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${dir.path}/chat_images');
    if (!await scansDir.exists()) {
      await scansDir.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final localPath = '${scansDir.path}/$timestamp.jpg';
    await imageFile.copy(localPath);
    return localPath;
  }

  Future<void> _sendMessage(AuthProvider authProvider) async {
    final user = authProvider.user;
    final profile = authProvider.profile;
    if (user == null || profile == null) return;

    final userText = _messageController.text.trim();
    if (userText.isEmpty && _selectedImage == null) return;

    final tier = authProvider.subscriptionTier;

    // Gate: image upload requires Pro+
    if (_selectedImage != null) {
      final canImage = await SubscriptionGateManager.canUploadImage(user.uid, tier);
      if (!canImage) {
        if (SubscriptionGateManager.isFree(tier)) {
          SubscriptionGateManager.showImageScanRequiresProDialog(context);
        } else {
          final max = SubscriptionGateManager.dailyImageUploadLimit(tier);
          SubscriptionGateManager.showLimitDialog(context, tier, 'Image Uploads', max);
        }
        return;
      }
    }

    // Gate: daily chat message limit
    if (!await SubscriptionGateManager.canChat(user.uid, tier)) {
      final max = SubscriptionGateManager.dailyChatMessageLimit(tier);
      if (mounted) SubscriptionGateManager.showLimitDialog(context, tier, 'Chat Messages', max);
      return;
    }

    if (authProvider.isFreeTier && _isPastPaperRequest(userText)) {
      _showUpgradePrompt(context);
      return;
    }

    final imageToSend = _selectedImage;

    setState(() {
      _messageController.clear();
      _selectedImage = null;
      _isGenerating = true;
      _streamingText = '';
    });

    if (_currentChatId == null) {
      await _startNewChat(user.uid);
    }

    final chatId = _currentChatId!;

    String? localImagePath;
    if (imageToSend != null) {
      localImagePath = await _saveImageLocally(imageToSend);
    }

    await _chatService.addMessage(chatId, 'user', userText, imageUrl: localImagePath);

    final existingContext = _messages
        .map((msg) => Content(msg.sender == 'user' ? 'user' : 'model', [
              TextPart(msg.text),
            ]))
        .toList();
    final prompt = _buildTutorPrompt(profile, userText);

    try {
      if (_messages.length <= 1) {
        await _chatService.updateChatTitle(chatId, _buildTitleFromText(userText.isNotEmpty ? userText : 'Image question'));
      }

      if (_geminiApiKey.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        final fallback = '''
## Answer
This is a demo response because the Gemini API key is not configured yet.

## What to do next
1. Add your Gemini key.
2. Ask the same question again.
3. The assistant will then generate a board-aligned answer for ${profile.boardName} Class ${profile.studentClass}.
''';
        for (final word in fallback.split(' ')) {
          if (!mounted) return;
          await Future.delayed(const Duration(milliseconds: 35));
          setState(() => _streamingText += '$word ');
          _scrollToBottom();
        }
      } else {
        final model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: _geminiApiKey,
        );

        final userParts = <Part>[TextPart('Student: $userText')];
        if (imageToSend != null) {
          final bytes = await imageToSend.readAsBytes();
          userParts.insert(0, DataPart('image/jpeg', bytes));
        }
        final currentContent = Content('user', userParts);

        final promptContent = <Content>[
          Content.text(prompt),
          ...existingContext,
          currentContent,
        ];

        final responseStream = model.generateContentStream(promptContent);
        await for (final chunk in responseStream) {
          if (!mounted) break;
          final chunkText = chunk.text;
          if (chunkText == null || chunkText.isEmpty) continue;
          setState(() => _streamingText += chunkText);
          _scrollToBottom();
        }
      }

      final finalText = _streamingText.trim();
      if (finalText.isNotEmpty) {
        await _chatService.addMessage(chatId, 'ai', finalText);
      }
      await SubscriptionGateManager.incrementDailyUsage(user.uid, 'chatMessagesCount');
      if (imageToSend != null) {
        await SubscriptionGateManager.incrementDailyUsage(user.uid, 'imageUploadsCount');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to generate a reply: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _streamingText = '';
        });
        _scrollToBottom();
      }
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _pickerOption(Icons.camera_alt_rounded, 'Camera', () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              }),
              _pickerOption(Icons.photo_library_rounded, 'Gallery', () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickerOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.onSurfaceOf(context))),
        ],
      ),
    );
  }

  void _showHistorySheet(String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
            decoration: BoxDecoration(
              color: AppColors.surfaceAltOf(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10), width: 42, height: 5,
                decoration: BoxDecoration(color: AppColors.borderOf(context), borderRadius: BorderRadius.circular(99)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Conversation History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.onSurfaceOf(context))),
                          const SizedBox(height: 4),
                          Text('Your previous IlmAI chats are stored in Firebase.', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMutedOf(context))),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _startNewChat(userId);
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Chat'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<ChatSessionModel>>(
                  stream: _chatService.getChatsStream(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final chats = snapshot.data ?? const [];
                    if (chats.isEmpty) {
                      return Center(
                        child: Text('No chats yet.', style: TextStyle(color: AppColors.onSurfaceMutedOf(context))),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: chats.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        final selected = chat.id == _currentChatId;
                        return InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _selectChat(chat.id);
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surfaceOf(context),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected ? AppColors.primary.withValues(alpha: 0.35) : AppColors.borderOf(context),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: selected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.12),
                                  child: Icon(Icons.chat_bubble_outline_rounded, color: selected ? Colors.white : AppColors.primary, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurfaceOf(context))),
                                      const SizedBox(height: 3),
                                      Text(_formatDate(chat.createdAt), style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMutedOf(context))),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Chat?'),
                                        content: const Text('This will permanently delete the chat and its messages.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _chatService.deleteChat(chat.id);
                                      if (_currentChatId == chat.id && mounted) {
                                        setState(() { _currentChatId = null; _messages = []; });
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour24 = local.hour;
    final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day}/${local.year} • $hour:$minute $period';
  }

  Widget _buildShimmerLoading() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18), topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 40, height: 10, decoration: BoxDecoration(color: AppColors.shimmerBase, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 10),
              Container(width: 220, height: 10, decoration: BoxDecoration(color: AppColors.shimmerBase, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 6),
              Container(width: 180, height: 10, decoration: BoxDecoration(color: AppColors.shimmerBase, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 6),
              Container(width: 100, height: 10, decoration: BoxDecoration(color: AppColors.shimmerBase, borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      backgroundColor: AppColors.surfaceAltOf(context).withValues(alpha: 0.9),
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.12)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
      onPressed: () {
        _messageController.text = text;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
      },
    );
  }

  Widget _buildAIContent(String text) {
    final blocks = text.split('\n\n').where((b) => b.trim().isNotEmpty).toList();
    final children = <Widget>[];
    final baseStyle = TextStyle(fontSize: 15, height: 1.5, color: AppColors.onSurfaceOf(context));

    for (final block in blocks) {
      final trimmed = block.trim();

      if (trimmed.startsWith('## ')) {
        final headingText = trimmed.substring(3).trim();
        children.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: SmartText(headingText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.onSurfaceOf(context), height: 1.4)),
        ));
      } else if (trimmed.startsWith('# ')) {
        final headingText = trimmed.substring(2).trim();
        children.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: SmartText(headingText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.onSurfaceOf(context), height: 1.3)),
        ));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        final lines = trimmed.split('\n');
        for (final line in lines) {
          final itemText = line.substring(2).trim();
          if (itemText.isEmpty) continue;
          children.add(Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: SmartText('•  $itemText', style: baseStyle),
          ));
        }
      } else if (RegExp(r'^\d+[\.\)] ').hasMatch(trimmed)) {
        final lines = trimmed.split('\n');
        int num = 1;
        for (final line in lines) {
          final match = RegExp(r'^\d+[\.\)] (.*)').firstMatch(line);
          final itemText = match?.group(1)?.trim() ?? line;
          if (itemText.isEmpty) continue;
          children.add(Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: SmartText('$num.  $itemText', style: baseStyle),
          ));
          num++;
        }
      } else {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: SmartText(trimmed, style: baseStyle),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.isNotEmpty ? children : [SmartText(text, style: baseStyle)],
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, {int index = -1}) {
    final isUser = message.sender == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isUser ? AppColors.primary : AppColors.surfaceOf(context),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              border: isUser ? null : Border.all(color: AppColors.borderOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUser ? 'You' : 'IlmAI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isUser ? Colors.white.withValues(alpha: 0.75) : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (message.imageUrl != null && message.imageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(message.imageUrl!),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: Colors.grey.withValues(alpha: 0.2),
                          child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                        ),
                      ),
                    ),
                  ),
                if (message.text.isNotEmpty)
                  isUser
                      ? SmartText(
                          message.text,
                          style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.white),
                        )
                      : _buildAIContent(message.text),
                if (!isUser && index >= 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 28, height: 28,
                          child: IconButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: message.text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Response copied'), duration: Duration(seconds: 2)),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            padding: EdgeInsets.zero,
                            color: AppColors.onSurfaceMutedOf(context),
                            tooltip: 'Copy response',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final profile = authProvider.profile;

    if (authProvider.isLoading || profile == null || user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: AppColors.surfaceAltOf(context),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceAltOf(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderOf(context)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('IlmAI Agent', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.onSurfaceOf(context))),
                          const SizedBox(height: 4),
                          Text('Board-aligned study chat for ${profile.promptSummary}.', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMutedOf(context))),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Chat history',
                      onPressed: () => _showHistorySheet(user.uid),
                      icon: Icon(Icons.history_rounded, color: AppColors.onSurfaceOf(context)),
                    ),
                    IconButton(
                      tooltip: 'New chat',
                      onPressed: () => _startNewChat(user.uid),
                      icon: Icon(Icons.add_comment_rounded, color: AppColors.onSurfaceOf(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _profileChip('Class ${profile.studentClass}'),
                    _profileChip(profile.boardName),
                    _profileChip(profile.levelName),
                  ],
                ),
              ],
            ),
          ),
          if (_currentChatId == null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSuggestionChip('Explain this chapter in simple words'),
                    const SizedBox(width: 8),
                    _buildSuggestionChip('Give me board-style important questions'),
                    const SizedBox(width: 8),
                    _buildSuggestionChip('Make a short revision summary'),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _currentChatId == null
                ? _buildEmptyState(profile, user.uid)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    itemCount: _messages.length + (_isGenerating ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isGenerating && index == _messages.length) {
                        if (_streamingText.isEmpty) return _buildShimmerLoading();
                        return _buildMessageBubble(
                          ChatMessageModel(id: 'streaming', sender: 'ai', text: _streamingText, timestamp: DateTime.now()),
                          index: index,
                        );
                      }
                      return _buildMessageBubble(_messages[index], index: index);
                    },
                  ),
          ),
          _buildInputBar(authProvider),
        ],
      ),
    );
  }

  Widget _profileChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _buildEmptyState(StudentProfile profile, String userId) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary.withValues(alpha: 0.18), AppColors.primary.withValues(alpha: 0.05)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 22),
            Text('Salaam, ${profile.name.split(' ').first}', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.onSurfaceOf(context))),
            const SizedBox(height: 10),
            Text('Ask anything about your board syllabus — upload an image or type a question.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.onSurfaceMutedOf(context))),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _startNewChat(userId),
              child: const Text('Start a new conversation'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        border: Border(top: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _showImagePickerSheet,
                    icon: Icon(
                      _selectedImage != null ? Icons.image_rounded : Icons.add_photo_alternate_outlined,
                      color: _selectedImage != null ? AppColors.primary : AppColors.onSurfaceMutedOf(context),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      style: TextStyle(color: AppColors.onSurfaceOf(context)),
                      decoration: const InputDecoration(
                        hintText: 'Ask a question or paste a topic...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendMessage(authProvider),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF0F2D6B)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: IconButton(
              onPressed: _isGenerating ? null : () => _sendMessage(authProvider),
              icon: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
