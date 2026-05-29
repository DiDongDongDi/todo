import 'package:drift/drift.dart';

/// Drift 表定义 — 与 ARCHITECTURE.md 一致。
/// 运行 `dart run build_runner build` 生成 `app_database.g.dart` 后可切换实现。
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get note => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('inbox'))();
  RealColumn get sortOrder => real().withDefault(const Constant(0))();
  TextColumn get attachments => text().withDefault(const Constant('[]'))();
  TextColumn get transcriptionStatus =>
      text().withDefault(const Constant('none'))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get trashedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
