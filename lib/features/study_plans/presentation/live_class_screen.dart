import 'dart:convert';
import 'dart:typed_data';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/study_plan_service.dart';
import '../models/study_plan_models.dart';

/// A chat message or system note shown in the live-class chat panel.
class _ChatMessage {
  final int uid;
  final String name;
  final String text;
  final bool isMe;

  _ChatMessage({
    required this.uid,
    required this.name,
    required this.text,
    this.isMe = false,
  });
}

/// Joins a live class as either the broadcaster (host/staff) or audience
/// (enrolled student), per the role the backend issues in the Agora token.
/// The caller is responsible for calling [StudyPlanService.startLiveClass]
/// before navigating here as host, and for only offering "Join" to students
/// once the class's status is 'live'.
///
/// Also carries a lightweight chat + "raise hand to speak" flow over Agora's
/// own RTC data stream (no separate backend/schema): chat is open and
/// instant for everyone, but only the host can grant a raised hand, which
/// promotes that one student from audience to broadcaster so they can
/// unmute and ask their question out loud. Scoped to the live session only
/// -- nothing here is persisted once the call ends.
class LiveClassScreen extends StatefulWidget {
  final int liveClassId;
  final String title;

  const LiveClassScreen({
    super.key,
    required this.liveClassId,
    required this.title,
  });

  @override
  State<LiveClassScreen> createState() => _LiveClassScreenState();
}

enum _LoadState { loading, permissionDenied, error, ready }

class _LiveClassScreenState extends State<LiveClassScreen> {
  RtcEngine? _engine;
  AgoraJoinCredentials? _credentials;
  _LoadState _loadState = _LoadState.loading;
  String? _errorMessage;

  bool _joined = false;
  bool _micMuted = false;
  bool _cameraOff = false;
  final Set<int> _remoteUids = {};
  late final StudyPlanService _service;
  String _displayName = 'You';

  int? _dataStreamId;
  final List<_ChatMessage> _messages = [];
  final ScrollController _chatScrollController = ScrollController();
  final TextEditingController _chatInputController = TextEditingController();
  bool _chatOpen = false;
  bool _hasUnread = false;

