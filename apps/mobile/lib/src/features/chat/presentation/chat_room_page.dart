import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../media/presentation/device_photo_picker_page.dart';
import '../../posts/presentation/post_detail_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../data/chat_models.dart';
import '../data/chat_mention.dart';
import '../data/chat_repository.dart';
import 'chat_details_page.dart';
import 'chat_widgets.dart';
import 'chat_mention_controller.dart';

typedef MessageLoader = Future<List<ChatMessage>> Function();
typedef MessageSender = Future<void> Function(
    String conversationId, String body);
typedef ConversationAction = Future<void> Function(String conversationId);
typedef MentionVisitAction = Future<void> Function(String messageId);

class ChatRoomPage extends StatefulWidget {
  const ChatRoomPage({
    super.key,
    required this.conversation,
    this.loadMessages,
    this.sendMessage,
    this.markRead,
    this.mentionParticipants,
    this.canMentionAll = false,
    this.initialUnvisitedMentionMessageIds = const [],
    this.markMentionVisited,
  });

  final ChatConversation conversation;
  final MessageLoader? loadMessages;
  final MessageSender? sendMessage;
  final ConversationAction? markRead;
  final List<ChatParticipant>? mentionParticipants;
  final bool canMentionAll;
  final List<String> initialUnvisitedMentionMessageIds;
  final MentionVisitAction? markMentionVisited;

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage>
    with WidgetsBindingObserver {
  static const _messageCachePrefix = 'chat.cached_messages.v1.';
  static final Map<String, List<ChatMessage>> _cachedMessages =
      <String, List<ChatMessage>>{};

  ChatRepository? _repository;
  RealtimeChannel? _channel;
  late Future<List<ChatMessage>> _messagesFuture;
  late ChatConversation _conversation = widget.conversation;
  final _controller = TextEditingController();
  final _mentionController = ChatMentionController();
  final _messageScrollController = ScrollController();
  final _inputFocusNode = FocusNode();
  final List<Timer> _scrollTimers = <Timer>[];
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  final GlobalKey _unreadDividerKey = GlobalKey();
  bool _isSending = false;
  bool _isPickingImage = false;
  bool _initialScrollDone = false;
  bool _showJumpToBottom = false;
  List<ChatParticipant> _mentionParticipants = const [];
  List<String> _unvisitedMentionMessageIds = const [];
  String? _mentionQuery;
  String _previousComposerText = '';
  bool _canMentionAll = false;
  final Set<String> _selectedMessageIds = <String>{};
  final Map<String, ChatMessage> _selectedMessagesById =
      <String, ChatMessage>{};

  ChatRepository get _repo =>
      _repository ??= ChatRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messageScrollController.addListener(_handleMessageScrollChanged);
    _inputFocusNode.addListener(_handleInputFocusChanged);
    _messagesFuture = _load();
    _mentionParticipants = widget.mentionParticipants ?? const [];
    _canMentionAll = widget.canMentionAll;
    _unvisitedMentionMessageIds = widget.initialUnvisitedMentionMessageIds;
    if (_conversation.isGroup &&
        widget.loadMessages == null &&
        widget.mentionParticipants == null) {
      _loadMentionParticipants();
    }
    (widget.markRead ?? _repo.markConversationRead)(_conversation.id);
    if (widget.loadMessages == null) {
      _channel = _repo.subscribeToChatChanges(
        channelName: 'chat-room-${_conversation.id}',
        onChange: (_) {
          if (mounted) {
            setState(() {
              _messagesFuture = _load();
            });
          }
        },
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final channel = _channel;
    if (channel != null) {
      _repo.unsubscribe(channel);
    }
    _messageScrollController.removeListener(_handleMessageScrollChanged);
    _inputFocusNode.removeListener(_handleInputFocusChanged);
    for (final timer in _scrollTimers) {
      timer.cancel();
    }
    _scrollTimers.clear();
    _controller.dispose();
    _inputFocusNode.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _pinToBottomAfterLayout();
  }

  void _handleInputFocusChanged() {
    if (!_inputFocusNode.hasFocus) return;
    _pinToBottomAfterLayout();
  }

  void _queueScrollToLatest(Duration delay, {bool jump = false}) {
    late final Timer timer;
    timer = Timer(delay, () {
      _scrollTimers.remove(timer);
      if (mounted) _scrollToLatest(jump: jump);
    });
    _scrollTimers.add(timer);
  }

  void _scheduleScrollToLatest({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToLatest(jump: jump);
    });
  }

  void _pinToBottomAfterLayout({bool smooth = false}) {
    _scheduleScrollToLatest(jump: !smooth);
    _queueScrollToLatest(const Duration(milliseconds: 50), jump: !smooth);
    _queueScrollToLatest(const Duration(milliseconds: 150), jump: !smooth);
    _queueScrollToLatest(const Duration(milliseconds: 300), jump: !smooth);
  }

  void _handleMessageScrollChanged() {
    if (!_messageScrollController.hasClients) return;
    if (!_messageScrollController.position.hasContentDimensions) return;
    final position = _messageScrollController.position;
    final shouldShow = position.pixels - position.minScrollExtent > 160;
    _setJumpToBottomVisible(shouldShow);
  }

  void _setJumpToBottomVisible(bool visible) {
    if (!mounted || visible == _showJumpToBottom) return;
    setState(() => _showJumpToBottom = visible);
  }

  void _scheduleInitialMessagePosition(List<ChatMessage> messages) {
    if (_initialScrollDone || messages.isEmpty) return;
    _initialScrollDone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_unvisitedMentionMessageIds.isNotEmpty) {
        _visitNextMention();
        return;
      }
      _scrollToUnreadDividerOrLatest(messages);
    });
  }

  void _scrollToUnreadDividerOrLatest(List<ChatMessage> messages) {
    final unreadCount = _conversation.unreadCount;
    if (unreadCount <= 0) {
      _setJumpToBottomVisible(false);
      return;
    }

    _queueRevealUnreadDividerIfNeeded(const Duration(milliseconds: 360));
  }

  void _scrollToLatest({bool jump = false}) {
    if (!_messageScrollController.hasClients) return;
    final position = _messageScrollController.position;
    if (!position.hasContentDimensions) return;
    final target = position.minScrollExtent;
    if ((position.pixels - target).abs() < 2) {
      _setJumpToBottomVisible(false);
      return;
    }
    if (jump) {
      _messageScrollController.jumpTo(target);
      _setJumpToBottomVisible(false);
      return;
    }
    _messageScrollController
        .animateTo(
      target,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
    )
        .whenComplete(() {
      if (!mounted || !_messageScrollController.hasClients) return;
      final position = _messageScrollController.position;
      if (!position.hasContentDimensions) return;
      if (position.pixels - position.minScrollExtent <= 8) {
        _setJumpToBottomVisible(false);
      }
    });
  }

  void _queueRevealUnreadDividerIfNeeded(Duration delay) {
    late final Timer timer;
    timer = Timer(delay, () {
      _scrollTimers.remove(timer);
      if (mounted) _revealUnreadDividerIfNeeded();
    });
    _scrollTimers.add(timer);
  }

  void _revealUnreadDividerIfNeeded() {
    if (!_messageScrollController.hasClients) return;
    final position = _messageScrollController.position;
    if (!position.hasContentDimensions) return;
    final context = _unreadDividerKey.currentContext;
    if (context == null) return;
    final box = context.findRenderObject();
    final scrollBox = position.context.notificationContext?.findRenderObject();
    if (box is! RenderBox || scrollBox is! RenderBox) return;
    final dividerTop = box.localToGlobal(Offset.zero).dy;
    final viewportTop = scrollBox.localToGlobal(Offset.zero).dy;
    final hiddenAboveViewport = dividerTop < viewportTop;
    if (!hiddenAboveViewport) {
      _scrollToLatest(jump: true);
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
    _setJumpToBottomVisible(true);
  }

  Future<List<ChatMessage>> _load() async {
    await _restoreCachedMessages();
    try {
      final messages = await (widget.loadMessages?.call() ??
          _repo.fetchMessages(_conversation.id));
      if (widget.loadMessages == null &&
          widget.initialUnvisitedMentionMessageIds.isEmpty) {
        final mentions = await _repo.fetchUnvisitedMentions(
          conversationId: _conversation.id,
        );
        _unvisitedMentionMessageIds =
            mentions.map((mention) => mention.messageId).toSet().toList();
        final loadedIds = messages.map((message) => message.id).toSet();
        final missingIds = _unvisitedMentionMessageIds
            .where((messageId) => !loadedIds.contains(messageId))
            .toList();
        if (missingIds.isNotEmpty) {
          messages.addAll(await _repo.fetchMessagesByIds(missingIds));
        }
      }
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _cachedMessages[_conversation.id] = messages.length <= 10
          ? messages
          : messages.sublist(messages.length - 10);
      await _saveMessageCache(_cachedMessages[_conversation.id]!);
      return messages;
    } catch (_) {
      return _cachedMessages[_conversation.id] ?? const <ChatMessage>[];
    }
  }

  Future<void> _loadMentionParticipants() async {
    try {
      final participants =
          await _repo.fetchConversationParticipants(_conversation.id);
      final currentId = _currentUserId;
      if (!mounted) return;
      setState(() {
        _canMentionAll = participants.any(
          (person) => person.id == currentId && person.isAdmin,
        );
        _mentionParticipants =
            participants.where((person) => person.id != currentId).toList();
      });
    } catch (_) {}
  }

  void _handleComposerChanged(String text) {
    _mentionController.reconcile(
      previousText: _previousComposerText,
      text: text,
    );
    _previousComposerText = text;
    final query = _mentionController.queryFor(
      text,
      _controller.selection.baseOffset,
    );
    if (query != _mentionQuery && mounted) {
      setState(() => _mentionQuery = query);
    }
  }

  void _insertMention(ChatParticipant? participant, {bool all = false}) {
    final result = _mentionController.insertMention(
      text: _controller.text,
      selectionOffset: _controller.selection.baseOffset,
      userId: participant?.id ?? '',
      displayName: participant?.name ?? 'all',
      isAll: all,
    );
    _controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.selectionOffset),
    );
    _previousComposerText = result.text;
    setState(() => _mentionQuery = null);
    _inputFocusNode.requestFocus();
  }

  List<ChatParticipant> get _filteredMentionParticipants {
    final query = (_mentionQuery ?? '').trim().toLowerCase();
    if (query == 'all') return const [];
    return _mentionParticipants
        .where((person) => person.name.toLowerCase().contains(query))
        .take(6)
        .toList();
  }

  List<ChatMessage> get _cachedRoomMessages =>
      _cachedMessages[_conversation.id] ?? const <ChatMessage>[];

  String? get _currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _restoreCachedMessages() async {
    if (_cachedMessages.containsKey(_conversation.id)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('$_messageCachePrefix${_conversation.id}');
      _cachedMessages[_conversation.id] = _decodeMessages(cached);
    } catch (_) {}
  }

  Future<void> _saveMessageCache(List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_messageCachePrefix${_conversation.id}',
        jsonEncode(messages.map(_messageToJson).toList()),
      );
    } catch (_) {}
  }

  static List<ChatMessage> _decodeMessages(String? value) {
    if (value == null || value.isEmpty) return const <ChatMessage>[];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return const <ChatMessage>[];
      return decoded
          .whereType<Map>()
          .map((item) {
            final map = Map<String, dynamic>.from(item);
            return ChatMessage(
              id: '${map['id'] ?? ''}',
              conversationId: '${map['conversation_id'] ?? ''}',
              senderId: '${map['sender_id'] ?? ''}',
              body: '${map['body'] ?? ''}',
              createdAt: DateTime.tryParse('${map['created_at'] ?? ''}') ??
                  DateTime.fromMillisecondsSinceEpoch(0),
              isMine: map['is_mine'] == true,
              deletedAt: DateTime.tryParse('${map['deleted_at'] ?? ''}'),
              senderName: map['sender_name']?.toString(),
              senderAvatarUrl: map['sender_avatar_url']?.toString(),
              mentions: (map['mentions'] as List?)
                      ?.whereType<Map>()
                      .map(ChatMention.fromMap)
                      .toList() ??
                  const [],
            );
          })
          .where((message) => !message.isDeleted)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (_) {
      return const <ChatMessage>[];
    }
  }

  static Map<String, dynamic> _messageToJson(ChatMessage message) {
    return {
      'id': message.id,
      'conversation_id': message.conversationId,
      'sender_id': message.senderId,
      'body': message.body,
      'created_at': message.createdAt.toIso8601String(),
      'deleted_at': message.deletedAt?.toIso8601String(),
      'is_mine': message.isMine,
      'sender_name': message.senderName,
      'sender_avatar_url': message.senderAvatarUrl,
      'mentions': message.mentions.map((mention) => mention.toJson()).toList(),
    };
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final action = widget.sendMessage ??
          (String id, String text) async {
            final leading =
                _controller.text.length - _controller.text.trimLeft().length;
            final mentions = _mentionController.mentions
                .map((mention) => ChatMention(
                      userId: mention.userId,
                      displayText: mention.displayText,
                      start: mention.start - leading,
                      end: mention.end - leading,
                      isAll: mention.isAll,
                    ))
                .where((mention) => mention.matches(text))
                .toList();
            await _repo.sendMessage(
              conversationId: id,
              body: text,
              mentions: mentions,
            );
          };
      await action(_conversation.id, body);
      _controller.clear();
      _mentionController.clear();
      _previousComposerText = '';
      _mentionQuery = null;
      final nextMessages = _load();
      if (mounted) {
        setState(() {
          _messagesFuture = nextMessages;
        });
        _pinToBottomAfterLayout();
      }
    } catch (error) {
      assert(() {
        debugPrint('Chat send failed: $error');
        return true;
      }());
      if (mounted) {
        final message = error.toString();
        final text = message.contains('Pending message requests are limited')
            ? 'You can only send 3 messages until they accept your request.'
            : message.contains('Active conversation membership required')
                ? 'You are not an active member of this chat yet.'
                : message.contains('Conversation not found')
                    ? 'This chat no longer exists.'
                    : 'No internet connection';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _visitNextMention() async {
    if (_unvisitedMentionMessageIds.isEmpty) return;
    final messageId = _unvisitedMentionMessageIds.first;
    final context = _messageKeys[messageId]?.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: 0.2,
    );
    if (mounted) {
      setState(() {
        _unvisitedMentionMessageIds =
            _unvisitedMentionMessageIds.skip(1).toList();
      });
    }
    try {
      await (widget.markMentionVisited ?? _repo.markMentionVisited)(messageId);
    } catch (_) {}
  }

  void _openMentionProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ProfilePage(userId: userId)),
    );
  }

  Future<void> _sendImage() async {
    if (_isSending || _isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final picked = await Navigator.of(context).push<List<XFile>>(
        MaterialPageRoute(
          builder: (_) => const DevicePhotoPickerPage(
            maxSelection: 10,
            allowCamera: true,
          ),
        ),
      );
      if (picked == null || picked.isEmpty) return;
      final uploads = <ChatImageUpload>[];
      for (final image in picked) {
        final bytes = await image.readAsBytes();
        uploads.add(
          ChatImageUpload(
            fileName: image.name,
            bytes: bytes,
            contentType: image.mimeType ?? 'image/jpeg',
            aspectRatio: await _imageAspectRatio(bytes),
          ),
        );
      }
      await _repo.sendImageMessages(
        conversationId: _conversation.id,
        images: uploads,
      );
      final nextMessages = _load();
      if (mounted) {
        setState(() {
          _messagesFuture = nextMessages;
        });
        _pinToBottomAfterLayout();
      }
    } catch (error) {
      assert(() {
        debugPrint('Chat image send failed: $error');
        return true;
      }());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<double?> _imageAspectRatio(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (width <= 0 || height <= 0) return null;
      return width / height;
    } catch (_) {
      return null;
    }
  }

  List<ChatMessage> get _selectedMessages {
    final messages = _selectedMessagesById.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }

  bool get _hasSelectedMessages => _selectedMessageIds.isNotEmpty;

  void _selectMessage(ChatMessage message) {
    setState(() {
      _selectedMessageIds.add(message.id);
      _selectedMessagesById[message.id] = message;
    });
  }

  void _toggleSelectedMessage(ChatMessage message) {
    if (!_hasSelectedMessages) return;
    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
        _selectedMessagesById.remove(message.id);
      } else {
        _selectedMessageIds.add(message.id);
        _selectedMessagesById[message.id] = message;
      }
    });
  }

  void _clearSelectedMessages() {
    setState(() {
      _selectedMessageIds.clear();
      _selectedMessagesById.clear();
    });
  }

  bool get _selectedCanCopy {
    final messages = _selectedMessages;
    return messages.isNotEmpty &&
        messages.every(
          (message) =>
              !message.isDeleted &&
              !message.hasImage &&
              !message.hasSharedPost &&
              message.body.isNotEmpty,
        );
  }

  bool get _selectedCanUnsend {
    final messages = _selectedMessages;
    return messages.isNotEmpty &&
        messages.every(
          (message) =>
              !message.isDeleted &&
              message.isMine &&
              DateTime.now().difference(message.createdAt) <=
                  const Duration(minutes: 10),
        );
  }

  Future<void> _copySelectedMessage() async {
    final text = _selectedMessages
        .where((message) => !message.isDeleted && !message.hasImage)
        .where((message) => !message.hasSharedPost)
        .map((message) => message.body)
        .where((body) => body.trim().isNotEmpty)
        .join('\n');
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _clearSelectedMessages();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
  }

  Future<void> _openSharedPost(ChatSharedPost sharedPost) async {
    if (_hasSelectedMessages) return;
    try {
      final post = await _repo.fetchPostForNotification(sharedPost.postId);
      if (post.moderationStatus != 'approved') {
        throw const ChatNotificationPostUnavailableException();
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PostDetailPage(post: post),
        ),
      );
    } on ChatNotificationPostUnavailableException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "This post can't be viewed. It may be deleted or not approved yet.",
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection')),
      );
    }
  }

  Future<void> _deleteSelectedForMe() async {
    final messages = _selectedMessages;
    if (messages.isEmpty) return;
    final isPlural = messages.length > 1;
    final confirmed = await _confirmMessageAction(
      title: isPlural ? 'Delete messages for you?' : 'Delete message for you?',
      body: isPlural
          ? 'These messages will be removed from your chat history. Other people can still see them.'
          : 'This message will be removed from your chat history. Other people can still see it.',
      actionLabel: 'Delete',
      danger: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      for (final message in messages) {
        await _repo.deleteMessageForMe(message.id);
        _removeMessageLocally(message.id);
      }
      if (!mounted) return;
      _clearSelectedMessages();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPlural ? 'Messages deleted for me' : 'Message deleted for me',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _restoreDeletedForMe(messages),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection')),
        );
      }
    }
  }

  Future<void> _unsendSelected() async {
    final messages = _selectedMessages;
    if (messages.isEmpty || !_selectedCanUnsend) return;
    final isPlural = messages.length > 1;
    final confirmed = await _confirmMessageAction(
      title: isPlural ? 'Unsend messages?' : 'Unsend message?',
      body: isPlural
          ? 'This permanently removes these messages for everyone in this chat.'
          : 'This permanently removes the message for everyone in this chat.',
      actionLabel: 'Unsend',
      danger: true,
    );
    if (confirmed != true || !mounted) return;
    var storageCleanupFailed = false;
    try {
      for (final message in messages) {
        final storagePaths = message.imageStoragePaths.toSet().toList();
        try {
          await _repo.unsendMessage(message.id);
        } catch (error) {
          if (!error.toString().contains('Message can no longer be unsent')) {
            rethrow;
          }
        }
        if (storagePaths.isNotEmpty) {
          try {
            await _repo.deleteImageStoragePaths(storagePaths);
          } catch (error) {
            storageCleanupFailed = true;
            assert(() {
              debugPrint('Chat image storage cleanup failed: $error');
              return true;
            }());
          }
        }
        _removeMessageLocally(message.id);
      }
      if (!mounted) return;
      _clearSelectedMessages();
      if (storageCleanupFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo cleanup failed. Please try again later.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection')),
      );
    }
  }

  Future<void> _restoreDeletedForMe(List<ChatMessage> messages) async {
    try {
      for (final message in messages) {
        await _repo.restoreMessageForMe(message.id);
      }
      if (!mounted) return;
      for (final message in messages) {
        _replaceMessageLocally(message);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection')),
      );
    }
  }

  Future<bool?> _confirmMessageAction({
    required String title,
    required String body,
    required String actionLabel,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
          contentPadding: const EdgeInsets.fromLTRB(22, 10, 22, 4),
          actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Text(
            title,
            style: const TextStyle(
              color: chatNavy,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          content: Text(
            body,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: danger ? chatDanger : chatCyan,
              ),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
  }

  void _removeMessageLocally(String messageId) {
    final current = List<ChatMessage>.of(_cachedRoomMessages)
      ..removeWhere((message) => message.id == messageId);
    _cachedMessages[_conversation.id] = current;
    setState(() {
      _messagesFuture = Future.value(current);
    });
    _saveMessageCache(current);
  }

  void _replaceMessageLocally(ChatMessage updatedMessage) {
    final current = List<ChatMessage>.of(_cachedRoomMessages);
    final index =
        current.indexWhere((message) => message.id == updatedMessage.id);
    if (index >= 0) {
      current[index] = updatedMessage;
    } else {
      current.add(updatedMessage);
    }
    current.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _cachedMessages[_conversation.id] =
        current.length <= 10 ? current : current.sublist(current.length - 10);
    setState(() {
      _messagesFuture = Future.value(current);
    });
    _saveMessageCache(_cachedMessages[_conversation.id]!);
  }

  @override
  Widget build(BuildContext context) {
    return ChatNoSplash(
      child: Scaffold(
        backgroundColor: chatWhatsappBackground,
        appBar: !_hasSelectedMessages
            ? AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 0,
                titleSpacing: 0,
                title: GestureDetector(
                  onTap: () async {
                    final updated = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ChatDetailsPage(conversation: _conversation),
                      ),
                    );
                    if (updated is ChatConversation && mounted) {
                      setState(() => _conversation = updated);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      _conversation.isGroup
                          ? GroupAvatar(
                              seed: _conversation.id,
                              size: 36,
                            )
                          : ChatAvatar(
                              name: _conversation.displayTitle,
                              avatarUrl: _conversation.otherUserAvatarUrl,
                              size: 36,
                            ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _conversation.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: chatNavy,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                  ),
                ),
              )
            : AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  onPressed: _clearSelectedMessages,
                  icon: const Icon(Icons.close_rounded),
                ),
                title: Text(
                  '${_selectedMessageIds.length} selected',
                  style: chatAppBarTitleStyle,
                ),
                actions: [
                  if (_selectedCanCopy)
                    IconButton(
                      onPressed: _copySelectedMessage,
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  IconButton(
                    onPressed: _deleteSelectedForMe,
                    color: chatDanger,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  if (_selectedCanUnsend)
                    IconButton(
                      onPressed: _unsendSelected,
                      color: chatDanger,
                      icon: const Icon(Icons.undo_rounded),
                    ),
                  const SizedBox(width: 6),
                ],
              ),
        body: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<ChatMessage>>(
                future: _messagesFuture,
                builder: (context, snapshot) {
                  final messages = List<ChatMessage>.of(
                    snapshot.data ?? _cachedRoomMessages,
                  )..sort((a, b) => a.createdAt.compareTo(b.createdAt));
                  _scheduleInitialMessagePosition(messages);
                  if (messages.isEmpty) {
                    return _WhatsAppRoomBackground(
                      child: _conversation.isGroup
                          ? _MessageList(
                              messages: const [],
                              conversation: _conversation,
                              currentUserId: _currentUserId,
                              scrollController: _messageScrollController,
                              selectedMessageIds: _selectedMessageIds,
                              messageKeys: _messageKeys,
                              unreadDividerKey: _unreadDividerKey,
                              onMessageTap: _toggleSelectedMessage,
                              onMessageLongPress: _selectMessage,
                              onSharedPostTap: _openSharedPost,
                              onMentionTap: _openMentionProfile,
                            )
                          : const Center(
                              child: Text('Say hi with a kind message.'),
                            ),
                    );
                  }

                  return _WhatsAppRoomBackground(
                    child: Stack(
                      children: [
                        _MessageList(
                          messages: messages,
                          conversation: _conversation,
                          currentUserId: _currentUserId,
                          scrollController: _messageScrollController,
                          selectedMessageIds: _selectedMessageIds,
                          messageKeys: _messageKeys,
                          unreadDividerKey: _unreadDividerKey,
                          onMessageTap: _toggleSelectedMessage,
                          onMessageLongPress: _selectMessage,
                          onSharedPostTap: _openSharedPost,
                          onMentionTap: _openMentionProfile,
                        ),
                        if (_unvisitedMentionMessageIds.isNotEmpty)
                          Positioned(
                            key: const ValueKey('mention-navigation-button'),
                            right: 16,
                            bottom: _showJumpToBottom ? 66 : 14,
                            child: _MentionNavigationButton(
                              onTap: _visitNextMention,
                            ),
                          ),
                        if (_showJumpToBottom)
                          Positioned(
                            key: const ValueKey('jump-to-bottom-button'),
                            right: 16,
                            bottom: 14,
                            child: _JumpToBottomButton(
                              onTap: () => _scrollToLatest(jump: false),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_mentionQuery != null && _conversation.isGroup)
                      _MentionSuggestionsPanel(
                        participants: _filteredMentionParticipants,
                        showAll: _canMentionAll &&
                            ('all'.startsWith(
                              (_mentionQuery ?? '').toLowerCase(),
                            )),
                        onMemberTap: _insertMention,
                        onAllTap: () => _insertMention(null, all: true),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox.square(
                          dimension: 44,
                          child: IconButton(
                            onPressed: _isPickingImage ? null : _sendImage,
                            icon: Icon(
                              _isPickingImage
                                  ? Icons.hourglass_empty_rounded
                                  : Icons.image_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _inputFocusNode,
                            minLines: 1,
                            maxLines: 4,
                            onChanged: _handleComposerChanged,
                            decoration: InputDecoration(
                              hintText: 'Message...',
                              filled: true,
                              fillColor: chatInput,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox.square(
                          dimension: 44,
                          child: IconButton(
                            onPressed: _isSending ? null : _send,
                            color: const Color(0xFF128C7E),
                            icon: Icon(
                              _isSending
                                  ? Icons.hourglass_empty_rounded
                                  : Icons.send_rounded,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.conversation,
    required this.currentUserId,
    required this.scrollController,
    required this.selectedMessageIds,
    required this.messageKeys,
    required this.unreadDividerKey,
    required this.onMessageTap,
    required this.onMessageLongPress,
    required this.onSharedPostTap,
    required this.onMentionTap,
  });

  final List<ChatMessage> messages;
  final ChatConversation conversation;
  final String? currentUserId;
  final ScrollController scrollController;
  final Set<String> selectedMessageIds;
  final Map<String, GlobalKey> messageKeys;
  final GlobalKey unreadDividerKey;
  final ValueChanged<ChatMessage> onMessageTap;
  final ValueChanged<ChatMessage> onMessageLongPress;
  final ValueChanged<ChatSharedPost> onSharedPostTap;
  final ValueChanged<String> onMentionTap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (conversation.isGroup) {
      final createdAt = conversation.createdAt ??
          (messages.isEmpty ? DateTime.now() : messages.first.createdAt);
      children
        ..add(_DateSeparator(date: createdAt))
        ..add(
          _GroupCreationNotice(
            conversation: conversation,
            currentUserId: currentUserId,
          ),
        );
    }
    final unreadCount = conversation.unreadCount;
    final rawFirstUnreadIndex = messages.length - unreadCount;
    final firstUnreadIndex = unreadCount <= 0
        ? -1
        : rawFirstUnreadIndex < 0
            ? 0
            : rawFirstUnreadIndex > messages.length
                ? messages.length
                : rawFirstUnreadIndex;
    for (var index = 0; index < messages.length; index += 1) {
      final message = messages[index];
      final previous = index == 0 ? null : messages[index - 1];
      final alreadyShowedCreationDate =
          conversation.isGroup && previous == null;
      if (!alreadyShowedCreationDate &&
          (previous == null ||
              !_isSameDate(previous.createdAt, message.createdAt))) {
        children.add(_DateSeparator(date: message.createdAt));
      }
      if (index == firstUnreadIndex) {
        children.add(
          _UnreadMessagesDivider(
            key: unreadDividerKey,
            count: unreadCount,
          ),
        );
      }
      children.add(
        ChatMessageBubble(
          key: messageKeys.putIfAbsent(message.id, GlobalKey.new),
          body: message.body,
          isMine: message.isMine,
          isDeleted: message.isDeleted,
          isSelected: selectedMessageIds.contains(message.id),
          isSelectionMode: selectedMessageIds.isNotEmpty,
          createdAt: message.createdAt,
          showSenderName: conversation.isGroup,
          senderName: message.senderName ?? 'Member',
          previewSenderName: message.isMine
              ? 'You'
              : (message.senderName ?? conversation.displayTitle),
          onTap: () => onMessageTap(message),
          onLongPress: () => onMessageLongPress(message),
          onSharedPostTap: onSharedPostTap,
          mentions: message.mentions,
          onMentionTap: onMentionTap,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: scrollController,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: children,
            ),
          ),
        );
      },
    );
  }
}

class _JumpToBottomButton extends StatelessWidget {
  const _JumpToBottomButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF128C7E),
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _MentionNavigationButton extends StatelessWidget {
  const _MentionNavigationButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox.square(
          dimension: 42,
          child: Center(
            child: Text(
              '@',
              style: TextStyle(
                color: Color(0xFF166534),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MentionSuggestionsPanel extends StatelessWidget {
  const _MentionSuggestionsPanel({
    required this.participants,
    required this.showAll,
    required this.onMemberTap,
    required this.onAllTap,
  });

  final List<ChatParticipant> participants;
  final bool showAll;
  final ValueChanged<ChatParticipant> onMemberTap;
  final VoidCallback onAllTap;

  @override
  Widget build(BuildContext context) {
    if (!showAll && participants.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: chatBorder),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: [
          if (showAll)
            ListTile(
              key: const ValueKey('mention-all-suggestion'),
              dense: true,
              leading: const CircleAvatar(child: Text('@')),
              title: const Text('@all',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Notify every group member'),
              onTap: onAllTap,
            ),
          ...participants.map((person) => ListTile(
                key: ValueKey('mention-suggestion-${person.id}'),
                dense: true,
                leading: ChatAvatar(
                  name: person.name,
                  avatarUrl: person.avatarUrl,
                  size: 36,
                ),
                title: Text(person.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => onMemberTap(person),
              )),
        ],
      ),
    );
  }
}

class _GroupCreationNotice extends StatelessWidget {
  const _GroupCreationNotice({
    required this.conversation,
    required this.currentUserId,
  });

  final ChatConversation conversation;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final isMine = conversation.createdBy != null &&
        currentUserId != null &&
        conversation.createdBy == currentUserId;
    final creator = isMine ? 'You' : (conversation.createdByName ?? 'Someone');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.76,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
          ),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.25,
              ),
              children: [
                TextSpan(
                  text: creator,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const TextSpan(text: ' created the group chat'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            _formatDateSeparator(date),
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadMessagesDivider extends StatelessWidget {
  const _UnreadMessagesDivider({
    super.key,
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 unread message' : '$count unread messages';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }
}

bool _isSameDate(DateTime a, DateTime b) {
  final first = a.toLocal();
  final second = b.toLocal();
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

String _formatDateSeparator(DateTime value) {
  final now = DateTime.now();
  final local = value.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final difference = today.difference(date).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return '${local.day}/${local.month}/${local.year}';
}

class _WhatsAppRoomBackground extends StatelessWidget {
  const _WhatsAppRoomBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: chatWhatsappBackground,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _ChatWallpaperPainter()),
          ),
          child,
        ],
      ),
    );
  }
}

class _ChatWallpaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const spacing = 72.0;
    for (var y = 24.0; y < size.height; y += spacing) {
      for (var x = 18.0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 10, paint);
        canvas.drawLine(Offset(x + 22, y - 8), Offset(x + 34, y + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
