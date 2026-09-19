import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ativ_ext2/main.dart';

void main() {
  testWidgets('App loads', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Estrutura Flutter pronta!'), findsOneWidget);
  });
}
