import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mooncake/entities/entities.dart';
import 'package:mooncake/sources/sources.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

void main() {
  Database database;
  LocalNotificationsSourceImpl source;

  setUp(() async {
    database = await databaseFactoryIo.openDatabase("notifications.db");
    source = LocalNotificationsSourceImpl(database: database);
  });

  tearDown(() async {
    File(database.path).deleteSync();
  });

  test('save works properly', () async {
    final not = TxSuccessfulNotification(date: DateTime.now(), txHash: "");
    await source.saveNotification(not);

    final count = await StoreRef.main().count(database);
    expect(count, equals(1));
  });

  test('notifications reading works properly', () async {
    final first = TxSuccessfulNotification(
      date: DateTime.fromMicrosecondsSinceEpoch(10000),
      txHash: "hash1",
    );
    final second = TxSuccessfulNotification(
      date: DateTime.fromMicrosecondsSinceEpoch(20000),
      txHash: "hash2",
    );

    final store = StoreRef.main();
    await store.addAll(database, [first.asJson(), second.asJson()]);
    expect(await store.count(database), equals(2));

    final result = await source.getNotifications();
    expect(result, equals([second, first]));
  });

  test('notificationsStream returns valid data', () async {
    final first = TxSuccessfulNotification(
      date: DateTime.fromMicrosecondsSinceEpoch(10000),
      txHash: "hash1",
    );
    final second = TxSuccessfulNotification(
      date: DateTime.fromMicrosecondsSinceEpoch(20000),
      txHash: "hash2",
    );

    final store = StoreRef.main();
    await store.add(database, first.asJson());
    await store.add(database, second.asJson());

    expectLater(source.notificationsStream, emitsInOrder([first, second]));
  });
}