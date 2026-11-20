import 'dart:math';

import 'fridge_data.dart';

enum FoodExpiryWindow {
  all('全部期限'),
  threeDays('3日内', maxDays: 3),
  sevenDays('7日内', maxDays: 7),
  thirtyDays('30日内', maxDays: 30),
  sixMonths('半年内'),
  longTerm('长期');

  const FoodExpiryWindow(this.label, {this.maxDays});

  final String label;
  final int? maxDays;

  bool includes(FridgeFood food) {
    if (this == all) return true;
    final remainingDays = food.expiresInDays;
    if (remainingDays < 0) return false;
    final limit = maxDays;
    if (limit != null) return remainingDays <= limit;

    // The server supplies the expiry date and the days left in the fridge's
    // time zone. Use those calendar dates without the device's local offset.
    final expiresOn = food.expiresOn;
    if (expiresOn == null) return false;
    final expiry = DateTime.tryParse('${expiresOn}T00:00:00Z');
    if (expiry == null) return false;
    final today = expiry.subtract(Duration(days: remainingDays));
    final lastDay = DateTime.utc(today.year, today.month + 7, 0).day;
    final cutoff = DateTime.utc(
      today.year,
      today.month + 6,
      min(today.day, lastDay),
    );
    return this == longTerm ? expiry.isAfter(cutoff) : !expiry.isAfter(cutoff);
  }
}

class FoodFilter {
  const FoodFilter({
    this.query = '',
    this.category = '',
    this.tags = const [],
    this.zoneId,
    this.expiryState = 'ALL',
    this.expiresFrom = '',
    this.expiresTo = '',
    this.sort = 'EXPIRES_ASC',
  });

  final String query;
  final String category;
  final List<String> tags;
  final int? zoneId;
  final String expiryState;
  final String expiresFrom;
  final String expiresTo;
  final String sort;

  Map<String, dynamic> toQuery(int fridgeId) => {
    'fridgeId': fridgeId,
    if (query.trim().isNotEmpty) 'query': query.trim(),
    if (category.trim().isNotEmpty) 'category': category.trim(),
    if (tags.isNotEmpty) 'tags': tags.map((tag) => tag.trim()).toSet().toList(),
    if (zoneId != null) 'zoneId': zoneId,
    'expiryState': expiryState,
    if (expiresFrom.isNotEmpty) 'expiresFrom': expiresFrom,
    if (expiresTo.isNotEmpty) 'expiresTo': expiresTo,
    'sort': sort,
  };
}
