import 'package:flutter/material.dart';
import '../models/daily_item.dart';

/// Beautiful card widget to display Daily Dua/Hadith/Ayah
class ItemCard extends StatelessWidget {
  final DailyItem item;
  final VoidCallback onShare;
  final VoidCallback onNext;
  final VoidCallback? onMarkAsRead;
  final bool isSharing;
  final bool isRead;

  const ItemCard({
    Key? key,
    required this.item,
    required this.onShare,
    required this.onNext,
    this.onMarkAsRead,
    this.isSharing = false,
    this.isRead = false,
  }) : super(key: key);

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title with icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.getIcon(),
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Text(
                item.getTitle(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F766E),
                ),
              ),
              if (isRead) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF0D9488),
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
                  const Color(0xFF0D9488).withValues(alpha: 0.3),
                  const Color(0xFF0D9488),
                  const Color(0xFF0D9488).withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Main text
          Text(
            item.text,
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
              color: const Color(0xFFF0FDFA).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '— ${item.source}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Color(0xFF0D9488),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Mark as read button (if not read yet)
          if (!isRead && onMarkAsRead != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onMarkAsRead,
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text('Okudum olarak işaretle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
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
                  onPressed: isSharing ? null : onShare,
                  icon: isSharing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.share, size: 20),
                  label: Text(isSharing ? 'Oluşturuluyor...' : 'Paylaş'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.6),
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
                  onPressed: onNext,
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
    );
  }
}

/// Loading widget
class LoadingCard extends StatelessWidget {
  const LoadingCard({Key? key}) : super(key: key);

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
            color: Color(0xFF0D9488),
          ),
          SizedBox(height: 20),
          Text(
            'Yükleniyor...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF0D9488),
            ),
          ),
        ],
      ),
    );
  }
}

