/// 养成 UI 文案（内部 ID → 中文展示）。
class PetLabels {
  const PetLabels._();

  static const Map<String, String> item = {
    '': '无',
    'hat_cap': '鸭舌帽',
    'hat_beret': '贝雷帽',
    'hat_crown': '小皇冠',
    'hat_bow': '蝴蝶结',
    'hat_earmuff': '耳罩',
    'hat_vip_star': '星光礼帽',
    'top_basic': '基础上衣',
    'top_hoodie': '连帽衫',
    'top_tee': 'T 恤',
    'top_coat': '外套',
    'top_dress': '连衣裙',
    'top_vest': '背心',
    'bottom_basic': '基础下装',
    'bottom_skirt': '短裙',
    'bottom_jeans': '牛仔裤',
    'bottom_shorts': '短裤',
    'bottom_pants': '长裤',
    'bottom_overall': '背带裤',
    'shoes_basic': '基础鞋',
    'shoes_sneaker': '运动鞋',
    'shoes_boot': '靴子',
    'shoes_sandal': '凉鞋',
    'shoes_slipper': '拖鞋',
    'shoes_heel': '小皮鞋',
    'bed_basic': '小床',
    'bed_cozy': '温馨小床',
    'table_wood': '木桌',
    'lamp_basic': '台灯',
    'lamp_soft': '柔光灯',
    'rug_basic': '地毯',
    'rug_heart': '爱心地毯',
    'window_lace': '窗饰',
  };

  static String of(String id) => item[id] ?? id;
}
