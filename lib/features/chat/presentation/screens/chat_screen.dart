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

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatFirestoreService _chatService = ChatFirestoreService();
  final ImagePicker _imagePicker = ImagePicker();
  final FocusNode _inputFocus = FocusNode();

  StreamSubscription<List<ChatMessageModel>>? _messagesSubscription;
  String? _currentChatId;
  bool _isGenerating = false;
  String _streamingText = '';
  List<ChatMessageModel> _messages = [];
  File? _selectedImage;

  late AnimationController _sidebarCtrl;
  late Animation<Offset> _sidebarSlide;
  late Animation<double> _backdropFade;
  bool _sidebarOpen = false;

  static const String _envApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  String get _geminiApiKey {
    if (AppConfig.geminiApiKey.isNotEmpty &&
        AppConfig.geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE') {
      return AppConfig.geminiApiKey;
    }
    return _envApiKey;
  }

  @override
  void initState() {
    super.initState();
    _sidebarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _sidebarSlide = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _sidebarCtrl,
      curve: Curves.easeOutCubic,
    ));
    _backdropFade = CurvedAnimation(
      parent: _sidebarCtrl,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _sidebarCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    if (_sidebarOpen) {
      _sidebarCtrl.reverse();
    } else {
      _sidebarCtrl.forward();
    }
    setState(() => _sidebarOpen = !_sidebarOpen);
  }

  void _closeSidebar() {
    if (_sidebarCtrl.isAnimating) return;
    if (_sidebarOpen) {
      _sidebarCtrl.reverse();
      setState(() => _sidebarOpen = false);
    }
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
    _messagesSubscription =
        _chatService.getMessagesStream(chatId).listen((messages) {
      if (!mounted) return;
      setState(() => _messages = messages);
      _scrollToBottom();
    });
  }

  Future<void> _startNewChat(String userId) async {
    _closeSidebar();
    final title = 'New Chat ${TimeOfDay.now().format(context)}';
    final chatId = await _chatService.createChat(userId, title);
    _selectChat(chatId);
  }

  String _levelLabel(StudentLevel level) {
    switch (level) {
      case StudentLevel.developing:
        return 'Weak';
      case StudentLevel.average:
        return 'Average';
      case StudentLevel.advanced:
        return 'Intelligent';
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
        _inputFocus.unfocus();
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

    if (_selectedImage != null) {
      final canImage =
          await SubscriptionGateManager.canUploadImage(user.uid, tier);
      if (!canImage) {
        if (SubscriptionGateManager.isFree(tier)) {
          SubscriptionGateManager.showImageScanRequiresProDialog(context);
        } else {
          final max = SubscriptionGateManager.dailyImageUploadLimit(tier);
          SubscriptionGateManager.showLimitDialog(
              context, tier, 'Image Uploads', max);
        }
        return;
      }
    }

    if (!await SubscriptionGateManager.canChat(user.uid, tier)) {
      final max = SubscriptionGateManager.dailyChatMessageLimit(tier);
      if (mounted) {
        SubscriptionGateManager.showLimitDialog(
            context, tier, 'Chat Messages', max);
      }
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

    await _chatService.addMessage(
        chatId, 'user', userText, imageUrl: localImagePath);

    final existingContext = _messages
        .map((msg) => Content(
              msg.sender == 'user' ? 'user' : 'model',
              [TextPart(msg.text)],
            ))
        .toList();
    final prompt = _buildTutorPrompt(profile, userText);

    try {
      if (_messages.length <= 1) {
        await _chatService.updateChatTitle(
            chatId,
            _buildTitleFromText(
                userText.isNotEmpty ? userText : 'Image question'));
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
      await SubscriptionGateManager.incrementDailyUsage(
          user.uid, 'chatMessagesCount');
      if (imageToSend != null) {
        await SubscriptionGateManager.incrementDailyUsage(
            user.uid, 'imageUploadsCount');
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderOf(context),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 20),
              Row(
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
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.primary.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 10),
          Text(label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.onSurfaceOf(context),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${local.month}/${local.day}/${local.year}';
  }

  Widget _buildShimmerLoading() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 10,
                decoration: BoxDecoration(
                  color: AppColors.shimmerBase,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 220, height: 10,
                decoration: BoxDecoration(
                  color: AppColors.shimmerBase,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 160, height: 10,
                decoration: BoxDecoration(
                  color: AppColors.shimmerBase,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIContent(String text) {
    final blocks =
        text.split('\n\n').where((b) => b.trim().isNotEmpty).toList();
    final children = <Widget>[];
    final baseStyle = TextStyle(
        fontSize: 15, height: 1.6, color: AppColors.onSurfaceOf(context));

    for (final block in blocks) {
      final trimmed = block.trim();

      if (trimmed.startsWith('## ')) {
        final headingText = trimmed.substring(3).trim();
        children.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: SmartText(
            headingText,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurfaceOf(context),
                height: 1.4),
          ),
        ));
      } else if (trimmed.startsWith('# ')) {
        final headingText = trimmed.substring(2).trim();
        children.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: SmartText(
            headingText,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.onSurfaceOf(context),
                height: 1.3),
          ),
        ));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        final lines = trimmed.split('\n');
        for (final line in lines) {
          final itemText = line.substring(2).trim();
          if (itemText.isEmpty) continue;
          children.add(Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: SmartText('  $itemText', style: baseStyle),
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
      children:
          children.isNotEmpty ? children : [SmartText(text, style: baseStyle)],
    );
  }

  // ─── NEW SIDEBAR (premium design) ─────────────────────────────────────

  Widget _buildSidebar(String userId) {
    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: SizedBox(
        width: 300,
        child: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 50,
                offset: const Offset(8, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // ─── Header ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.88),
                      Color(0xFF0F2460),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            color: Colors.white, size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('IlmAI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text('Chat History',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _closeSidebar,
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white, size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => _startNewChat(userId),
                        style: TextButton.styleFrom(
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.14),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10),
                        ),
                        icon: const Icon(
                          Icons.add_rounded, size: 20,
                        ),
                        label: const Text(
                          'New Chat',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ─── Chat List ──────────────────────────────────────
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                  ),
                  child: StreamBuilder<List<ChatSessionModel>>(
                    stream: _chatService.getChatsStream(userId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }
                      final chats = snapshot.data ?? const [];
                      if (chats.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 40,
                                  color:
                                      AppColors.onSurfaceMutedOf(context)
                                          .withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No conversations yet',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors
                                        .onSurfaceMutedOf(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap "New Chat" to start learning',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors
                                        .onSurfaceMutedOf(context)
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.only(
                            top: 8, bottom: 8),
                        itemCount: chats.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          final selected =
                              chat.id == _currentChatId;
                          return _buildChatItem(chat, selected);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem(ChatSessionModel chat, bool selected) {
    return GestureDetector(
      onTap: () {
        _closeSidebar();
        _selectChat(chat.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 17,
                color: selected
                    ? Colors.white
                    : AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.onSurfaceOf(context),
                    ),
                  ),
                  Text(
                    _formatDate(chat.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceMutedOf(context),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _confirmDeleteChat(chat.id),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: Colors.red.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteChat(String chatId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded,
                color: Colors.red.shade400, size: 24),
            const SizedBox(width: 10),
            const Text('Delete Chat?',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: const Text(
          'This will permanently delete this conversation and all its messages. This action cannot be undone.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.onSurfaceMutedOf(context),
            ),
            child: const Text('Cancel',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _chatService.deleteChat(chatId);
      if (_currentChatId == chatId && mounted) {
        setState(() {
          _currentChatId = null;
          _messages = [];
        });
      }
    }
  }

  // ─── GREETING (animated & unique) ────────────────────────────────────

  Widget _buildGreetingState(StudentProfile profile, String userId) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            // Animated icon stack
            SizedBox(
              width: 120, height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.15),
                          AppColors.primary.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      size: 44,
                      color: AppColors.primary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Headline
            Text(
              'Master Your Board\nExams with IlmAI',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: AppColors.onSurfaceOf(context),
                height: 1.15,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 14),
            // Subtitle
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                '${profile.boardName}  |  Class ${profile.studentClass}  |  ${profile.levelName}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Subject bubbles
            _buildSubjectGrid(),
            const SizedBox(height: 28),
            // Start button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF0F2460)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _startNewChat(userId),
                    borderRadius: BorderRadius.circular(16),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Start Learning',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectGrid() {
    final subjects = <MapEntry<String, IconData>>[
      MapEntry('Mathematics', Icons.calculate_rounded),
      MapEntry('Physics', Icons.science_rounded),
      MapEntry('Chemistry', Icons.biotech_rounded),
      MapEntry('Biology', Icons.pets_rounded),
      MapEntry('Computer', Icons.computer_rounded),
      MapEntry('English', Icons.menu_book_rounded),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: subjects.map((s) {
        return GestureDetector(
          onTap: () {
            _messageController.text =
                'Help me study ${s.key} for my upcoming exam';
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.borderOf(context),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(s.value, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  s.key,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── TOP BAR ────────────────────────────────────────────────────────

  Widget _buildTopBar(StudentProfile profile) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderOf(context).withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleSidebar,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceAltOf(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.menu_rounded,
                color: AppColors.onSurfaceOf(context),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF0F2460)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white, size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IlmAI',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurfaceOf(context),
                  ),
                ),
                Text(
                  '${profile.boardName}  .  Class ${profile.studentClass}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceMutedOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── INPUT BAR (redesigned) ─────────────────────────────────────────

  Widget _buildInputBar(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(
          top: BorderSide(
            color: AppColors.borderOf(context).withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedImage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      width: 36, height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedImage!.path.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceOf(context),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _selectedImage = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.red.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceAltOf(context),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.borderOf(context),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: GestureDetector(
                    onTap: _showImagePickerSheet,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _selectedImage != null
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _selectedImage != null
                            ? Icons.image_rounded
                            : Icons.add_photo_alternate_outlined,
                        size: 20,
                        color: _selectedImage != null
                            ? AppColors.primary
                            : AppColors.onSurfaceMutedOf(context),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _inputFocus,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    style: TextStyle(
                      color: AppColors.onSurfaceOf(context),
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask a question or paste a topic...',
                      hintStyle: TextStyle(
                        color: AppColors.onSurfaceMutedOf(context)
                            .withValues(alpha: 0.7),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(authProvider),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4, bottom: 4),
                  child: GestureDetector(
                    onTap: _isGenerating
                        ? null
                        : () => _sendMessage(authProvider),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _isGenerating
                            ? null
                            : const LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  Color(0xFF0F2D6B),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: _isGenerating
                            ? AppColors.onSurfaceMutedOf(context)
                                .withValues(alpha: 0.15)
                            : null,
                      ),
                      child: Icon(
                        _isGenerating
                            ? Icons.hourglass_bottom_rounded
                            : Icons.arrow_upward_rounded,
                        color: _isGenerating
                            ? AppColors.onSurfaceMutedOf(context)
                            : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── MESSAGES (with entrance animation) ──────────────────────────────

  Widget _buildMessageBubble(ChatMessageModel message, {int index = -1}) {
    final isUser = message.sender == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isUser
                  ? AppColors.primary
                  : AppColors.surfaceOf(context),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(22),
                topRight: const Radius.circular(22),
                bottomLeft: Radius.circular(isUser ? 22 : 6),
                bottomRight: Radius.circular(isUser ? 6 : 22),
              ),
              border: isUser
                  ? null
                  : Border.all(
                      color: AppColors.borderOf(context)),
              boxShadow: isUser
                  ? [
                      BoxShadow(
                        color: AppColors.primary
                            .withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.imageUrl != null &&
                    message.imageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(message.imageUrl!),
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 100,
                          color: Colors.grey.withValues(alpha: 0.15),
                          child: const Center(
                            child: Icon(Icons.broken_image,
                                color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (message.text.isNotEmpty)
                  isUser
                      ? SmartText(
                          message.text,
                          style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: Colors.white),
                        )
                      : _buildAIContent(message.text),
                if (!isUser && index >= 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: message.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied to clipboard'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.onSurfaceOf(context)
                                  .withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 13,
                                  color: AppColors
                                      .onSurfaceMutedOf(context),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Copy',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors
                                        .onSurfaceMutedOf(context),
                                  ),
                                ),
                              ],
                            ),
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

  // ─── BUILD ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final profile = authProvider.profile;

    if (authProvider.isLoading || profile == null || user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Column(
          children: [
            _buildTopBar(profile),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                child: _currentChatId == null
                    ? _buildGreetingState(profile, user.uid)
                    : ListView.builder(
                        key: const ValueKey('chat_list'),
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(
                            16, 20, 16, 12),
                        itemCount: _messages.length +
                            (_isGenerating ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isGenerating &&
                              index == _messages.length) {
                            if (_streamingText.isEmpty) {
                              return _buildShimmerLoading();
                            }
                            return _buildMessageBubble(
                              ChatMessageModel(
                                id: 'streaming',
                                sender: 'ai',
                                text: _streamingText,
                                timestamp: DateTime.now(),
                              ),
                              index: index,
                            );
                          }
                          return _buildMessageBubble(
                              _messages[index], index: index);
                        },
                      ),
              ),
            ),
            _buildInputBar(authProvider),
          ],
        ),
        // Backdrop (FIXED: fills the entire Stack)
        if (_sidebarOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeSidebar,
              child: FadeTransition(
                opacity: _backdropFade,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        // Sidebar
        SlideTransition(
          position: _sidebarSlide,
          child: _buildSidebar(user.uid),
        ),
      ],
    );
  }
}
