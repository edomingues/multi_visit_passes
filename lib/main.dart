import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dao.dart';
import 'package:path_provider/path_provider.dart';
import "package:path/path.dart";
import "package:intl/intl.dart";

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Multi Visit Passes',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new MyHomePage(title: 'Multi Visit Pass'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const String ENTRIES_LEFT = 'entriesLeft';
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  VisitsProvider _visitsProvider;
  final dateFormat = new DateFormat('yyyy-MM-dd');

  Future _showNoEntriesAlert(BuildContext context) async {
    return showDialog(
        context: context,
        child: new AlertDialog(
          title: const Text("No entries left to use"),
          content: const Text("Please recharge"),

        )
    );
  }

  Future _logVisit(BuildContext context) async {

    final SharedPreferences prefs = await _prefs;
    int counter = (prefs.getInt(ENTRIES_LEFT) ?? 0);

    if (counter <= 0) {
      // No entries left, show alert
      return _showNoEntriesAlert(context);
    } else {
      // Ask date of visit (default: today)
      DateTime date = await showDatePicker(context: context,
          initialDate: new DateTime.now(),
          firstDate: new DateTime(0),
          lastDate: new DateTime(9999));
      if (date != null) {
        // User confirmed date, log visit
        counter--;
        _logVisitIntoDb(date);
        setState(() {
          prefs.setInt(ENTRIES_LEFT, counter);
        });
      }
    }
  }

  Future _recharge(BuildContext context) async {
    const DEFAULT_RECHARGE_ENTRIES = '10';
    TextEditingController controller = new TextEditingController(text: DEFAULT_RECHARGE_ENTRIES);

    Visit visit = new Visit();
    visit.date = new DateTime.now();
    final int entriesRecharge = await Navigator.of(context).push(new MaterialPageRoute<int>(builder: (BuildContext context) {

      return new Scaffold(
          appBar: new AppBar(
            title: const Text('Recharge pass'),
            actions: <Widget>[
              new FlatButton(
                onPressed: () {
                  Navigator.of(context).pop(int.parse(controller.text, onError: (source) => 0));
                },
                child: new Text('Recharge'))
          ]),
          body:new Column(
              children: <Widget>[
                new Row(
                  children: <Widget>[
                    new Container(child: const Text('Entries '), padding: const EdgeInsets.all(20.0), width: 90.0,),
                    new Container(
                      child: new TextField(controller: controller, keyboardType: TextInputType.number),
                      width: 48.0,
                   ),
                  ],
                ),
                new Row(
                  children: <Widget>[
                    new Container(child: const Text('Date '), padding: const EdgeInsets.all(20.0), width: 90.0,),
                    new Expanded(
                      child: new GestureDetector(
                        onTap: () {
                          // Ask date of recharge (default: date selected)
                          showDatePicker(context: context,
                              initialDate: visit.date,
                              firstDate: new DateTime(0),
                              lastDate: new DateTime(9999)).then((DateTime value) { if (value != null) {visit.date = value;} });
                        },
                        child:
                          new Text(dateFormat.format(visit.date))
                      )
                    ),
                  ],
                )
              ],
            )
      );
    }));

    if (entriesRecharge != null) {
      final SharedPreferences prefs = await _prefs;
      final int counter = (prefs.getInt(ENTRIES_LEFT) ?? 0) + entriesRecharge;
      _insertRechargeIntoDB(entriesRecharge, visit.date);
      setState(() {
        prefs.setInt(ENTRIES_LEFT, counter);
      });
    }
  }

  void _confirmDelete(BuildContext context, Visit visit) {
    showDialog(
        context: context,
        child: new AlertDialog(
          title: const Text("Delete?"),
          actions: <Widget>[
            new FlatButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text("Cancel")
            ),
            new FlatButton(
                onPressed: () {
                  _delete(visit);
                  Navigator.of(context).pop();
                },
                child: const Text("Delete")
            ),
          ],
        )
    );
  }

  Future _delete(Visit visit) async {
    final SharedPreferences prefs = await _prefs;
    int entriesCredit;
    if (visit.action == Action.visit) {
      entriesCredit = visit.entries;
    } else if (visit.action == Action.recharge) {
      entriesCredit = -visit.entries;
    }
    final int counter = (prefs.getInt(ENTRIES_LEFT) ?? 0) + entriesCredit;
    _deleteFromDb(visit.id);
    setState(() {
      prefs.setInt(ENTRIES_LEFT, counter);
    });
  }
  
  Future _logVisitIntoDb(DateTime date) async {
    Visit visit = new Visit();
    visit.date = date;
    visit.action = Action.visit;
    visit.entries = 1;
    _visitsProvider.insert(visit);
  }

  Future _insertRechargeIntoDB(int entries, DateTime date) async {
    Visit recharge = new Visit();
    recharge.date = date;
    recharge.action = Action.recharge;
    recharge.entries = entries;
    _visitsProvider.insert(recharge);
  }

  Future _deleteFromDb(int id) async {
    await _visitsProvider.delete(id);
  }

  Future _getVisitsProvider() async {
    // Get a location using path_provider
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "multivisitpass.db");

    VisitsProvider visitsProvider = new VisitsProvider();
    await visitsProvider.open(path);

    setState(() {
      _visitsProvider = visitsProvider;
    });
  }

  @override
  void initState() {
    super.initState();

    _getVisitsProvider();
  }

  @override
  void dispose() {

    _visitsProvider.close();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(widget.title),
        actions: <Widget>[
          new IconButton(
            icon: new Icon(Icons.replay),
            tooltip: 'Recharge',
            onPressed: () => _recharge(context),
          ),
        ],
      ),
      body: new Builder(
          builder: (BuildContext context) {
            if (_visitsProvider == null)
              return const Text('Loading...');
            return new FutureBuilder<List<Visit>>(
        future: _visitsProvider.getVisits(),
        builder: (BuildContext context, AsyncSnapshot<List<Visit>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Text('Loading...');
          return new ListView.builder(
            itemCount: snapshot.requireData.length + 1,
            itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return new FutureBuilder<SharedPreferences>(
                future: _prefs,
                builder: (BuildContext context,
                    AsyncSnapshot<SharedPreferences> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Text('Loading...');
                  final int _entriesLeft = snapshot.requireData.getInt(
                      ENTRIES_LEFT) ?? 0;
                  return new Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        new Text('Remaining entries:'),
                        new Text('$_entriesLeft', style: Theme
                            .of(context)
                            .textTheme
                            .display1),
                      ]);
                }
            );
          }
          else {
            List<Visit> visits = snapshot.requireData;
            if (index <= visits.length) {
              Visit visit = visits[index-1];

              return new ListTile(
                leading: new Icon(visit.action == Action.recharge ? Icons.replay : Icons.add),
                title: new Text('${visit.action == Action.recharge ? 'Recharge (${visit.entries})' : 'Visit'}'),
                subtitle: new Text(dateFormat.format(visit.date)),
                trailing: new IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDelete(context, visit),
                ),
              );
            }
            else {
              return null;
            }
          }
        }
        );}
      );}),
      floatingActionButton: new FloatingActionButton(
        onPressed: () => _logVisit(context),
        tooltip: 'Log visit',
        child: new Icon(Icons.add),
      ),
    );
  }
}
