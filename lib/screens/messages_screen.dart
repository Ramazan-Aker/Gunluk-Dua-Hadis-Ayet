import 'package:flutter/material.dart';
import 'package:widgets_to_image/widgets_to_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/greeting_message.dart';
import '../services/greeting_service.dart';
import '../services/ad_service.dart';
import '../services/firebase_service.dart';
import '../widgets/greeting_shareable_card.dart';

/// Screen for sharing Cuma, Kandil, and Bayram greeting messages
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({Key? key}) : super(key: key);

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final GreetingService _greetingService = GreetingService();
  final AdService _adService = AdService();

  bool _isLoading = true;
  bool _isSharing = false;

  // Step 0: null = main groups, 'kandil'/'bayram' = show sub-list
  String? _mainGroup;
  String? _selectedCategoryId;
  String _messageText = '';
  String _messageTitle = '';
  bool _isCustomMessage = false;
  String? _selectedMessageId;
  String? _previewImageUrl;
  Future<String?>? _imageFuture;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _adService.loadInterstitialAd();
    FirebaseService.logScreenView(screenName: 'screen_messages');
  }

  Future<void> _loadMessages() async {
    await _greetingService.loadMessages();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _selectMainGroup(String? group) {
    setState(() {
      _mainGroup = group;
      _selectedCategoryId = null;
      _messageText = '';
      _messageTitle = '';
      _isCustomMessage = false;

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
      _greetingService.prefetchImageForCategory(categoryId);
    });
  }

  void _selectMessage(GreetingMessage msg) {
    setState(() {
      _messageText = msg.text;
      _messageTitle = msg.title;
      _isCustomMessage = false;
      _selectedMessageId = msg.id;
      _imageFuture = _greetingService.fetchImageForMessage(msg.category, messageId: msg.id);
    });
  }

  void _setCustomMessage(String text, String title) {
    setState(() {
      _messageText = text;
      _messageTitle = title;
      _isCustomMessage = true;
      _selectedMessageId = null;
      if (_selectedCategoryId != null) {
        _imageFuture = _greetingService.fetchImageForMessage(_selectedCategoryId!, messageId: null);
      }
    });
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
      final adShown = await _adService.showInterstitialAd();
      if (adShown) {
        print('✅ Interstitial ad shown before greeting share');
      } else {
        print('⚠️ Interstitial ad not ready, proceeding with share');
      }
    } catch (e) {
      print('❌ Error showing ad: $e');
    }

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Kart görseli oluşturuluyor...'),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      if (!mounted) return;
      final overlay = Overlay.of(context);
      late OverlayEntry overlayEntry;
      final controller = WidgetsToImageController();

      final imageUrl = await _greetingService.fetchImageForMessage(
        _selectedCategoryId!,
        messageId: _selectedMessageId,
      );
      if (imageUrl != null && imageUrl.isNotEmpty && mounted) {
        await precacheImage(NetworkImage(imageUrl), context);
      }
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
                      categoryId: _selectedCategoryId!,
                      messageText: _messageText,
                      messageTitle: _messageTitle,
                      imageUrl: imageUrl,
                      width: 1080,
                      height: 1080,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      overlay.insert(overlayEntry);
      await Future.delayed(Duration(milliseconds: imageUrl != null && imageUrl.isNotEmpty ? 800 : 500));

      final bytes = await controller.capture();
      overlayEntry.remove();

      if (bytes != null && bytes.isNotEmpty) {
        final directory = await getTemporaryDirectory();
        final imagePath =
            '${directory.path}/greeting_${DateTime.now().millisecondsSinceEpoch}.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(imagePath)],
          text: '$_messageTitle\n\n$_messageText\n\nGünlük Dua & Hadis Uygulamasından paylaşıldı',
          subject: _messageTitle,
        );

        FirebaseService.logEvent(
          name: AnalyticsEvents.greetingShared,
          parameters: {
            AnalyticsParams.category: _selectedCategoryId!,
            AnalyticsParams.messageType: _isCustomMessage ? 'custom' : 'predefined',
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
      print('❌ Error sharing: $e');
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

  void _shareAsText() {
    if (_messageText.isEmpty) return;
    Share.share(
      '$_messageTitle\n\n$_messageText\n\nGünlük Dua & Hadis Uygulamasından paylaşıldı',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _mainGroup != null || _selectedCategoryId != null
              ? 'Mesaj Paylaş'
              : 'Cuma, Kandil & Bayram',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: _canGoBack()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _onBackPressed,
              )
            : null,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0FDFA), Color(0xFFCCFBF1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
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
    // Step 1: Main group selection (Cuma, Kandiller, Bayramlar)
    if (_mainGroup == null) {
      return _buildMainGroupSelection();
    }

    // Step 2: Sub-category for Kandiller or Bayramlar
    if ((_mainGroup == 'kandil' || _mainGroup == 'bayram') &&
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
          const Text(
            'Kategori Seçin',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F766E),
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
        ],
      ),
    );
  }

  Widget _categoryChip(String label, IconData icon, {VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF0D9488), size: 28),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F766E),
                ),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF0D9488)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubCategorySelection() {
    final ids = _mainGroup == 'kandil'
        ? _greetingService.getKandilIds()
        : _greetingService.getBayramIds();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Alt Kategori Seçin',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F766E),
          ),
        ),
        const SizedBox(height: 16),
        ...ids.map((id) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _categoryChip(
                GreetingCategoryInfo.getDisplayName(id),
                _mainGroup == 'kandil' ? Icons.nightlight_round : Icons.celebration,
                onTap: () => _selectCategory(id),
              ),
            )),
      ],
    );
  }

  Widget _buildMessageSelection() {
    final messages = _greetingService.getMessagesForCategory(_selectedCategoryId!);

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
                  color: Color(0xFF0F766E),
                ),
              ),
              const SizedBox(height: 16),
              ...messages.map((msg) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _messageCard(msg),
                  )),
              const SizedBox(height: 12),
              Material(
                color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => _showCustomMessageDialog(),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.edit_note,
                            color: const Color(0xFF0D9488), size: 28),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Özel mesaj yaz',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _messageCard(GreetingMessage msg) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: () => _selectMessage(msg),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            msg.text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF2C3E50),
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  void _showCustomMessageDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Özel Mesaj Yaz'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: 'Mesajınızı yazın...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                _setCustomMessage(text, 'Özel Mesaj');
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            child: const Text('Kullan'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Önizleme',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<String?>(
            future: _imageFuture,
            builder: (context, snapshot) {
              final imageUrl = snapshot.data;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      child: GreetingShareableCard(
                        categoryId: _selectedCategoryId!,
                        messageText: _messageText,
                        messageTitle: _messageTitle,
                        imageUrl: imageUrl,
                        width: 1080,
                        height: 1080,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _isSharing ? null : _shareGreeting,
                icon: _isSharing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.share, size: 22),
                label: Text(
                  _isSharing ? 'Paylaşılıyor...' : 'Paylaş',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _isSharing
                    ? null
                      : () => setState(() {
                            _messageText = '';
                            _messageTitle = '';
                            _selectedMessageId = null;
                            _imageFuture = null;
                          }),
                icon: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: Colors.grey[600],
                ),
                label: Text(
                  'Değiştir',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
