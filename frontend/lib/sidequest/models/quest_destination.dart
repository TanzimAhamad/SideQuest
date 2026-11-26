import 'package:flutter/material.dart';

class QuestDestination {
  final int id;
  final String name;
  final String activity;
  final String area;
  final String description;
  final int estimatedCost;
  final IconData icon;
  final String? imageUrl;
  final String? sourceUrl;
  final String? priceLabel;
  final String? sourceName;
  final String? sourceId;
  final DateTime? scheduledAt;
  final int? createdByUserId;
  final String? createdByUsername;

  String get displayPrice => priceLabel ??
      (estimatedCost > 0 ? '৳$estimatedCost per person' : 'Price to be confirmed');

  const QuestDestination(
    this.id,
    this.name,
    this.activity,
    this.area,
    this.estimatedCost,
    this.description,
    this.icon, {
    this.imageUrl,
    this.sourceUrl,
    this.priceLabel,
    this.sourceName,
    this.sourceId,
    this.scheduledAt,
    this.createdByUserId,
    this.createdByUsername,
  });
}

/// Generates a positive ID for a live listing so it can use the existing
/// in-memory nomination and voting maps without changing their data type.
int questDestinationId(String sourceKey) {
  var hash = 0;
  for (final rune in sourceKey.runes) {
    hash = ((hash * 31) + rune) & 0x7fffffff;
  }
  return 100000 + (hash % 1900000000);
}