  bool _handRaised = false;
  bool _grantedToSpeak = false;
  final Map<int, String> _raisedHandRequests = {};

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = StudyPlanService(apiClient: apiClient);
    _displayName =
        (apiClient.user?['username'] as String?)?.trim().isNotEmpty == true
        ? apiClient.user!['username'] as String
        : 'You';
    _setup();
  }

  @override
  void dispose() {
    _chatScrollController.dispose();
    _chatInputController.dispose();
    _teardown();
    super.dispose();
  }

  Future<void> _teardown() async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.leaveChannel();
      await engine.release();
    } catch (_) {
      // Best-effort cleanup -- the screen is closing regardless.
    }
  }

  Future<void> _setup() async {
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!camera.isGranted || !mic.isGranted) {
      if (!mounted) return;
      setState(() => _loadState = _LoadState.permissionDenied);
      return;
    }

    try {
      final credentials = await _service.getLiveClassToken(widget.liveClassId);
      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: credentials.appId));

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (!mounted) return;
            setState(() => _joined = true);
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!mounted) return;
            setState(() => _remoteUids.add(remoteUid));
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!mounted) return;
            setState(() {
              _remoteUids.remove(remoteUid);
              _raisedHandRequests.remove(remoteUid);
            });
          },
          onError: (err, msg) {
            if (!mounted) return;
            setState(() {
              _loadState = _LoadState.error;
              _errorMessage = msg;
            });
          },
          onLeaveChannel: (connection, stats) {
            if (!mounted) return;
            setState(() {
              _joined = false;
              _remoteUids.clear();
            });
          },
          onStreamMessage:
              (connection, remoteUid, streamId, data, length, sentTs) {
                _handleStreamMessage(remoteUid, data);
              },
        ),
      );

      await engine.enableVideo();
      if (credentials.isHost) {
        await engine.startPreview();
      }

      await engine.joinChannel(
        token: credentials.token ?? '',
        channelId: credentials.channelName,
        uid: credentials.uid,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: credentials.isHost
              ? ClientRoleType.clientRoleBroadcaster
              : ClientRoleType.clientRoleAudience,
        ),
      );

      _dataStreamId = await engine.createDataStream(
        const DataStreamConfig(syncWithAudio: false, ordered: true),
      );

      if (!mounted) return;
      setState(() {
        _engine = engine;
        _credentials = credentials;
        _loadState = _LoadState.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadState = _LoadState.error;
        _errorMessage = e.toString();
      });
    }
  }

  // --- Chat + raise-hand protocol, over Agora's own RTC data stream ---

  void _handleStreamMessage(int remoteUid, Uint8List data) {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = payload['type'] as String?;
    final isHost = _credentials?.isHost ?? false;
    final myUid = _credentials?.uid;

    switch (type) {
      case 'chat':
        if (!mounted) return;
        setState(() {
          _messages.add(
            _ChatMessage(
              uid: remoteUid,
              name: payload['name'] as String? ?? 'Guest',
              text: payload['text'] as String? ?? '',
            ),
          );
          if (!_chatOpen) _hasUnread = true;
        });
        _scrollChatToBottom();
        break;
      case 'raise_hand':
        if (!isHost || !mounted) return;
        setState(
          () => _raisedHandRequests[remoteUid] =
              payload['name'] as String? ?? 'Student',
        );
        break;
      case 'lower_hand':
        if (!isHost || !mounted) return;
        setState(() => _raisedHandRequests.remove(remoteUid));
        break;
      case 'grant_speak':
        if (payload['uid'] != myUid || !mounted) return;
        _becomeSpeaker();
        break;
      case 'deny_speak':
        if (payload['uid'] != myUid || !mounted) return;
        setState(() => _handRaised = false);
        break;
      case 'revoke_speak':
        if (payload['uid'] != myUid || !mounted) return;
        _stopSpeaking();
        break;
    }
  }

  Future<void> _sendStreamJson(Map<String, dynamic> payload) async {
    final engine = _engine;
    final streamId = _dataStreamId;
    if (engine == null || streamId == null) return;
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    try {
      await engine.sendStreamMessage(
        streamId: streamId,
        data: bytes,
        length: bytes.length,
      );
    } catch (_) {
      // Best-effort -- a dropped chat/signal packet isn't worth surfacing an error for.
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendChatMessage() async {
    final text = _chatInputController.text.trim();
    final credentials = _credentials;
    if (text.isEmpty || credentials == null) return;
    _chatInputController.clear();
    setState(() {
      _messages.add(
        _ChatMessage(
          uid: credentials.uid,
          name: _displayName,
          text: text,
          isMe: true,
        ),
      );
    });
    _scrollChatToBottom();
    await _sendStreamJson({'type': 'chat', 'name': _displayName, 'text': text});
  }

  Future<void> _toggleRaiseHand() async {
    if (_grantedToSpeak) return;
    setState(() => _handRaised = !_handRaised);
    await _sendStreamJson({
      'type': _handRaised ? 'raise_hand' : 'lower_hand',
      'name': _displayName,
    });
  }

  Future<void> _approveRaisedHand(int uid) async {
    setState(() => _raisedHandRequests.remove(uid));
    await _sendStreamJson({'type': 'grant_speak', 'uid': uid});
  }

  Future<void> _denyRaisedHand(int uid) async {
    setState(() => _raisedHandRequests.remove(uid));
    await _sendStreamJson({'type': 'deny_speak', 'uid': uid});
  }

  Future<void> _becomeSpeaker() async {
    final engine = _engine;
    if (engine == null) return;
    await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await engine.enableLocalAudio(true);
    await engine.muteLocalAudioStream(false);
    if (!mounted) return;
    setState(() {
      _grantedToSpeak = true;
      _handRaised = false;
      _micMuted = false;
    });
  }

  Future<void> _stopSpeaking() async {
    final engine = _engine;
    final credentials = _credentials;
    if (engine == null || credentials == null) return;
    await engine.muteLocalAudioStream(true);
    await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
    if (credentials.isHost) return;
    if (!mounted) return;
    setState(() {
      _grantedToSpeak = false;
      _micMuted = true;
    });
  }

  // --- Standard call controls ---

  Future<void> _toggleMic() async {
    final engine = _engine;
    if (engine == null) return;
    await engine.muteLocalAudioStream(!_micMuted);
    setState(() => _micMuted = !_micMuted);
  }

  Future<void> _toggleCamera() async {
    final engine = _engine;
    if (engine == null) return;
    await engine.muteLocalVideoStream(!_cameraOff);
    setState(() => _cameraOff = !_cameraOff);
  }

  Future<void> _endClassAndLeave() async {
    final isHost = _credentials?.isHost ?? false;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (isHost) {
      try {
        await _service.endLiveClass(widget.liveClassId);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not end class on server: $e')),
        );
      }
    }
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    switch (_loadState) {
      case _LoadState.loading:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      case _LoadState.permissionDenied:
        return _buildMessageState(
          icon: Icons.videocam_off_rounded,
          title: 'Camera & microphone needed',
          message:
              'Allow camera and microphone access in your device settings to join this live class.',
        );
      case _LoadState.error:
        return _buildMessageState(
          icon: Icons.error_outline_rounded,
          title: "Couldn't join the class",
          message: _errorMessage ?? 'Something went wrong.',
        );
      case _LoadState.ready:
        return _joined
            ? _buildLiveView()
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
    }
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.cardTitle.copyWith(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Go back',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveView() {
    final credentials = _credentials!;
    final engine = _engine!;
    final isHost = credentials.isHost;

    return Stack(
      children: [
        Positioned.fill(child: _buildMainVideo(engine, isHost)),

        if (isHost && _remoteUids.isNotEmpty)
          Positioned(
            top: 12,
            right: 12,
            child: SizedBox(
              width: 96,
              height: 130,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: engine,
                    canvas: VideoCanvas(uid: _remoteUids.first),
                    connection: RtcConnection(
                      channelId: credentials.channelName,
                    ),
                  ),
                ),
              ),
            ),
          ),

        Positioned(
          top: 12,
          left: 12,
          child: Row(
            children: [
              _buildLiveBadge(),
              const SizedBox(width: 8),
              _buildParticipantChip(isHost),
            ],
          ),
        ),

        Positioned(
          top: 12,
          right: isHost && _remoteUids.isNotEmpty ? 116 : 12,
          child: Row(
            children: [
              if (isHost) ...[
                _buildIconButton(
                  icon: Icons.front_hand_rounded,
                  onPressed: _showRaisedHandRequests,
                  background: _raisedHandRequests.isNotEmpty
                      ? AppColors.saffron
                      : Colors.black45,
                  badgeCount: _raisedHandRequests.length,
                ),
                const SizedBox(width: 8),
              ],
              _buildIconButton(
                icon: Icons.close_rounded,
                onPressed: _endClassAndLeave,
              ),
            ],
          ),
        ),

        if (_grantedToSpeak)
          Positioned(
            top: 60,
            left: 12,
            right: 12,
            child: _buildSpeakingBanner(),
          ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(child: _buildControlsBar(isHost)),
        ),

        Positioned(right: 12, bottom: 96, child: _buildChatToggleButton()),

        if (_chatOpen)
          Positioned(left: 0, right: 0, bottom: 0, child: _buildChatPanel()),
      ],
    );
  }

  Widget _buildMainVideo(RtcEngine engine, bool isHost) {
    if (isHost) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: engine,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    }

    if (_remoteUids.isEmpty) {
      return Container(
        color: const Color(0xFF0F172A),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white54,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Waiting for the host to start video…',
                style: AppTypography.body.copyWith(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: _remoteUids.first),
        connection: RtcConnection(channelId: _credentials!.channelName),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.berry,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'LIVE',
            style: AppTypography.eyebrowSmall.copyWith(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantChip(bool isHost) {
    final count = isHost ? _remoteUids.length : _remoteUids.length + 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_alt_rounded, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakingBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.emerald,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "You're live — go ahead and ask your question",
              style: AppTypography.cardTitle.copyWith(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: _stopSpeaking,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
            ),
            child: Text(
              'Done',
              style: AppTypography.button.copyWith(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? background,
    int badgeCount = 0,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: background ?? Colors.black45,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: const BoxDecoration(
                color: AppColors.berry,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$badgeCount',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChatToggleButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildIconButton(
          icon: _chatOpen
              ? Icons.expand_more_rounded
              : Icons.chat_bubble_outline_rounded,
          onPressed: () => setState(() {
            _chatOpen = !_chatOpen;
            if (_chatOpen) {
              _hasUnread = false;
              _scrollChatToBottom();
            }
          }),
        ),
        if (_hasUnread && !_chatOpen)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: AppColors.saffron,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControlsBar(bool isHost) {
    final canSpeak = isHost || _grantedToSpeak;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canSpeak)
          _buildIconButton(
            icon: _micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            background: _micMuted ? Colors.white24 : Colors.black45,
            onPressed: _toggleMic,
          )
        else
          _buildIconButton(
            icon: _handRaised
                ? Icons.front_hand_rounded
                : Icons.back_hand_outlined,
            background: _handRaised ? AppColors.saffron : Colors.black45,
            onPressed: _toggleRaiseHand,
          ),
        const SizedBox(width: 16),
        _buildIconButton(
          icon: Icons.call_end_rounded,
          background: AppColors.berry,
          onPressed: _endClassAndLeave,
        ),
        if (isHost) ...[
          const SizedBox(width: 16),
          _buildIconButton(
            icon: _cameraOff
                ? Icons.videocam_off_rounded
                : Icons.videocam_rounded,
            background: _cameraOff ? Colors.white24 : Colors.black45,
            onPressed: _toggleCamera,
          ),
          const SizedBox(width: 16),
          _buildIconButton(
            icon: Icons.cameraswitch_rounded,
            onPressed: () => _engine?.switchCamera(),
          ),
        ],
      ],
    );
  }

  Widget _buildChatPanel() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xE6111827),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet — say hello.',
                      style: AppTypography.body.copyWith(
                        color: Colors.white38,
                        fontSize: 12.5,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _buildChatBubble(_messages[index]),
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              10,
              6,
              10,
              MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 14,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatInputController,
                    style: AppTypography.body.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask a question…',
                      hintStyle: AppTypography.body.copyWith(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendChatMessage(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                _buildIconButton(
                  icon: Icons.send_rounded,
                  background: AppColors.civic,
                  onPressed: _sendChatMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(_ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: message.isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            message.isMe ? 'You' : message.name,
            style: AppTypography.cardTitle.copyWith(
              color: Colors.white54,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: message.isMe ? AppColors.civic : Colors.white10,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              message.text,
              style: AppTypography.body.copyWith(
                color: Colors.white,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRaisedHandRequests() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final entries = _raisedHandRequests.entries.toList();
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Raised hands',
                    style: AppTypography.statValue.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No pending requests.',
                        style: AppTypography.body.copyWith(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    ...entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.value,
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                _denyRaisedHand(entry.key);
                                setSheetState(() {});
                                if (_raisedHandRequests.isEmpty &&
                                    sheetContext.mounted)
                                  Navigator.of(sheetContext).pop();
                              },
                              child: Text(
                                'Deny',
                                style: AppTypography.button.copyWith(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              style: AppButtonStyles.filled(
                                color: AppColors.emerald,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                radius: AppRadius.md,
                              ),
                              onPressed: () {
                                _approveRaisedHand(entry.key);
                                setSheetState(() {});
                                if (_raisedHandRequests.isEmpty &&
                                    sheetContext.mounted)
                                  Navigator.of(sheetContext).pop();
                              },
                              child: Text('Allow', style: AppTypography.button),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
