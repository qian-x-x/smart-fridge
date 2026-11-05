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
