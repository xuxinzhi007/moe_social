import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/game/pet/pet_adventure_game.dart';
import 'package:moe_social/widgets/pet/pet_care_juice_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PetCareJuiceController builds combo streak inside window', () {
    final juice = PetCareJuiceController();
    final a = juice.register(
      PetJuiceKind.feed,
      label: '+饱食',
      color: Colors.orange,
    );
    final b = juice.register(
      PetJuiceKind.care,
      label: '+心情',
      color: Colors.pink,
    );
    expect(a, 1);
    expect(b, 2);
    expect(juice.bursts.last.label, contains('连击×2'));
    juice.dispose();
  });

  test('PetAdventureGame win threshold is 28', () {
    expect(PetAdventureGame.winThreshold, 28);
  });
}
