import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/video_item.dart';
import '../../data/short_item.dart';
import '../../data/short_store.dart';
import '../player/player_screen.dart';
import '../shorts/shorts_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.onThemeChanged,
    required this.themeSliderValue,
  });

  final void Function(double) onThemeChanged;
  final double themeSliderValue;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  VideoItem? _activeItem;
  VideoPlayerController? _playerController;
  bool _miniActive = false;

  Future<void> _openVideo(VideoItem item) async {
    _activeItem = item;
    _miniActive = false;

    _playerController?.dispose();
    _playerController =
        VideoPlayerController.networkUrl(Uri.parse(item.playbackUrl));
    await _playerController!.initialize();
    await _playerController!.play();

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          video: item,
          controller: _playerController!,
          onEnterMini: () {
            _miniActive = true;
            Navigator.of(context).pop();
            setState(() {});
          },
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          value: widget.themeSliderValue,
          onThemeChanged: widget.onThemeChanged,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _playerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: [
              HomeScreen(
                onOpenVideo: _openVideo,
                onProfile: _openSettings,
              ),
              ShortsScreen(
                shorts: demoShorts,
                onOpenShort: (ShortItem s) => _openVideo(s.toVideoItem()),
              ),
              const _PlaceholderScreen(label: 'Publish'),
              const _PlaceholderScreen(label: 'Subscriptions'),
              const _PlaceholderScreen(label: 'Library'),
            ],
          ),
          if (_miniActive && _playerController != null && _activeItem != null)
            _MiniPlayerOverlay(
              controller: _playerController!,
              title: _activeItem!.title,
              onTap: () async {
                _miniActive = false;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlayerScreen(
                      video: _activeItem!,
                      controller: _playerController!,
                      onEnterMini: () {
                        _miniActive = true;
                        Navigator.of(context).pop();
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
              onClose: () {
                _miniActive = false;
                _playerController?.dispose();
                _playerController = null;
                _activeItem = null;
                setState(() {});
              },
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_arrow_outlined),
            selectedIcon: Icon(Icons.play_arrow),
            label: 'Shorts',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.subscriptions_outlined),
            selectedIcon: Icon(Icons.subscriptions),
            label: 'Subscriptions',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Text(
          'Раздел «$label» временно недоступен',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _MiniPlayerOverlay extends StatefulWidget {
  const _MiniPlayerOverlay({
    required this.controller,
    required this.title,
    required this.onTap,
    required this.onClose,
  });

  final VideoPlayerController controller;
  final String title;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<_MiniPlayerOverlay> createState() => _MiniPlayerOverlayState();
}

class _MiniPlayerOverlayState extends State<_MiniPlayerOverlay> {
  Offset _offset = const Offset(16, 16);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width * 0.5;
    final height = width * 9 / 16 + 40;
    final initialized = widget.controller.value.isInitialized;

    return Positioned(
      right: _offset.dx,
      bottom: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _offset = Offset(
              (_offset.dx - details.delta.dx).clamp(8, size.width - width - 8),
              (_offset.dy - details.delta.dy).clamp(8, size.height - height - 8),
            );
          });
        },
        onTap: widget.onTap,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: width,
            height: height,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    color: Colors.black,
                    child: initialized
                        ? FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: widget.controller.value.size.width,
                              height: widget.controller.value.size.height,
                              child: VideoPlayer(widget.controller),
                            ),
                          )
                        : const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                  ),
                ),
                Container(
                  color: Colors.black87,
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close, color: Colors.white),
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
}
