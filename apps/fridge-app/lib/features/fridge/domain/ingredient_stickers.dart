import 'fridge_data.dart';

class IngredientSticker {
  const IngredientSticker(
    this.name,
    this.category,
    this.zone, {
    this.choiceOfStorage = false,
    this.artwork,
    this.hasPhoto = true,
  });

  final String name;
  final String category;
  final FridgeZoneId zone;
  final bool choiceOfStorage;
  final String? artwork;
  final bool hasPhoto;

  String get modelKey => 'sticker:$name';
  String? get imageName => hasPhoto ? artwork ?? name : null;
  String? get asset {
    final image = imageName;
    return image == null
        ? null
        : 'assets/images/ingredient-stickers/$image.webp';
  }
}

const ingredientStickers = [
  // 蔬菜
  IngredientSticker('冬瓜', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('南瓜', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('土豆', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('小米辣', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('山药', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('洋葱', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('玉米', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('生菜', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('白菜', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('空心菜', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('胡萝卜', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('芹菜', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('苦瓜', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('茄子', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('莲藕', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('莴笋', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('菠菜', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('西兰花', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('西红柿', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('豆角', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('金针菇', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('青椒', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('韭菜', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('香菇', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('香菜', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('黄瓜', '蔬菜', FridgeZoneId.fresh),
  IngredientSticker('上海青', '蔬菜', FridgeZoneId.fresh, hasPhoto: false),
  IngredientSticker('小葱', '蔬菜', FridgeZoneId.fresh, hasPhoto: false),
  // 水果
  IngredientSticker('柠檬', '水果', FridgeZoneId.fresh),
  IngredientSticker('桃子', '水果', FridgeZoneId.fresh),
  IngredientSticker('梨', '水果', FridgeZoneId.fresh),
  IngredientSticker('樱桃', '水果', FridgeZoneId.fresh),
  IngredientSticker('橙子', '水果', FridgeZoneId.fresh),
  IngredientSticker('火龙果', '水果', FridgeZoneId.fresh),
  IngredientSticker('牛油果', '水果', FridgeZoneId.fresh),
  IngredientSticker('猕猴桃', '水果', FridgeZoneId.fresh),
  IngredientSticker('芒果', '水果', FridgeZoneId.fresh),
  IngredientSticker('苹果', '水果', FridgeZoneId.fresh),
  IngredientSticker('草莓', '水果', FridgeZoneId.fresh),
  IngredientSticker('菠萝', '水果', FridgeZoneId.fresh),
  IngredientSticker('葡萄', '水果', FridgeZoneId.fresh),
  IngredientSticker('蓝莓', '水果', FridgeZoneId.fresh),
  IngredientSticker('西瓜', '水果', FridgeZoneId.fresh),
  IngredientSticker('香蕉', '水果', FridgeZoneId.fresh),
  // 饮品
  IngredientSticker('可乐', '饮品', FridgeZoneId.fresh),
  IngredientSticker('咖啡', '饮品', FridgeZoneId.fresh),
  IngredientSticker('啤酒', '饮品', FridgeZoneId.fresh),
  IngredientSticker('普洱茶饼', '饮品', FridgeZoneId.variable),
  IngredientSticker('椰汁', '饮品', FridgeZoneId.fresh),
  IngredientSticker('橙汁', '饮品', FridgeZoneId.fresh),
  IngredientSticker('矿泉水', '饮品', FridgeZoneId.fresh),
  IngredientSticker('红茶', '饮品', FridgeZoneId.fresh),
  IngredientSticker('绿茶', '饮品', FridgeZoneId.fresh),
  IngredientSticker('绿茶茶叶', '饮品', FridgeZoneId.variable),
  IngredientSticker('豆浆', '饮品', FridgeZoneId.variable),
  // 奶制品
  IngredientSticker('奶油', '奶制品', FridgeZoneId.fresh),
  IngredientSticker('奶粉', '奶制品', FridgeZoneId.fresh),
  IngredientSticker('奶酪', '奶制品', FridgeZoneId.fresh),
  IngredientSticker('炼乳', '奶制品', FridgeZoneId.fresh),
  IngredientSticker('牛奶', '奶制品', FridgeZoneId.fresh),
  IngredientSticker('芝士片', '奶制品', FridgeZoneId.fresh),
  IngredientSticker('酸奶', '奶制品', FridgeZoneId.fresh),
  IngredientSticker('黄油', '奶制品', FridgeZoneId.fresh),
  // 蛋奶豆制品
  IngredientSticker('豆腐', '蛋奶豆制品', FridgeZoneId.variable),
  IngredientSticker('鸡蛋', '蛋奶豆制品', FridgeZoneId.fresh),
  // 肉类
  IngredientSticker('五花肉', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('培根', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('排骨', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('整鸡', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('火腿', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('牛排', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('牛腩', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('猪肝', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('猪蹄', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('羊排', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('羊肉卷', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('肉馅', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('肥牛卷', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('腊肉', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('里脊肉', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('香肠', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('鸡爪', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('鸡翅', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('鸡胸肉', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('鸡腿', '肉类', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker(
    '猪肉末',
    '肉类',
    FridgeZoneId.variable,
    artwork: '肉馅',
    choiceOfStorage: true,
  ),
  // 海鲜
  IngredientSticker('三文鱼', '海鲜', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('带鱼', '海鲜', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('扇贝', '海鲜', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('生蚝', '海鲜', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('花甲', '海鲜', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('虾', '海鲜', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('螃蟹', '海鲜', FridgeZoneId.variable, choiceOfStorage: true),
  IngredientSticker('鱿鱼', '海鲜', FridgeZoneId.variable, choiceOfStorage: true),
  // 速冻食品
  IngredientSticker('冰块', '速冻食品', FridgeZoneId.freezer),
  IngredientSticker('包子', '速冻食品', FridgeZoneId.freezer),
  IngredientSticker('手抓饼', '速冻食品', FridgeZoneId.freezer),
  IngredientSticker('春卷', '速冻食品', FridgeZoneId.freezer),
  IngredientSticker('汤圆', '速冻食品', FridgeZoneId.freezer),
  IngredientSticker('烧麦', '速冻食品', FridgeZoneId.freezer),
  IngredientSticker('花卷', '速冻食品', FridgeZoneId.freezer),
  IngredientSticker('雪糕', '速冻食品', FridgeZoneId.freezer),
  IngredientSticker('饺子', '速冻食品', FridgeZoneId.freezer),
  IngredientSticker('馄饨', '速冻食品', FridgeZoneId.freezer),
  IngredientSticker('馒头', '速冻食品', FridgeZoneId.freezer),
  IngredientSticker('鱼丸', '速冻食品', FridgeZoneId.freezer),
  IngredientSticker('冷冻虾仁', '速冻食品', FridgeZoneId.freezer, artwork: '虾'),
  IngredientSticker('速冻玉米粒', '速冻食品', FridgeZoneId.freezer, artwork: '玉米'),
  // 调味品
  IngredientSticker('大蒜', '调味品', FridgeZoneId.variable),
  IngredientSticker('料酒', '调味品', FridgeZoneId.variable),
  IngredientSticker('淀粉', '调味品', FridgeZoneId.variable),
  IngredientSticker('生姜', '调味品', FridgeZoneId.variable),
  IngredientSticker('白糖', '调味品', FridgeZoneId.variable),
  IngredientSticker('胡椒粉', '调味品', FridgeZoneId.variable),
  IngredientSticker('花椒', '调味品', FridgeZoneId.variable),
  IngredientSticker('蚝油', '调味品', FridgeZoneId.variable),
  IngredientSticker('豆瓣酱', '调味品', FridgeZoneId.variable),
  IngredientSticker('辣椒酱', '调味品', FridgeZoneId.variable),
  IngredientSticker('酱油', '调味品', FridgeZoneId.variable),
  IngredientSticker('食用油', '调味品', FridgeZoneId.variable),
  IngredientSticker('食盐', '调味品', FridgeZoneId.variable),
  IngredientSticker('食醋', '调味品', FridgeZoneId.variable),
  IngredientSticker('香油', '调味品', FridgeZoneId.variable),
  IngredientSticker('鸡精', '调味品', FridgeZoneId.variable),
  IngredientSticker('生抽', '调味品', FridgeZoneId.variable, artwork: '酱油'),
  IngredientSticker('老抽', '调味品', FridgeZoneId.variable, artwork: '酱油'),
  IngredientSticker('白醋', '调味品', FridgeZoneId.variable, artwork: '食醋'),
  IngredientSticker('冰糖', '调味品', FridgeZoneId.variable, hasPhoto: false),
  // 干货
  IngredientSticker('八角', '干货', FridgeZoneId.variable),
  IngredientSticker('干辣椒', '干货', FridgeZoneId.variable),
  IngredientSticker('干香菇', '干货', FridgeZoneId.variable),
  IngredientSticker('木耳', '干货', FridgeZoneId.variable),
  IngredientSticker('枸杞', '干货', FridgeZoneId.variable),
  IngredientSticker('核桃', '干货', FridgeZoneId.variable),
  IngredientSticker('桂皮', '干货', FridgeZoneId.variable),
  IngredientSticker('海带', '干货', FridgeZoneId.variable),
  IngredientSticker('粉丝', '干货', FridgeZoneId.variable),
  IngredientSticker('紫菜', '干货', FridgeZoneId.variable),
  IngredientSticker('红枣', '干货', FridgeZoneId.variable),
  IngredientSticker('绿豆', '干货', FridgeZoneId.variable),
  IngredientSticker('腐竹', '干货', FridgeZoneId.variable),
  IngredientSticker('花生', '干货', FridgeZoneId.variable),
  IngredientSticker('虾米', '干货', FridgeZoneId.variable),
  IngredientSticker('银耳', '干货', FridgeZoneId.variable),
  IngredientSticker('大米', '干货', FridgeZoneId.variable, hasPhoto: false),
  IngredientSticker('中筋面粉', '干货', FridgeZoneId.variable, hasPhoto: false),
  IngredientSticker('熟花生米', '干货', FridgeZoneId.variable, artwork: '花生'),
  IngredientSticker('白芝麻', '干货', FridgeZoneId.variable, hasPhoto: false),
  // 零食
  IngredientSticker('冰淇淋', '零食', FridgeZoneId.freezer),
  IngredientSticker('巧克力', '零食', FridgeZoneId.variable),
  IngredientSticker('布丁', '零食', FridgeZoneId.fresh),
  IngredientSticker('果冻', '零食', FridgeZoneId.variable),
  IngredientSticker('棒棒糖', '零食', FridgeZoneId.variable),
  IngredientSticker('爆米花', '零食', FridgeZoneId.variable),
  IngredientSticker('瓜子', '零食', FridgeZoneId.variable),
  IngredientSticker('糖果', '零食', FridgeZoneId.variable),
  IngredientSticker('薯条', '零食', FridgeZoneId.variable),
  IngredientSticker('薯片', '零食', FridgeZoneId.variable),
  IngredientSticker('蛋黄派', '零食', FridgeZoneId.variable),
  IngredientSticker('辣条', '零食', FridgeZoneId.variable),
  IngredientSticker('锅巴', '零食', FridgeZoneId.variable),
  IngredientSticker('雪饼', '零食', FridgeZoneId.variable),
  IngredientSticker('饼干', '零食', FridgeZoneId.variable),
  IngredientSticker('魔芋爽', '零食', FridgeZoneId.variable),
];

final _stickersByName = {
  for (final sticker in ingredientStickers) sticker.name: sticker,
};
final _stickersByKey = {
  for (final sticker in ingredientStickers) sticker.modelKey: sticker,
};

const _stockArtworkNames = {
  '番茄': '西红柿',
  '鲜牛奶': '牛奶',
  '鲜虾': '虾',
  '手工水饺': '饺子',
  '水饺': '饺子',
  '豆奶': '豆浆',
  '盐': '食盐',
  '虾仁': '冷冻虾仁',
  '牛里脊': '牛排',
  '猪里脊': '里脊肉',
};

IngredientSticker? stickerForFood(FridgeFood food) =>
    _stickersByKey[food.modelKey] ??
    _stickersByName[_stockArtworkNames[food.name.trim()] ?? food.name.trim()];

String storageName(FridgeZoneId zone) => switch (zone) {
  FridgeZoneId.fresh => '冷藏',
  FridgeZoneId.variable => '变温',
  FridgeZoneId.freezer => '冷冻',
};
