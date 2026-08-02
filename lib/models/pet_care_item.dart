/// A server-recognised care item that can be used in the pet home.
class PetCareItem {
  const PetCareItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.hungerGain,
    required this.moodGain,
  });

  final String id;
  final String name;
  final String emoji;
  final String description;
  final int hungerGain;
  final int moodGain;

  static const foods = <PetCareItem>[
    PetCareItem(
        id: 'home_meal',
        name: '暖心家常餐',
        emoji: '🍚',
        description: '刚刚好的日常一餐',
        hungerGain: 18,
        moodGain: 4),
    PetCareItem(
        id: 'fruit_yogurt',
        name: '水果酸奶',
        emoji: '🍓',
        description: '轻盈又有好心情',
        hungerGain: 12,
        moodGain: 10),
    PetCareItem(
        id: 'energy_soup',
        name: '元气浓汤',
        emoji: '🍲',
        description: '适合需要补充能量的时候',
        hungerGain: 24,
        moodGain: 5),
  ];
}
