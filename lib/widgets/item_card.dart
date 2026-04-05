import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/daily_item.dart';
import '../services/pixabay_image_service.dart';

/// Beautiful card widget to display Daily Dua/Hadith/Ayah
class ItemCard extends StatefulWidget {
  final DailyItem item;
  final VoidCallback onShare;
  final VoidCallback onNext;
  final VoidCallback? onMarkAsRead;
  final bool isSharing;
  final bool isRead;

  const ItemCard({
    super.key,
    required this.item,
    required this.onShare,
    required this.onNext,
    this.onMarkAsRead,
    this.isSharing = false,
    this.isRead = false,
  });

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  final PixabayImageService _pixabay = PixabayImageService();
  String? _imageUrl;
  bool _imageLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBackgroundImage();
  }

  Future<void> _loadBackgroundImage() async {
    final url = await _pixabay.fetchRandomImage('günlük_dua');
    if (mounted) {
      setState(() {
        _imageUrl = url;
        _imageLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background image
            if (_imageUrl != null && !_imageLoading)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: _imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.white),
                  errorWidget: (context, url, error) => Container(color: Colors.white),
                ),
              ),
            
            // White overlay for readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.92),
                      Colors.white.withOpacity(0.95),
                      Colors.white.withOpacity(0.92),
                    ],
                  ),
                ),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title with icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.item.getIcon(),
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.item.getTitle(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      if (widget.isRead) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF1E40AF),
                          size: 24,
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Divider
                  Container(
                    height: 2,
                    width: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 100),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E40AF).withValues(alpha: 0.3),
                          const Color(0xFF1E40AF),
                          const Color(0xFF1E40AF).withValues(alpha: 0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Main text
                  Text(
                    widget.item.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.8,
                      color: Color(0xFF2C3E50),
                      letterSpacing: 0.5,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Source
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '— ${widget.item.source}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF1E40AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Mark as read button (if not read yet)
                  if (!widget.isRead && widget.onMarkAsRead != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: widget.onMarkAsRead,
                          icon: const Icon(Icons.check_circle_outline, size: 20),
                          label: const Text('Okudum olarak işaretle'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),
                  
                  // Action buttons
                  Row(
                    children: [
                      // Share button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.isSharing ? null : widget.onShare,
                          icon: widget.isSharing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.share, size: 20),
                          label: Text(widget.isSharing ? 'Oluşturuluyor...' : 'Paylaş'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E40AF),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF1E40AF).withValues(alpha: 0.6),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Next button (amber accent)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.onNext,
                          icon: const Icon(Icons.refresh, size: 20),
                          label: const Text('Sonraki'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading widget
class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF1E40AF),
          ),
          SizedBox(height: 20),
          Text(
            'Yükleniyor...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF1E40AF),
            ),
          ),
        ],
      ),
    );
  }
}

