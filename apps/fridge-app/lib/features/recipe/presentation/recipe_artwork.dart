/// Exact names prevent an unknown recipe from borrowing another dish's photo.
abstract final class RecipeArtwork {
  static const assets = <String, String>{
    '番茄滑蛋': 'assets/images/quiet-white-v2/tomato-eggs.jpg',
    '蒜蓉生菜': 'assets/images/quiet-white-v2/garlic-lettuce.jpg',
    '青椒炒鸡胸': 'assets/images/quiet-white-v2/pepper-chicken.jpg',
    '香煎三文鱼': 'assets/images/quiet-white-v2/pan-seared-salmon.jpg',
    '虾仁玉米炒饭': 'assets/images/quiet-white-v2/shrimp-corn-rice.jpg',
    '鲜蔬蛋饼': 'assets/images/quiet-white-v2/vegetable-egg-pancake.jpg',
    '酸辣土豆丝': 'assets/images/quiet-white-v2/sour-spicy-potatoes.jpg',
    '家常红烧肉': 'assets/images/quiet-white-v2/red-braised-pork.jpg',
    '宫保鸡丁': 'assets/images/quiet-white-v2/kung-pao-chicken.jpg',
    '麻婆豆腐': 'assets/images/quiet-white-v2/mapo-tofu.jpg',
    '可乐鸡翅': 'assets/images/quiet-white-v2/cola-chicken-wings.jpg',
    '蒜蓉西兰花': 'assets/images/quiet-white-v2/garlic-broccoli.jpg',
    '鱼香肉丝': 'assets/images/quiet-white-v2/fish-fragrant-pork.jpg',
    '香菇青菜': 'assets/images/quiet-white-v2/shiitake-bok-choy.jpg',
    '紫菜蛋花汤': 'assets/images/quiet-white-v2/seaweed-egg-soup.jpg',
    '拍黄瓜': 'assets/images/quiet-white-v2/smashed-cucumber.jpg',
    '嫩滑蒸蛋': 'assets/images/quiet-white-v2/steamed-eggs.jpg',
    '清蒸南瓜': 'assets/images/quiet-white-v2/steamed-pumpkin.jpg',
  };

  static String? forName(String name) => assets[name];
}
