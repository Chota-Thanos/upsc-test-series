import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/mentor_service.dart';
import '../models/mentor_models.dart';

enum _LoadState { loading, permissionDenied, error, ready }

/// 1:1 mentorship video call. Unlike the live-class room, both participants
/// here are symmetric -- each publishes and subscribes video/audio, so this
/// is a plain two-tile call with no host/audience or raise-hand distinction.
class MentorshipVideoCallScreen extends StatefulWidget {
  final int sessionId;

  const MentorshipVideoCallScreen({super.key, required this.sessionId});

  @override
  State<MentorshipVideoCallScreen> createState() =>
      _MentorshipVideoCallScreenState();
}

class _MentorshipVideoCallScreenState
    extends State<MentorshipVideoCallScreen> {
  RtcEngine? _engine;
  MentorshipCallCredentials? _credentials;
  _LoadState _loadState = _LoadState.loading;
  String? _errorMessage;

  bool _joined = false;
  bool _micMuted = false;
  bool _cameraOff = false;
  int? _remoteUid;
  late final MentorService _service;

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = MentorService(apiClient: apiClient);
    _setup();
  }

  @override
  void dispose() {
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
      final credentials = await _service.getAgoraToken(widget.sessionId);
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
            setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!mounted) return;
            setState(() {
              if (_remoteUid == remoteUid) _remoteUid = null;
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
              _remoteUid = null;
            });
          },
        ),
      );

      await engine.enableVideo();
      await engine.startPreview();

      await engine.joinChannel(
        token: credentials.token ?? '',
        channelId: credentials.channelName,
        uid: credentials.uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
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

  Future<void> _leaveCall() async {
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openBackupLink() async {
    final link = _credentials?.meetingLink;
    if (link == null) return;
    final url = Uri.parse(link);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $link");
    }
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
              'Allow camera and microphone access in your device settings to join this call.',
        );
      case _LoadState.error:
        return _buildMessageState(
          icon: Icons.error_outline_rounded,
          title: "Couldn't join the call",
          message: _errorMessage ?? 'Something went wrong.',
          showBackupLink: true,
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
    bool showBackupLink = false,
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
            if (showBackupLink && _credentials?.meetingLink != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _openBackupLink,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white38),
                ),
                child: const Text(
                  'Try Backup Meeting Link',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
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
    final engine = _engine!;
    final credentials = _credentials!;

    return Stack(
      children: [
        Positioned.fill(
          child: _remoteUid == null
              ? Container(
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
                          'Waiting for the other participant to join…',
                          style: AppTypography.body.copyWith(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: engine,
                    canvas: VideoCanvas(uid: _remoteUid),
                    connection: RtcConnection(channelId: credentials.channelName),
                  ),
                ),
        ),

        Positioned(
          top: 12,
          right: 12,
          child: SizedBox(
            width: 96,
            height: 130,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: _cameraOff
                  ? Container(color: Colors.white10)
                  : AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: engine,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
            ),
          ),
        ),

        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              'Mentorship Session #${widget.sessionId}',
              style: AppTypography.eyebrowSmall.copyWith(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ),
        ),

        if (_credentials?.meetingLink != null)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton(
                onPressed: _openBackupLink,
                child: Text(
                  'Trouble joining? Use backup link',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white54,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIconButton(
                  icon: _micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  background: _micMuted ? Colors.white24 : Colors.black45,
                  onPressed: _toggleMic,
                ),
                const SizedBox(width: 16),
                _buildIconButton(
                  icon: Icons.call_end_rounded,
                  background: AppColors.berry,
                  onPressed: _leaveCall,
                ),
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
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? background,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: background ?? Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
