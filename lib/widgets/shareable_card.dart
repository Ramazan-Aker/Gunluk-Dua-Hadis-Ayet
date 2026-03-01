import 'package:flutter/material.dart';
import '../models/daily_item.dart';

/// Paylaşılabilir kart - Ekrandaki ItemCard ile aynı görünüm, butonlar olmadan
/// Paylaş butonuna basıldığında oluşturulan görsel bu karttan üretilir
class ShareableCard extends StatelessWidget {
  final DailyItem item;
  final double width;
  final double height;

  const ShareableCard({
    Key? key,
    required this.item,
    this.width = 1080,
    this.height = 1080,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF0FDFA), Color(0xFFCCFBF1)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(60),
          padding: const EdgeInsets.all(50),
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
              // Icon + Title (ekrandaki kart gibi)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.getIcon(),
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      item.getTitle(),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // Divider
              Center(
                child: Container(
                  height: 3,
                  width: 80,
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
              ),
              const SizedBox(height: 40),
              // Main text
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    item.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      height: 1.8,
                      color: Color(0xFF2C3E50),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Source
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '— ${item.source}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF0D9488),
                    fontWeight: FontWeight.w500,
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
