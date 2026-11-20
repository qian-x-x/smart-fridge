enum FridgeZoneId { fresh, variable, freezer }

class FridgeContainer {
  const FridgeContainer({
    required this.id,
    required this.name,
    required this.type,
  });

  final int id;
  final String name;
  final String type;
}

class FridgeZone {
  const FridgeZone({
    required this.id,
    required this.name,
    required this.description,
    required this.temperature,
    required this.emoji,
    this.serverId,
    this.containers = const [],
  });

  final FridgeZoneId id;
  final String name;
  final String description;
  final String temperature;
  final String emoji;
  final int? serverId;
  final List<FridgeContainer> containers;
}

class FridgeFood {
  const FridgeFood({
    required this.id,
    required this.name,
    required this.emoji,
    required this.quantity,
    required this.unit,
    required this.expiresInDays,
    required this.zone,
    required this.category,
    required this.owner,
    required this.tilt,
    this.serverId,
    this.containerId,
    this.version = 0,
    this.tags = const [],
    this.productionDate,
    this.expiresOn,
    this.modelKey,
  });

  final String id;
  final String name;
  final String emoji;
  final double quantity;
  final String unit;
  final int expiresInDays;
  final FridgeZoneId zone;
  final String category;
  final String owner;
  final double tilt;
  final int? serverId;
  final int? containerId;
  final int version;
  final List<String> tags;
  final String? productionDate;
  final String? expiresOn;
  final String? modelKey;

  bool get isExpiring => expiresInDays <= 3;
  bool get isStickerFood => modelKey?.startsWith('sticker:') ?? false;
}

const demoZones = [
  FridgeZone(
    id: FridgeZoneId.fresh,
    name: '冷藏',
    description: '蔬果 · 饮品 · 奶制品',
    temperature: '4°C',
    emoji: '🥬',
  ),
  FridgeZone(
    id: FridgeZoneId.variable,
    name: '变温',
    description: '调味品 · 干货 · 短期肉类和海鲜',
    temperature: '0°C',
    emoji: '🥩',
  ),
  FridgeZone(
    id: FridgeZoneId.freezer,
    name: '冷冻',
    description: '速冻 · 长期肉类和海鲜',
    temperature: '-18°C',
    emoji: '🧊',
  ),
];

const demoFoods = [
  FridgeFood(
    id: 'food-tomato',
    name: '番茄',
    emoji: '🍅',
    quantity: 4,
    unit: '个',
    expiresInDays: 2,
    zone: FridgeZoneId.fresh,
    category: '蔬菜',
    owner: '小满',
    tilt: -0.04,
  ),
  FridgeFood(
    id: 'food-egg',
    name: '鸡蛋',
    emoji: '🥚',
    quantity: 6,
    unit: '枚',
    expiresInDays: 8,
    zone: FridgeZoneId.fresh,
    category: '蛋奶',
    owner: '阿成',
    tilt: 0.03,
  ),
  FridgeFood(
    id: 'food-milk',
    name: '鲜牛奶',
    emoji: '🥛',
    quantity: 1,
    unit: '盒',
    expiresInDays: 1,
    zone: FridgeZoneId.fresh,
    category: '饮品',
    owner: '小满',
    tilt: 0.05,
  ),
  FridgeFood(
    id: 'food-lettuce',
    name: '生菜',
    emoji: '🥬',
    quantity: 1,
    unit: '把',
    expiresInDays: 3,
    zone: FridgeZoneId.fresh,
    category: '蔬菜',
    owner: '阿成',
    tilt: -0.05,
  ),
  FridgeFood(
    id: 'food-beef',
    name: '牛里脊',
    emoji: '🥩',
    quantity: 300,
    unit: '克',
    expiresInDays: 2,
    zone: FridgeZoneId.variable,
    category: '肉类',
    owner: '小满',
    tilt: 0.03,
  ),
  FridgeFood(
    id: 'food-shrimp',
    name: '鲜虾',
    emoji: '🍤',
    quantity: 1,
    unit: '盒',
    expiresInDays: 4,
    zone: FridgeZoneId.variable,
    category: '海鲜',
    owner: '小满',
    tilt: -0.04,
  ),
  FridgeFood(
    id: 'food-dumpling',
    name: '手工水饺',
    emoji: '🥟',
    quantity: 18,
    unit: '只',
    expiresInDays: 20,
    zone: FridgeZoneId.freezer,
    category: '主食',
    owner: '阿成',
    tilt: 0.04,
  ),
  FridgeFood(
    id: 'food-blueberry',
    name: '蓝莓',
    emoji: '🫐',
    quantity: 1,
    unit: '盒',
    expiresInDays: 5,
    zone: FridgeZoneId.freezer,
    category: '水果',
    owner: '小满',
    tilt: -0.03,
  ),
  FridgeFood(
    id: 'food-rice',
    name: '大米',
    emoji: '🍚',
    quantity: 2.4,
    unit: '千克',
    expiresInDays: 120,
    zone: FridgeZoneId.fresh,
    category: '主食',
    owner: '阿成',
    tilt: 0.05,
  ),
  FridgeFood(
    id: 'food-soy',
    name: '生抽',
    emoji: '🍶',
    quantity: 1,
    unit: '瓶',
    expiresInDays: 180,
    zone: FridgeZoneId.fresh,
    category: '调料',
    owner: '小满',
    tilt: -0.04,
  ),
];
