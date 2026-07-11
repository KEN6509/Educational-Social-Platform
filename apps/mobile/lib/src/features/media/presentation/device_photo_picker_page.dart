import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

class DevicePhotoPickerPage extends StatefulWidget {
  const DevicePhotoPickerPage({
    required this.maxSelection,
    this.allowCamera = false,
    super.key,
  });

  final int maxSelection;
  final bool allowCamera;

  @override
  State<DevicePhotoPickerPage> createState() => _DevicePhotoPickerPageState();
}

class _DevicePhotoPickerPageState extends State<DevicePhotoPickerPage> {
  static const _assetPageSize = 200;

  final ImagePicker _cameraPicker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _album;
  bool _isLoading = true;
  bool _hasPermission = true;
  bool _showAlbums = false;
  bool _isLoadingMore = false;
  bool _hasMoreAssets = false;
  int _assetPage = 0;
  int _assetTotal = 0;

  bool get _isSingle => widget.maxSelection == 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadAlbums();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_hasMoreAssets || _isLoadingMore || !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 720) {
      _loadMoreAssets();
    }
  }

  Future<void> _loadAlbums() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      if (!mounted) return;
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(
            type: OrderOptionType.createDate,
            asc: false,
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      _albums = albums;
      _album = albums.isEmpty ? null : albums.first;
    });
    await _loadAssets();
  }

  Future<void> _loadAssets() async {
    final album = _album;
    if (album == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    final total = await album.assetCountAsync;
    final assets = await album.getAssetListPaged(page: 0, size: _assetPageSize);
    if (!mounted) return;
    setState(() {
      _assets
        ..clear()
        ..addAll(assets);
      _selected.removeWhere((asset) => !_assets.any((a) => a.id == asset.id));
      _assetPage = 1;
      _assetTotal = total;
      _hasMoreAssets = _assets.length < _assetTotal;
      _isLoading = false;
    });
  }

  Future<void> _loadMoreAssets() async {
    final album = _album;
    if (album == null || _isLoadingMore || !_hasMoreAssets) return;
    setState(() => _isLoadingMore = true);
    final assets = await album.getAssetListPaged(
      page: _assetPage,
      size: _assetPageSize,
    );
    if (!mounted) return;
    setState(() {
      _assets.addAll(assets);
      _assetPage += 1;
      _hasMoreAssets = assets.isNotEmpty && _assets.length < _assetTotal;
      _isLoadingMore = false;
    });
  }

  Future<void> _takePhoto() async {
    final image = await _cameraPicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 86,
    );
    if (image == null || !mounted) return;
    Navigator.pop(context, [image]);
  }

  void _toggleAsset(AssetEntity asset) {
    final existingIndex = _selected.indexWhere((item) => item.id == asset.id);
    if (_isSingle) {
      _returnSingleAsset(asset);
      return;
    }
    if (existingIndex < 0 && _selected.length >= widget.maxSelection) {
      return;
    }
    setState(() {
      if (existingIndex >= 0) {
        _selected.removeAt(existingIndex);
      } else if (_selected.length < widget.maxSelection) {
        _selected.add(asset);
      }
    });
  }

  Future<void> _returnSingleAsset(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null || !mounted) return;
    Navigator.pop(context, [XFile(file.path)]);
  }

  Future<void> _done() async {
    final files = <XFile>[];
    for (final asset in _selected) {
      final file = await asset.file;
      if (file != null) {
        files.add(XFile(file.path));
      }
    }
    if (!mounted) return;
    Navigator.pop(context, files);
  }

  Future<void> _previewSelected() async {
    if (_selected.isEmpty) return;
    final result = await Navigator.of(context).push<_PhotoPreviewResult>(
      MaterialPageRoute(
        builder: (_) => _PhotoPreviewPage(
          assets: List<AssetEntity>.from(_selected),
          initialIndex: 0,
          selected: List<AssetEntity>.from(_selected),
          maxSelection: widget.maxSelection,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(result.selected);
    });
    if (result.done) {
      await _done();
    }
  }

  Future<void> _changeAlbum(AssetPathEntity? album) async {
    if (album == null) return;
    setState(() {
      _album = album;
      _showAlbums = false;
    });
    await _loadAssets();
  }

  Future<void> _previewAsset(AssetEntity asset) async {
    if (_isSingle) {
      await _returnSingleAsset(asset);
      return;
    }
    final initialIndex = _assets.indexWhere((item) => item.id == asset.id);
    final result = await Navigator.of(context).push<_PhotoPreviewResult>(
      MaterialPageRoute(
        builder: (_) => _PhotoPreviewPage(
          assets: List<AssetEntity>.from(_assets),
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
          selected: List<AssetEntity>.from(_selected),
          maxSelection: widget.maxSelection,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(result.selected);
    });
    if (result.done) {
      await _done();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFBFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: Color(0xFF111827)),
        ),
        title: _AlbumSelectorChip(
          selectedAlbum: _album,
          isExpanded: _showAlbums,
          onTap: () => setState(() => _showAlbums = !_showAlbums),
        ),
        centerTitle: true,
        actions: const [SizedBox(width: 48)],
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_showAlbums)
            _AlbumDropdownPanel(
              albums: _albums,
              selectedAlbum: _album,
              onSelect: _changeAlbum,
              onDismiss: () => setState(() => _showAlbums = false),
            ),
        ],
      ),
      bottomNavigationBar: _isSingle
          ? null
          : _PhotoPickerBottomBar(
              selectedCount: _selected.length,
              onPreview: _selected.isEmpty ? null : _previewSelected,
              onDone: _selected.isEmpty ? null : _done,
            ),
    );
  }

  Widget _buildBody() {
    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: 40,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 12),
              const Text(
                'Allow photo access to choose from your device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: PhotoManager.openSetting,
                child: const Text('Open settings'),
              ),
            ],
          ),
        ),
      );
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_assets.isEmpty && !widget.allowCamera) {
      return const Center(
        child: Text(
          'No photos in this folder',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (widget.allowCamera)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(2, 12, 2, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              delegate: SliverChildListDelegate([
                _CameraGridTile(onTap: _takePhoto),
              ]),
            ),
          ),
        ..._buildGroupedPhotoSlivers(),
        if (_isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildGroupedPhotoSlivers() {
    final groups = <String, List<AssetEntity>>{};
    for (final asset in _assets) {
      final key = _monthLabel(asset.createDateTime);
      groups.putIfAbsent(key, () => []).add(asset);
    }

    return [
      for (final entry in groups.entries) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: Text(
              entry.key,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final asset = entry.value[index];
                final selectedIndex =
                    _selected.indexWhere((item) => item.id == asset.id);
                final isBlocked = !_isSingle &&
                    selectedIndex < 0 &&
                    _selected.length >= widget.maxSelection;
                return _PhotoTile(
                  asset: asset,
                  selectedIndex: selectedIndex,
                  showSelectionControl: !_isSingle,
                  isBlocked: isBlocked,
                  onPreview: () => _previewAsset(asset),
                  onToggle: () => _toggleAsset(asset),
                );
              },
              childCount: entry.value.length,
            ),
          ),
        ),
      ],
    ];
  }

  String _monthLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month) {
      return 'This Month';
    }
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _CameraGridTile extends StatelessWidget {
  const _CameraGridTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F5F9),
      child: InkWell(
        onTap: onTap,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_camera_rounded, color: Color(0xFF0B1F3E)),
            SizedBox(height: 6),
            Text(
              'Camera',
              style: TextStyle(
                color: Color(0xFF0B1F3E),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.asset,
    required this.selectedIndex,
    required this.showSelectionControl,
    required this.isBlocked,
    required this.onPreview,
    required this.onToggle,
  });

  final AssetEntity asset;
  final int selectedIndex;
  final bool showSelectionControl;
  final bool isBlocked;
  final VoidCallback onPreview;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndex >= 0;
    return GestureDetector(
      onTap: onPreview,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: asset.thumbnailDataWithSize(
              const ThumbnailSize.square(280),
              quality: 82,
            ),
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null) {
                return Container(color: const Color(0xFFF3F4F6));
              }
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              );
            },
          ),
          if (isSelected) Container(color: Colors.black.withValues(alpha: 0.2)),
          if (isBlocked) Container(color: Colors.black.withValues(alpha: 0.38)),
          if (showSelectionControl)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: isBlocked ? null : onToggle,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      margin: const EdgeInsets.all(7),
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF4490AD)
                            : isBlocked
                                ? Colors.black54
                                : Colors.black26,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.6),
                      ),
                      child: Center(
                        child: isSelected
                            ? Text(
                                '${selectedIndex + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlbumSelectorChip extends StatelessWidget {
  const _AlbumSelectorChip({
    required this.selectedAlbum,
    required this.isExpanded,
    required this.onTap,
  });

  final AssetPathEntity? selectedAlbum;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              selectedAlbum?.name ?? 'Photos',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          AnimatedRotation(
            turns: isExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 21,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumDropdownPanel extends StatelessWidget {
  const _AlbumDropdownPanel({
    required this.albums,
    required this.selectedAlbum,
    required this.onSelect,
    required this.onDismiss,
  });

  final List<AssetPathEntity> albums;
  final AssetPathEntity? selectedAlbum;
  final ValueChanged<AssetPathEntity?> onSelect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.18),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismiss,
              child: const SizedBox.expand(),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.52,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                  bottom: BorderSide(color: Color(0xFFE5E7EB)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: albums.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  indent: 72,
                  color: Color(0xFFF1F5F9),
                ),
                itemBuilder: (context, index) {
                  final album = albums[index];
                  final isSelected = album.id == selectedAlbum?.id;
                  return _AlbumRow(
                    album: album,
                    isSelected: isSelected,
                    onTap: () => onSelect(album),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumRow extends StatelessWidget {
  const _AlbumRow({
    required this.album,
    required this.isSelected,
    required this.onTap,
  });

  final AssetPathEntity album;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 68,
        child: Row(
          children: [
            const SizedBox(width: 12),
            _AlbumThumbnail(album: album),
            const SizedBox(width: 12),
            Expanded(
              child: FutureBuilder<int>(
                future: album.assetCountAsync,
                builder: (context, snapshot) {
                  final count = snapshot.data;
                  return Text(
                    count == null ? album.name : '${album.name} ($count)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(right: 18),
                child: Icon(
                  Icons.check_rounded,
                  color: Color(0xFF4490AD),
                  size: 23,
                ),
              )
            else
              const SizedBox(width: 41),
          ],
        ),
      ),
    );
  }
}

class _AlbumThumbnail extends StatelessWidget {
  const _AlbumThumbnail({required this.album});

  final AssetPathEntity album;

  Future<Uint8List?> _loadThumb() async {
    final assets = await album.getAssetListRange(start: 0, end: 1);
    if (assets.isEmpty) return null;
    return assets.first.thumbnailDataWithSize(
      const ThumbnailSize.square(120),
      quality: 78,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: FutureBuilder<Uint8List?>(
        future: _loadThumb(),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            return Container(
              width: 48,
              height: 48,
              color: const Color(0xFFF3F4F6),
            );
          }
          return Image.memory(
            bytes,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        },
      ),
    );
  }
}

class _PhotoPickerBottomBar extends StatelessWidget {
  const _PhotoPickerBottomBar({
    required this.selectedCount,
    required this.onPreview,
    required this.onDone,
  });

  final int selectedCount;
  final VoidCallback? onPreview;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final suffix = selectedCount > 0 ? '($selectedCount)' : '';

    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: onPreview,
            style: TextButton.styleFrom(
              minimumSize: const Size(84, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              foregroundColor: const Color(0xFF4490AD),
            ),
            child: Text(
              'Preview$suffix',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4490AD),
              disabledBackgroundColor: const Color(0xFF4490AD),
              disabledForegroundColor: Colors.white,
              minimumSize: const Size(88, 34),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
            child: Text(
              'Done$suffix',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPreviewResult {
  const _PhotoPreviewResult({
    required this.selected,
    required this.done,
  });

  final List<AssetEntity> selected;
  final bool done;
}

class _PhotoPreviewPage extends StatefulWidget {
  const _PhotoPreviewPage({
    required this.assets,
    required this.initialIndex,
    required this.selected,
    required this.maxSelection,
  });

  final List<AssetEntity> assets;
  final int initialIndex;
  final List<AssetEntity> selected;
  final int maxSelection;

  @override
  State<_PhotoPreviewPage> createState() => _PhotoPreviewPageState();
}

class _PhotoPreviewPageState extends State<_PhotoPreviewPage> {
  late final PageController _pageController;
  late final List<AssetEntity> _selected;
  late final List<AssetEntity> _stripAssets;
  late int _index;

  AssetEntity get _current => widget.assets[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.assets.length - 1);
    _pageController = PageController(initialPage: _index);
    _selected = List<AssetEntity>.from(widget.selected);
    _stripAssets = List<AssetEntity>.from(widget.selected);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _contains(List<AssetEntity> list, AssetEntity asset) {
    return list.any((item) => item.id == asset.id);
  }

  int _selectedIndex(AssetEntity asset) {
    return _selected.indexWhere((item) => item.id == asset.id);
  }

  void _toggleCurrent() {
    final existingIndex = _selectedIndex(_current);
    setState(() {
      if (existingIndex >= 0) {
        _selected.removeAt(existingIndex);
      } else if (_selected.length < widget.maxSelection) {
        _selected.add(_current);
        if (!_contains(_stripAssets, _current)) {
          _stripAssets.add(_current);
        }
      }
    });
  }

  void _return({required bool done}) {
    Navigator.pop(
      context,
      _PhotoPreviewResult(
        selected: List<AssetEntity>.from(_selected),
        done: done,
      ),
    );
  }

  void _jumpToAsset(AssetEntity asset) {
    final index = widget.assets.indexWhere((item) => item.id == asset.id);
    if (index < 0) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(_current);
    final isSelected = selectedIndex >= 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _return(done: false);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            '${_index + 1}/${widget.assets.length}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: _toggleCurrent,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 29,
                      height: 29,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF4490AD)
                            : Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.4),
                      ),
                      child: Center(
                        child: isSelected
                            ? Text(
                                '${selectedIndex + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: PageView.builder(
          controller: _pageController,
          itemCount: widget.assets.length,
          onPageChanged: (value) => setState(() => _index = value),
          itemBuilder: (context, index) {
            return FutureBuilder<File?>(
              future: widget.assets[index].file,
              builder: (context, snapshot) {
                final file = snapshot.data;
                if (file == null) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.file(file, fit: BoxFit.contain),
                  ),
                );
              },
            );
          },
        ),
        bottomNavigationBar: _PreviewBottomBar(
          stripAssets: _stripAssets,
          selected: _selected,
          selectedCount: _selected.length,
          onTapAsset: _jumpToAsset,
          onDone: _selected.isEmpty ? null : () => _return(done: true),
        ),
      ),
    );
  }
}

class _PreviewBottomBar extends StatelessWidget {
  const _PreviewBottomBar({
    required this.stripAssets,
    required this.selected,
    required this.selectedCount,
    required this.onTapAsset,
    required this.onDone,
  });

  final List<AssetEntity> stripAssets;
  final List<AssetEntity> selected;
  final int selectedCount;
  final ValueChanged<AssetEntity> onTapAsset;
  final VoidCallback? onDone;

  bool _isSelected(AssetEntity asset) {
    return selected.any((item) => item.id == asset.id);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      color: Colors.black,
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottom + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stripAssets.isNotEmpty)
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stripAssets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final asset = stripAssets[index];
                  final active = _isSelected(asset);
                  return GestureDetector(
                    onTap: () => onTapAsset(asset),
                    child: Opacity(
                      opacity: active ? 1 : 0.38,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: FutureBuilder<Uint8List?>(
                          future: asset.thumbnailDataWithSize(
                            const ThumbnailSize.square(120),
                            quality: 78,
                          ),
                          builder: (context, snapshot) {
                            final bytes = snapshot.data;
                            if (bytes == null) {
                              return Container(
                                width: 52,
                                height: 52,
                                color: const Color(0xFF1F2937),
                              );
                            }
                            return Image.memory(
                              bytes,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Row(
            children: [
              Text(
                '$selectedCount selected',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onDone,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4490AD),
                  disabledBackgroundColor: const Color(0xFF4490AD),
                  disabledForegroundColor: Colors.white,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(82, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: Text(
                  selectedCount > 0 ? 'Done($selectedCount)' : 'Done',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
