import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/ready_message_design.dart';

class ReadyMessageService {
  static const _catalogAsset = 'assets/ready_message_designs.json';

  Future<List<ReadyMessageDesign>> loadDesigns() async {
    final source = await rootBundle.loadString(_catalogAsset);
    final decoded = jsonDecode(source);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(ReadyMessageDesign.fromJson)
        .where(
          (design) =>
              design.id.isNotEmpty &&
              design.backgroundAssetPath.isNotEmpty &&
              design.message.isNotEmpty,
        )
        .toList(growable: false);
  }
}
