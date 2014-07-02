//Copyright (C) 2014 Potix Corporation. All Rights Reserved.
//History: Tue, Jul 01, 2014 12:58:00 PM
// Author: tomyeh

import "dart:async";

import "package:unittest/unittest.dart";
import "package:entity/entity.dart";
import "package:entity/postgresql.dart";

import "package:postgresql/postgresql.dart" show Connection, connect;

import "sql_sample.dart";

const String DB_URI = "postgres://postgres:123@localhost:5432/testdb";

void main() {
  test("Entity Test on PostgreSQL", test1);
}

Future test1() {
  Connection conn;
  return connect(DB_URI)
  .then((_) => initDB(conn = _))
  .then((_) {
    final PostgresqlAccess access = new PostgresqlAccess(conn);
    Master m1 = new Master("m1");
    Detail d1 = new Detail(new DateTime.now(), 100);
    d1.master = m1.oid;
    Detail d2 = new Detail(new DateTime.now(), 200);
    d2.master = m1.oid;

    return Future.forEach([m1, d1, d2], (Entity e) => e.save(access))
    .then((_) => load(access, m1.oid, beMaster))
    .then((Master m) {
      expect(identical(m, m1), isFalse); //not the same instance
      expect(m.name, m1.name);
    })
    .then((_) => load(access, d1.oid, beDetail, const ["value", "createdAt"]))
    .then((Detail d) {
      expect(identical(d, d1), isFalse);
      expect(d.createdAt, d1.createdAt);
      expect(d.value, d1.value);
      expect(d.master, isNull);
    });
  })
  .whenComplete(() {
    if (conn != null) {
      return cleanDB(conn)
      .then((_) => conn.close())
      .catchError((ex, st) => print("Error ${ex.runtimeType}: $ex\n$st"));
    } else {
      print("Make sure you create a case-sensitive database called testdb, "
        "and the password must be 123");
    }
  });
}

Future initDB(Connection conn)
=> Future.forEach(const [
  """
  create table "Master" (
    "oid" varchar(40) primary key,
    "name" varchar(60)
  )
  """, """
  create table "Detail" (
    "oid" varchar(40) primary key,
    "createdAt" timestamp without time zone null,
    "value" integer,
    "master" varchar(40) null references "Master"("oid")
  )
  """],
  (String stmt) => conn.execute(stmt));

Future cleanDB(Connection conn)
=> Future.forEach(const ['"Detail"', '"Master"'],
  (String otype) => conn.execute("drop table $otype"));