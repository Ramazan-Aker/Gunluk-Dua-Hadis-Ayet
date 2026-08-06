import 'package:flutter/material.dart';
import 'package:widgets_to_image/widgets_to_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/greeting_message.dart';
import '../services/greeting_service.dart';
import '../services/greeting_preferences_service.dart';
import '../services/ad_service.dart';
import '../services/firebase_service.dart';
import '../widgets/greeting_shareable_card.dart';
import '../widgets/widget_shortcut_helper.dart';
import '../models/share_format.dart';
import '../theme/app_theme.dart';

/// Screen for sharing Cuma, Kandil, and Bayram greeting messages
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final GreetingService _greetingService = GreetingService();
  final GreetingPreferencesService _preferencesService =
      GreetingPreferencesService();
  final AdService _adService = AdService();
  // iOS share sheet konumu için paylaş butonuna atanan key
  final GlobalKey _shareButtonKey = GlobalKey();

  bool _isLoading = true;
  bool _isSharing = false;
  bool _isSaving = false;

  // Step 0: null = main groups, 'kandil'/'bayram' = show sub-list
  String? _mainGroup;
  String? _selectedCategoryId;
  String _messageText = '';
  String _messageTitle = '';
  bool _isCustomMessage = false;
  String? _selectedMessageId;
  Future<String?>? _imageFuture;
  ShareFormat _shareFormat = ShareFormat.feed;
  List<GreetingMessage> _favoriteMessages = [];
  List<GreetingMessage> _recentMessages = [];
  String _signature = '';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _adService.loadInterstitialAd();
    FirebaseService.logScreenView(screenName: 'screen_messages');
  }

  Future<void> _loadMessages() async {
    await _greetingService.loadMessages();
    final favorites = await _preferencesService.loadFavorites();
    final recents = await _preferencesService.loadRecents();
    final signature = await _preferencesService.loadSignature();
    if (mounted) {
      setState(() {
        _favoriteMessages = favorites;
        _recentMessages = recents;
        _signature = signature;
        _isLoading = false;
      });
    }
  }

  void _selectMainGroup(String? group) {
    setState(() {
      _mainGroup = group;
      _selectedCategoryId = null;
      _messageText = '';
      _messageTitle = '';
      _isCustomMessage = false;
      _selectedMessageId = null;
      _imageFuture = null;

      if (group == 'cuma') {
        _selectedCategoryId = 'cuma';
        _greetingService.prefetchImageForCategory('cuma');
      } else if (group == 'günlük_dua') {
        _selectedCategoryId = 'günlük_dua';
        _greetingService.prefetchImageForCategory('günlük_dua');
      }
    });
  }

  void _selectCategory(String categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _messageText = '';
      _messageTitle = '';
      _isCustomMessage = false;
      _selectedMessageId = null;
      _imageFuture = null;
      _greetingService.prefetchImageForCategory(categoryId);
    });
  }

  void _selectMessage(GreetingMessage msg) {
    setState(() {
      _selectedCategoryId = msg.category;
      _messageText = msg.text;
      _messageTitle = msg.title;
      _isCustomMessage = false;
      _selectedMessageId = msg.id;
      _imageFuture = _greetingService.fetchImageForMessage(msg.category,
          messageId: msg.id);
    });
    _preferencesService.addRecent(msg).then((recents) {
      if (mounted) setState(() => _recentMessages = recents);
    });
  }

  void _setCustomMessage(String text, String title) {
    final messageId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _messageText = text;
      _messageTitle = title;
      _isCustomMessage = true;
      _selectedMessageId = messageId;
      if (_selectedCategoryId != null) {
        _imageFuture = _greetingService
            .fetchImageForMessage(_selectedCategoryId!, messageId: messageId);
      }
    });
    if (_selectedCategoryId != null) {
      final message = GreetingMessage(
        id: messageId,
        category: _selectedCategoryId!,
        title: title,
        text: text,
      );
      _preferencesService.addRecent(message).then((recents) {
        if (mounted) setState(() => _recentMessages = recents);
      });
    }
  }

  GreetingMessage? _currentMessage() {
    if (_selectedCategoryId == null ||
        _selectedMessageId == null ||
        _messageText.isEmpty) {
      return null;
    }
    return GreetingMessage(
      id: _selectedMessageId!,
      category: _selectedCategoryId!,
      title: _messageTitle,
      text: _messageText,
    );
  }

  String _messageKey(GreetingMessage message) {
    final identity =
        message.id.trim().isEmpty ? message.text.trim() : message.id;
    return '${message.category}::$identity';
  }

  bool _isFavorite(GreetingMessage message) => _favoriteMessages.any(
        (favorite) => _messageKey(favorite) == _messageKey(message),
      );

  Future<void> _toggleFavorite(GreetingMessage message) async {
    final wasFavorite = _isFavorite(message);
    final favorites = await _preferencesService.toggleFavorite(message);
    if (!mounted) return;
    setState(() => _favoriteMessages = favorites);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasFavorite
              ? 'Mesaj favorilerden kaldırıldı'
              : 'Mesaj favorilere eklendi',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showSignatureDialog() async {
    final signature = await showDialog<String>(
      context: context,
      builder: (context) => _TextInputDialog(
        title: 'Kişisel İmza',
        hintText: 'Örn. Ramazan ve Ailesi',
        initialValue: _signature,
        submitLabel: 'Kaydet',
        maxLength: 50,
        minLines: 1,
        maxLines: 2,
        allowEmpty: true,
        helperText: 'Boş bırakırsanız paylaşım kartında imza görünmez.',
      ),
    );
    if (signature == null || !mounted) return;
    final cleanSignature = signature.trim();
    await _preferencesService.saveSignature(cleanSignature);
    if (mounted) setState(() => _signature = cleanSignature);
  }

  bool _canGoBack() {
    return _mainGroup != null || _selectedCategoryId != null;
  }

  void _onBackPressed() {
    if (_messageText.isNotEmpty) {
      setState(() {
        _messageText = '';
        _messageTitle = '';
        _selectedMessageId = null;
        _imageFuture = null;
      });
      return;
    }
    if (_selectedCategoryId != null) {
      if (_mainGroup == 'kandil' || _mainGroup == 'bayram') {
        setState(() => _selectedCategoryId = null);
      } else {
        _selectMainGroup(null);
      }
      return;
    }
    if (_mainGroup != null) {
      _selectMainGroup(null);
    }
  }

  Future<void> _shareGreeting() async {
    if (_messageText.isEmpty || _selectedCategoryId == null) return;

    setState(() => _isSharing = true);

    try {
      if (!mounted) return;
      final categoryId = _selectedCategoryId!;
      // Paralel: görsel oluşturma (reklam sırasında arka planda hazırlanır)
      final imageFuture = _captureGreetingCard();

      // Paralel: reklam göster (kullanıcı izler)
      final adFuture = _adService.showInterstitialAd().catchError((e) {
        return false;
      });

      await adFuture;
      final bytes = await imageFuture;

      if (bytes != null && bytes.isNotEmpty) {
        final directory = await getTemporaryDirectory();
        final imagePath =
            '${directory.path}/greeting_${_shareFormat.name}_${DateTime.now().millisecondsSinceEpoch}.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(bytes);

        // iOS'ta share sheet konumu zorunlu
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
          [XFile(imagePath)],
          text: 'Her Gün İslam uygulamasından paylaşıldı',
          sharePositionOrigin: origin,
        );

        FirebaseService.logEvent(
          name: AnalyticsEvents.greetingShared,
          parameters: {
            AnalyticsParams.category: categoryId,
            AnalyticsParams.messageType:
                _isCustomMessage ? 'custom' : 'predefined',
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Kart görsel olarak paylaşıldı!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        Future.delayed(const Duration(minutes: 5), () {
          try {
            if (imageFile.existsSync()) imageFile.deleteSync();
          } catch (_) {}
        });
      } else {
        _shareAsText();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Görsel oluşturulamadı: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      _shareAsText();
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<Uint8List?> _captureGreetingCard() async {
    if (_messageText.isEmpty || _selectedCategoryId == null || !mounted) {
      return null;
    }

    final categoryId = _selectedCategoryId!;
    final imageUrl = await (_imageFuture ??
        _greetingService.fetchImageForMessage(
          categoryId,
          messageId: _selectedMessageId,
        ));
    if (imageUrl != null && imageUrl.isNotEmpty && mounted) {
      await precacheImage(NetworkImage(imageUrl), context);
    }
    if (!mounted) return null;

    final controller = WidgetsToImageController();
    final overlay = Overlay.of(context);
    late final OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned(
            left: -10000,
            top: -10000,
            child: WidgetsToImage(
              controller: controller,
              child: Material(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: GreetingShareableCard(
                    categoryId: categoryId,
                    messageText: _messageText,
                    messageTitle: _messageTitle,
                    signature: _signature,
                    imageUrl: imageUrl,
                    width: _shareFormat.width,
                    height: _shareFormat.height,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(overlayEntry);
    try {
      await Future.delayed(Duration(
          milliseconds: imageUrl != null && imageUrl.isNotEmpty ? 800 : 500));
      return await controller.capture();
    } finally {
      overlayEntry.remove();
    }
  }

  void _changePreviewImage() {
    if (_selectedCategoryId == null) return;
    setState(() {
      _imageFuture = _greetingService.fetchImageForMessage(
        _selectedCategoryId!,
        messageId: _selectedMessageId,
        forceRefresh: true,
      );
    });
  }

  Future<void> _showEditMessageDialog() async {
    final editedText = await showDialog<String>(
      context: context,
      builder: (context) => _TextInputDialog(
        title: 'Metni Düzenle',
        hintText: 'Paylaşmak istediğiniz mesajı yazın',
        initialValue: _messageText,
        submitLabel: 'Uygula',
        maxLength: 500,
        minLines: 5,
        maxLines: 9,
      ),
    );

    if (editedText != null && mounted) {
      setState(() {
        _messageText = editedText;
        _isCustomMessage = true;
      });
    }
  }

  Future<void> _saveGreetingToDevice() async {
    if (_isSaving || _messageText.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final bytes = await _captureGreetingCard();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Görsel oluşturulamadı');
      }
      final directory = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final imagePath =
          '${directory.path}/her_gun_islam_${_shareFormat.name}_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(imagePath).writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Görsel kaydedildi: $imagePath')),
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

  void _shareAsText() {
    if (_messageText.isEmpty) return;
    // iOS'ta share sheet konumu zorunlu
    final box =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromCenter(
            center: MediaQuery.of(context).size.center(Offset.zero),
            width: 1,
            height: 1,
          );
    final signatureText = _signature.isEmpty ? '' : '\n\n— $_signature';
    Share.share(
      '$_messageTitle\n\n$_messageText$signatureText\n\nHer Gün İslam uygulamasından paylaşıldı',
      sharePositionOrigin: origin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesaj Paylaş', style: TextStyle(fontSize: 22)),
        centerTitle: true,
        elevation: 0,
        leading: _canGoBack()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _onBackPressed,
              )
            : const Icon(Icons.menu_rounded),
        actions: [
          IconButton(
            onPressed: _showSignatureDialog,
            tooltip: 'Kişisel imza',
            icon: Icon(
              Icons.draw_outlined,
              color: _signature.isEmpty ? AppTheme.navy : AppTheme.gold,
            ),
          ),
          ...WidgetShortcutHelper.appBarActions(context),
          const SizedBox(width: 6),
        ],
      ),
      body: Container(
        color: AppTheme.ivory,
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(),
            ),
            const AdBannerWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Step 1: Main group selection (Cuma, Kandiller, Bayramlar, Özel Günler)
    if (_mainGroup == null) {
      return _buildMainGroupSelection();
    }

    if ((_mainGroup == 'favorites' || _mainGroup == 'recent') &&
        _messageText.isEmpty) {
      return _buildSavedMessageSelection(
        title:
            _mainGroup == 'favorites' ? 'Favori Mesajlar' : 'Son Kullanılanlar',
        messages:
            _mainGroup == 'favorites' ? _favoriteMessages : _recentMessages,
        emptyText: _mainGroup == 'favorites'
            ? 'Henüz favori mesajınız yok.'
            : 'Henüz kullanılan bir mesaj yok.',
        emptyIcon: _mainGroup == 'favorites'
            ? Icons.favorite_border_rounded
            : Icons.history_rounded,
      );
    }

    // Step 2: Sub-category for Kandiller, Bayramlar, or Özel Günler
    if ((_mainGroup == 'kandil' ||
            _mainGroup == 'bayram' ||
            _mainGroup == 'özel_günler') &&
        _selectedCategoryId == null) {
      return _buildSubCategorySelection();
    }

    // Step 3: Message selection
    if (_messageText.isEmpty) {
      return _buildMessageSelection();
    }

    // Step 4: Preview and share
    return _buildPreview();
  }

  Widget _buildMainGroupSelection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _libraryCard(
                  label: 'Favoriler',
                  count: _favoriteMessages.length,
                  icon: Icons.favorite_rounded,
                  color: const Color(0xFFB95D67),
                  onTap: () => _selectMainGroup('favorites'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _libraryCard(
                  label: 'Son Kullanılanlar',
                  count: _recentMessages.length,
                  icon: Icons.history_rounded,
                  color: AppTheme.emerald,
                  onTap: () => _selectMainGroup('recent'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Text(
            'Kategori Seçin',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.navy,
            ),
          ),
          const SizedBox(height: 20),
          _categoryChip(
            'Cuma',
            Icons.calendar_today,
            onTap: () => _selectMainGroup('cuma'),
          ),
          const SizedBox(height: 12),
          _categoryChip(
            'Kandiller',
            Icons.nightlight_round,
            onTap: () => _selectMainGroup('kandil'),
          ),
          const SizedBox(height: 12),
          _categoryChip(
            'Bayramlar',
            Icons.celebration,
            onTap: () => _selectMainGroup('bayram'),
          ),
          const SizedBox(height: 12),
          _categoryChip(
            'Günlük Dua & Zikir',
            Icons.menu_book,
            onTap: () => _selectMainGroup('günlük_dua'),
          ),
          const SizedBox(height: 12),
          _categoryChip(
            'Özel Günler',
            Icons.card_giftcard,
            onTap: () => _selectMainGroup('özel_günler'),
          ),
        ],
      ),
    );
  }

  Widget _libraryCard({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 13),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count mesaj',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(String label, IconData icon, {VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.emerald, size: 28),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.navy,
                ),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.navy),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubCategorySelection() {
    final List<String> ids;
    final IconData icon;

    if (_mainGroup == 'kandil') {
      ids = _greetingService.getKandilIds();
      icon = Icons.nightlight_round;
    } else if (_mainGroup == 'bayram') {
      ids = _greetingService.getBayramIds();
      icon = Icons.celebration;
    } else if (_mainGroup == 'özel_günler') {
      ids = GreetingCategoryInfo.specialOccasionIds;
      icon = Icons.card_giftcard;
    } else {
      ids = [];
      icon = Icons.category;
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Alt Kategori Seçin',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.navy,
          ),
        ),
        const SizedBox(height: 16),
        ...ids.map((id) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _categoryChip(
                GreetingCategoryInfo.getDisplayName(id),
                icon,
                onTap: () => _selectCategory(id),
              ),
            )),
      ],
    );
  }

  Widget _buildMessageSelection() {
    final messages =
        _greetingService.getMessagesForCategory(_selectedCategoryId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Mesaj Seçin veya özel yazın',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 16),

              // ÖNEMLİ: Özel mesaj butonu EN ÜSTTE (vurgulu tasarım)
              Material(
                color: AppTheme.gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => _showCustomMessageDialog(),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note,
                            color: AppTheme.gold, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Özel mesaj yaz',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.navy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Kendi mesajınızı oluşturun',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios,
                            size: 18, color: AppTheme.gold),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // Hazır mesajlar listesi
              ...messages.map((msg) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _messageCard(msg),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSavedMessageSelection({
    required String title,
    required List<GreetingMessage> messages,
    required String emptyText,
    required IconData emptyIcon,
  }) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.navy,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${messages.length} mesaj',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 18),
        if (messages.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 52),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Icon(emptyIcon, size: 46, color: AppTheme.gold),
                const SizedBox(height: 14),
                Text(
                  emptyText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          )
        else
          ...messages.map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _messageCard(message, showCategory: true),
            ),
          ),
      ],
    );
  }

  Widget _messageCard(GreetingMessage msg, {bool showCategory = false}) {
    final favorite = _isFavorite(msg);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: () => _selectMessage(msg),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showCategory) ...[
                      Text(
                        GreetingCategoryInfo.getDisplayName(msg.category),
                        style: const TextStyle(
                          color: AppTheme.emerald,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      msg.text,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppTheme.text,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _toggleFavorite(msg),
                tooltip: favorite ? 'Favorilerden kaldır' : 'Favorilere ekle',
                icon: Icon(
                  favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color:
                      favorite ? const Color(0xFFB95D67) : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCustomMessageDialog() async {
    final message = await showDialog<String>(
      context: context,
      builder: (context) => const _TextInputDialog(
        title: 'Özel Mesaj Yaz',
        hintText: 'Mesajınızı yazın...',
        submitLabel: 'Kullan',
        maxLength: 200,
        minLines: 4,
        maxLines: 6,
      ),
    );
    if (message != null && message.trim().isNotEmpty) {
      _setCustomMessage(message.trim(), 'Özel Mesaj');
    }
  }

  Widget _buildPreview() {
    final currentMessage = _currentMessage();
    final currentIsFavorite =
        currentMessage != null && _isFavorite(currentMessage);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Önizleme',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
                ),
              ),
              if (currentMessage != null)
                IconButton(
                  onPressed: () => _toggleFavorite(currentMessage),
                  tooltip: currentIsFavorite
                      ? 'Favorilerden kaldır'
                      : 'Favorilere ekle',
                  icon: Icon(
                    currentIsFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: currentIsFavorite
                        ? const Color(0xFFB95D67)
                        : AppTheme.navy,
                  ),
                ),
              PopupMenuButton<ShareFormat>(
                initialValue: _shareFormat,
                onSelected: (format) => setState(() => _shareFormat = format),
                itemBuilder: (context) => ShareFormat.values
                    .map(
                      (format) => PopupMenuItem(
                        value: format,
                        child: Row(
                          children: [
                            Icon(
                              _shareFormat == format
                                  ? Icons.check_circle
                                  : Icons.crop_outlined,
                              size: 19,
                              color: _shareFormat == format
                                  ? AppTheme.gold
                                  : AppTheme.navy,
                            ),
                            const SizedBox(width: 10),
                            Text(format.label),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: AppTheme.navy.withValues(alpha: .16)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.aspect_ratio_rounded,
                          size: 17, color: AppTheme.navy),
                      const SizedBox(width: 7),
                      Text(
                        _shareFormat.label,
                        style: const TextStyle(
                          color: AppTheme.navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: AppTheme.navy),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<String?>(
            future: _imageFuture,
            builder: (context, snapshot) {
              final imageUrl = snapshot.data;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.navy.withValues(alpha: 0.13),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: _shareFormat.aspectRatio,
                    child: snapshot.connectionState == ConnectionState.waiting
                        ? const ColoredBox(
                            color: Color(0xFFE8E5DC),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            child: GreetingShareableCard(
                              categoryId: _selectedCategoryId!,
                              messageText: _messageText,
                              messageTitle: _messageTitle,
                              signature: _signature,
                              imageUrl: imageUrl,
                              width: _shareFormat.width,
                              height: _shareFormat.height,
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.navy.withValues(alpha: .07),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  key: _shareButtonKey,
                  onPressed: _isSharing || _isSaving ? null : _shareGreeting,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.ios_share_rounded, size: 22),
                  label: Text(
                    _isSharing ? 'Paylaşılıyor...' : 'Paylaş',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.navy,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppTheme.navy.withValues(alpha: .55),
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSharing || _isSaving
                            ? null
                            : _changePreviewImage,
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Görseli Değiştir'),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.navy,
                          side: BorderSide(
                              color: AppTheme.navy.withValues(alpha: .35)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 13),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSharing || _isSaving
                            ? null
                            : _showEditMessageDialog,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Metni Düzenle'),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.navy,
                          side: BorderSide(
                              color: AppTheme.navy.withValues(alpha: .35)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 13),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                TextButton.icon(
                  onPressed:
                      _isSharing || _isSaving ? null : _saveGreetingToDevice,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded, size: 20),
                  label: Text(_isSaving ? 'Kaydediliyor...' : 'Cihaza Kaydet'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.navy,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _TextInputDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final String initialValue;
  final String submitLabel;
  final int maxLength;
  final int minLines;
  final int maxLines;
  final bool allowEmpty;
  final String? helperText;

  const _TextInputDialog({
    required this.title,
    required this.hintText,
    this.initialValue = '',
    required this.submitLabel,
    required this.maxLength,
    required this.minLines,
    required this.maxLines,
    this.allowEmpty = false,
    this.helperText,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller;

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

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty || widget.allowEmpty) {
      Navigator.pop(context, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: widget.hintText,
          helperText: widget.helperText,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}
