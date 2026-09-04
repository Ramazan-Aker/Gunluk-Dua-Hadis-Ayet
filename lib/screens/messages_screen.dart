import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ready_message_design.dart';
import '../models/share_format.dart';
import '../services/ad_service.dart';
import '../services/firebase_service.dart';
import '../services/ready_message_preferences_service.dart';
import '../services/ready_message_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widget_shortcut_helper.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ReadyMessageService _messageService = ReadyMessageService();
  final ReadyMessagePreferencesService _preferencesService =
      ReadyMessagePreferencesService();
  final AdService _adService = AdService();

  List<ReadyMessageDesign> _designs = const [];
  Set<String> _favoriteIds = const {};
  String _selectedFilter = 'all';
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    _adService.loadInterstitialAd();
    FirebaseService.logScreenView(screenName: 'screen_ready_messages');
  }

  Future<void> _loadCatalog() async {
    try {
      final results = await Future.wait([
        _messageService.loadDesigns(),
        _preferencesService.loadFavoriteIds(),
      ]);
      if (!mounted) return;
      setState(() {
        _designs = results[0] as List<ReadyMessageDesign>;
        _favoriteIds = results[1] as Set<String>;
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  List<ReadyMessageDesign> get _visibleDesigns {
    if (_selectedFilter == 'all') return _designs;
    if (_selectedFilter == 'favorites') {
      return _designs
          .where((design) => _favoriteIds.contains(design.id))
          .toList(growable: false);
    }
    if (_selectedFilter == 'kandiller') {
      return _designs
          .where((design) => _kandilCategories.contains(design.category))
          .toList(growable: false);
    }
    if (_selectedFilter == 'bayramlar') {
      return _designs
          .where((design) => _bayramCategories.contains(design.category))
          .toList(growable: false);
    }
    return _designs
        .where((design) => design.category == _selectedFilter)
        .toList(growable: false);
  }

  Future<bool> _toggleFavorite(ReadyMessageDesign design) async {
    final favoriteIds = await _preferencesService.toggleFavorite(design.id);
    if (!mounted) return favoriteIds.contains(design.id);
    setState(() => _favoriteIds = favoriteIds);
    return favoriteIds.contains(design.id);
  }

  void _openDesign(ReadyMessageDesign design) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ReadyMessagePreviewPage(
          design: design,
          adService: _adService,
          initialIsFavorite: _favoriteIds.contains(design.id),
          onToggleFavorite: () => _toggleFavorite(design),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ivory,
      appBar: AppBar(
        title: const Text(
          'Hazır Mesajlar',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        leading: const Icon(Icons.auto_awesome_mosaic_rounded),
        actions: [
          ...WidgetShortcutHelper.appBarActions(context),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          const AdBannerWidget(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _MessageLoadError(onRetry: _loadCatalog);
    }

    final visibleDesigns = _visibleDesigns;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 900
            ? 5
            : constraints.maxWidth >= 620
                ? 3
                : 2;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildFilters()),
            if (visibleDesigns.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyFavorites(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverGrid.builder(
                  itemCount: visibleDesigns.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 9 / 16,
                  ),
                  itemBuilder: (context, index) {
                    final design = visibleDesigns[index];
                    return _ReadyMessageTile(
                      design: design,
                      isFavorite: _favoriteIds.contains(design.id),
                      onTap: () => _openDesign(design),
                      onFavorite: () => _toggleFavorite(design),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF002F46), Color(0xFF075B56)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppTheme.navy.withValues(alpha: .14),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .13),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppTheme.gold,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paylaşmaya hazır tasarımlar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        scrollDirection: Axis.horizontal,
        itemCount: _messageFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _messageFilters[index];
          final selected = filter.id == _selectedFilter;
          return FilterChip(
            selected: selected,
            showCheckmark: false,
            avatar: Icon(
              filter.icon,
              size: 17,
              color: selected ? Colors.white : AppTheme.emerald,
            ),
            label: Text(filter.label),
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppTheme.navy,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: Colors.white,
            selectedColor: AppTheme.navy,
            side: BorderSide(
              color: selected
                  ? AppTheme.navy
                  : AppTheme.navy.withValues(alpha: .12),
            ),
            onSelected: (_) => setState(() => _selectedFilter = filter.id),
          );
        },
      ),
    );
  }
}

class _ReadyMessageTile extends StatelessWidget {
  final ReadyMessageDesign design;
  final bool isFavorite;
  final VoidCallback onTap;
  final Future<bool> Function() onFavorite;

  const _ReadyMessageTile({
    required this.design,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'ready-message-${design.id}',
              child: _EditableMessageCard(
                design: design,
                message: design.message,
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0x8C000000)],
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              top: 5,
              right: 4,
              child: IconButton(
                tooltip: isFavorite ? 'Favorilerden kaldır' : 'Favorilere ekle',
                onPressed: onFavorite,
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite ? const Color(0xFFFF6374) : Colors.white,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                ),
              ),
            ),
            Positioned(
              left: 11,
              right: 11,
              bottom: 10,
              child: Text(
                design.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 7)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyMessagePreviewPage extends StatefulWidget {
  final ReadyMessageDesign design;
  final AdService adService;
  final bool initialIsFavorite;
  final Future<bool> Function() onToggleFavorite;

  const _ReadyMessagePreviewPage({
    required this.design,
    required this.adService,
    required this.initialIsFavorite,
    required this.onToggleFavorite,
  });

  @override
  State<_ReadyMessagePreviewPage> createState() =>
      _ReadyMessagePreviewPageState();
}

class _ReadyMessagePreviewPageState extends State<_ReadyMessagePreviewPage> {
  static const _mediaChannel = MethodChannel(
    'com.tahram.gunlukduahadis/media',
  );

  final GlobalKey _shareButtonKey = GlobalKey();
  final GlobalKey _editableCardKey = GlobalKey();
  late bool _isFavorite;
  late String _messageText;
  ShareFormat _shareFormat = ShareFormat.story;
  bool _isSharing = false;
  bool _isSaving = false;

  bool get _isEdited => _messageText != widget.design.message;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.initialIsFavorite;
    _messageText = widget.design.message;
  }

  Future<_ExportImage> _createExportImage() async {
    await precacheImage(AssetImage(widget.design.backgroundAssetPath), context);
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _editableCardKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null || boundary.size.isEmpty) {
      throw StateError('Düzenlenen görsel henüz hazır değil');
    }

    final pixelRatio = _shareFormat.width / boundary.size.width;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Görsel verisi oluşturulamadı');
      return _ExportImage(
        bytes: data.buffer.asUint8List(),
        extension: 'png',
        mimeType: 'image/png',
      );
    } finally {
      image.dispose();
    }
  }

  Future<void> _editMessage() async {
    final message = await showDialog<String>(
      context: context,
      builder: (context) => _EditMessageDialog(initialValue: _messageText),
    );
    if (message == null || !mounted) return;
    setState(() => _messageText = message);
  }

  void _restoreDefaultMessage() {
    setState(() => _messageText = widget.design.message);
  }

  Future<void> _openSource() async {
    final uri = Uri.tryParse(widget.design.sourceUrl ?? '');
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Görsel kaynağı açılamadı.')),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final isFavorite = await widget.onToggleFavorite();
    if (mounted) setState(() => _isFavorite = isFavorite);
  }

  Future<void> _share() async {
    if (_isSharing || _isSaving) return;
    setState(() => _isSharing = true);

    File? temporaryFile;
    try {
      final imageFuture = _createExportImage();
      await widget.adService.showInterstitialAd().catchError((_) => false);
      final export = await imageFuture;
      final directory = await getTemporaryDirectory();
      temporaryFile = File(
        '${directory.path}/her_gun_islam_${widget.design.id}_${_shareFormat.name}_${DateTime.now().millisecondsSinceEpoch}.${export.extension}',
      );
      await temporaryFile.writeAsBytes(export.bytes, flush: true);

      if (!mounted) return;
      final box =
          _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : Rect.fromCenter(
              center: MediaQuery.of(context).size.center(Offset.zero),
              width: 1,
              height: 1,
            );

      await Share.shareXFiles(
        [XFile(temporaryFile.path, mimeType: export.mimeType)],
        text: 'Her Gün İslam uygulamasından paylaşıldı',
        sharePositionOrigin: origin,
      );

      FirebaseService.logEvent(
        name: AnalyticsEvents.greetingShared,
        parameters: {
          AnalyticsParams.category: widget.design.category,
          AnalyticsParams.messageType:
              _isEdited ? 'ready_local_edited' : 'ready_local',
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Görsel paylaşılamadı: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
      final fileToDelete = temporaryFile;
      if (fileToDelete != null) {
        Future<void>.delayed(const Duration(minutes: 5), () async {
          try {
            if (await fileToDelete.exists()) await fileToDelete.delete();
          } catch (_) {}
        });
      }
    }
  }

  Future<void> _save() async {
    if (_isSharing || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      // Prepare the image while the same interstitial used by sharing is
      // displayed. Saving continues normally when no ad is ready.
      final imageFuture = _createExportImage();
      await widget.adService.showInterstitialAd().catchError((_) => false);
      final export = await imageFuture;
      if (Platform.isIOS) {
        final saved = await _mediaChannel.invokeMethod<bool>(
          'saveImageToPhotoLibrary',
          export.bytes,
        );
        if (saved != true) {
          throw Exception('Görsel Fotoğraflar arşivine kaydedilemedi');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Görsel Fotoğraflar’a kaydedildi.')),
          );
        }
        return;
      }

      final directory = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      await directory.create(recursive: true);
      final file = File(
        '${directory.path}/her_gun_islam_${widget.design.id}_${DateTime.now().millisecondsSinceEpoch}.${export.extension}',
      );
      await file.writeAsBytes(export.bytes, flush: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Görsel kaydedildi: ${file.path}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Görsel kaydedilemedi: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ivory,
      appBar: AppBar(
        title: Text(widget.design.categoryLabel),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _toggleFavorite,
            tooltip: _isFavorite ? 'Favorilerden kaldır' : 'Favorilere ekle',
            icon: Icon(
              _isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _isFavorite ? const Color(0xFFCE5868) : AppTheme.navy,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: AspectRatio(
                        aspectRatio: _shareFormat.aspectRatio,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Hero(
                            tag: 'ready-message-${widget.design.id}',
                            child: RepaintBoundary(
                              key: _editableCardKey,
                              child: _EditableMessageCard(
                                design: widget.design,
                                message: _messageText,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_isEdited) ...[
                    const SizedBox(height: 10),
                    const Center(
                      child: _EditedBadge(),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _buildFormatSelector(),
                  const SizedBox(height: 12),
                  _buildActions(),
                  const SizedBox(height: 12),
                  Text(
                    widget.design.source,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  if (widget.design.sourceUrl != null) ...[
                    const SizedBox(height: 3),
                    TextButton.icon(
                      onPressed: _openSource,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Görsel kaynağı ve lisans'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const AdBannerWidget(),
        ],
      ),
    );
  }

  Widget _buildFormatSelector() {
    const formats = [
      ShareFormat.story,
      ShareFormat.feed,
      ShareFormat.square,
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: .06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 1, 4, 9),
            child: Text(
              'Paylaşım formatı',
              style: TextStyle(
                color: AppTheme.navy,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Row(
            children: [
              for (var index = 0; index < formats.length; index++) ...[
                if (index > 0) const SizedBox(width: 7),
                Expanded(
                  child: _ShareFormatOption(
                    format: formats[index],
                    isSelected: _shareFormat == formats[index],
                    onTap: () => setState(
                      () => _shareFormat = formats[index],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: .08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            key: _shareButtonKey,
            onPressed: _isSharing || _isSaving ? null : _share,
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.ios_share_rounded),
            label: Text(_isSharing ? 'Paylaşılıyor...' : 'Paylaş'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSharing || _isSaving ? null : _editMessage,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Metni Düzenle'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.navy,
                    side: BorderSide(
                      color: AppTheme.navy.withValues(alpha: .25),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (_isEdited) ...[
                const SizedBox(width: 9),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _isSharing || _isSaving ? null : _restoreDefaultMessage,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Varsayılana Dön'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.navy,
                      side: BorderSide(
                        color: AppTheme.navy.withValues(alpha: .25),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: _isSharing || _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(_isSaving ? 'Kaydediliyor...' : 'Cihaza Kaydet'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.navy,
              side: BorderSide(color: AppTheme.navy.withValues(alpha: .25)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareFormatOption extends StatelessWidget {
  final ShareFormat format;
  final bool isSelected;
  final VoidCallback onTap;

  const _ShareFormatOption({
    required this.format,
    required this.isSelected,
    required this.onTap,
  });

  IconData get _icon => switch (format) {
        ShareFormat.story => Icons.stay_current_portrait_rounded,
        ShareFormat.feed => Icons.crop_portrait_rounded,
        ShareFormat.square => Icons.crop_square_rounded,
      };

  String get _shortLabel => switch (format) {
        ShareFormat.story => 'Hikâye/Reels',
        ShareFormat.feed => 'Gönderi',
        ShareFormat.square => 'Kare',
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppTheme.navy : AppTheme.ivory,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
          child: Column(
            children: [
              Icon(
                _icon,
                size: 20,
                color: isSelected ? Colors.white : AppTheme.navy,
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _shortLabel,
                  maxLines: 1,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${format.width.toInt()}×${format.height.toInt()}',
                  maxLines: 1,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white.withValues(alpha: .72)
                        : AppTheme.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableMessageCard extends StatelessWidget {
  final ReadyMessageDesign design;
  final String message;

  const _EditableMessageCard({
    required this.design,
    required this.message,
  });

  double _baseFontSize() {
    if (message.length <= 42) return 30;
    if (message.length <= 72) return 25;
    if (message.length <= 110) return 21;
    if (message.length <= 145) return 18;
    return 16;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / 360;
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              design.backgroundAssetPath,
              fit: BoxFit.cover,
              cacheWidth: 1080,
              filterQuality: FilterQuality.high,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Color(0x24000000),
                    Color(0x52000000),
                  ],
                  stops: [0, .48, 1],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: .78,
                  colors: [Color(0x5C000000), Color(0x08000000)],
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 30 * scale),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _baseFontSize() * scale,
                    height: 1.28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .1 * scale,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: .92),
                        blurRadius: 13 * scale,
                        offset: Offset(0, 2 * scale),
                      ),
                      Shadow(
                        color: Colors.black.withValues(alpha: .62),
                        blurRadius: 3 * scale,
                        offset: Offset(0, 1 * scale),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 28 * scale,
              right: 28 * scale,
              bottom: 29 * scale,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 20 * scale,
                    height: 1 * scale,
                    color: Colors.white.withValues(alpha: .55),
                  ),
                  SizedBox(width: 9 * scale),
                  Text(
                    'HER GÜN İSLAM',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .9),
                      fontSize: 8.5 * scale,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.55 * scale,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 7),
                      ],
                    ),
                  ),
                  SizedBox(width: 9 * scale),
                  Container(
                    width: 20 * scale,
                    height: 1 * scale,
                    color: Colors.white.withValues(alpha: .55),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EditedBadge extends StatelessWidget {
  const _EditedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 15, color: AppTheme.gold),
          SizedBox(width: 6),
          Text(
            'Metin düzenlendi',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditMessageDialog extends StatefulWidget {
  final String initialValue;

  const _EditMessageDialog({required this.initialValue});

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _errorText = 'Mesaj boş bırakılamaz.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mesajı Düzenle'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 4,
        maxLines: 7,
        maxLength: 180,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'Paylaşmak istediğiniz mesajı yazın',
          errorText: _errorText,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) {
          if (_errorText != null) setState(() => _errorText = null);
        },
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Uygula'),
        ),
      ],
    );
  }
}

class _ExportImage {
  final Uint8List bytes;
  final String extension;
  final String mimeType;

  const _ExportImage({
    required this.bytes,
    required this.extension,
    required this.mimeType,
  });
}

class _MessageLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _MessageLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              size: 52,
              color: AppTheme.gold,
            ),
            const SizedBox(height: 14),
            const Text(
              'Hazır mesajlar yüklenemedi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.navy,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite_border_rounded,
              size: 54,
              color: AppTheme.gold,
            ),
            const SizedBox(height: 13),
            const Text(
              'Henüz favori tasarımınız yok.',
              style: TextStyle(
                color: AppTheme.navy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Beğendiğiniz tasarımlardaki kalp simgesine dokunun.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.navy.withValues(alpha: .58),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageFilter {
  final String id;
  final String label;
  final IconData icon;

  const _MessageFilter(this.id, this.label, this.icon);
}

const _messageFilters = [
  _MessageFilter('all', 'Tümü', Icons.grid_view_rounded),
  _MessageFilter('favorites', 'Favoriler', Icons.favorite_rounded),
  _MessageFilter('cesaret', 'Cesaret', Icons.shield_outlined),
  _MessageFilter('cuma', 'Cuma', Icons.mosque_rounded),
  _MessageFilter('kandiller', 'Kandiller', Icons.nightlight_round),
  _MessageFilter('bayramlar', 'Bayramlar', Icons.celebration_rounded),
  _MessageFilter('dua', 'Dua', Icons.volunteer_activism_rounded),
  _MessageFilter('tevekkul', 'Tevekkül', Icons.route_rounded),
  _MessageFilter('sabir', 'Sabır', Icons.hourglass_bottom_rounded),
  _MessageFilter('sukur', 'Şükür', Icons.wb_sunny_outlined),
  _MessageFilter('umut', 'Umut', Icons.light_mode_outlined),
  _MessageFilter('huzur', 'Huzur', Icons.spa_outlined),
  _MessageFilter('namaz', 'Namaz', Icons.self_improvement_rounded),
  _MessageFilter('iyilik', 'İyilik', Icons.favorite_outline_rounded),
];

const _kandilCategories = <String>{
  'mevlid',
  'regaib',
  'mirac',
  'berat',
  'kadir',
};

const _bayramCategories = <String>{
  'ramazan_bayrami',
  'kurban_bayrami',
};
