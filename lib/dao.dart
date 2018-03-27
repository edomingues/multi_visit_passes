import 'dart:async';

import 'package:sqflite/sqflite.dart';

final String tableVisits = "visits";
final String columnId = "_id";
final String columnDate = "date";
final String columnAction = "action";
final String columnEntries = "entries"; // Number of entries/visits used or recharged

enum Action {
  visit, recharge
}

class Visit {
  int id;
  DateTime date;
  Action action;
  int entries;

  Map toMap() {
    Map map = {columnDate: date.millisecondsSinceEpoch, columnAction: action.index, columnEntries: entries};
    if (id != null) {
      map[columnId] = id;
    }
    return map;
  }

  Visit();

  Visit.fromMap(Map map) {
    id = map[columnId];
    date = new DateTime.fromMillisecondsSinceEpoch(map[columnDate]);
    action = Action.values.firstWhere((e) => e.index == map[columnAction]);
    entries = map[columnEntries];
  }

}

class VisitsProvider {
  Database db;

  Future open(String path) async {
    db = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
          await db.execute('''
create table $tableVisits ( 
  $columnId integer primary key autoincrement, 
  $columnDate integer not null,
  $columnAction integer not null,
  $columnEntries integer not null)
''');
        });
  }

  Future<Visit> insert(Visit visit) async {
    visit.id = await db.insert(tableVisits, visit.toMap());
    return visit;
  }

  Future<Visit> getVisit(int id) async {
    List<Map> maps = await db.query(tableVisits,
        columns: [columnId, columnDate, columnAction, columnEntries],
        where: "$columnId = ?",
        whereArgs: [id]);
    if (maps.length > 0) {
      return new Visit.fromMap(maps.first);
    }
    return null;
  }

  Future<int> delete(int id) async {
    return await db.delete(tableVisits, where: "$columnId = ?", whereArgs: [id]);
  }

  Future<int> update(Visit visit) async {
    return await db.update(tableVisits, visit.toMap(),
        where: "$columnId = ?", whereArgs: [visit.id]);
  }
  
  Future<int> countRecords() async {
    Future<List<Map<String, dynamic>>> f = db.rawQuery('SELECT COUNT(*) FROM "$tableVisits"');
    List<Map<String, dynamic>> l = await f;
    int i = l[0][0];
    return i;
  }

  Future<List<Visit>> getVisits() async {
    List<Map<String, dynamic>> records = await db.query(tableVisits, orderBy: "$columnDate desc");
    List<Visit> visits = records.map((Map map) => new Visit.fromMap(map)).toList();
    return visits;
  }

  Future close() async => db.close();
}