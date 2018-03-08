import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  void _logVisit() async {
    final SharedPreferences prefs = await _prefs;
    final int counter = (prefs.getInt(ENTRIES_LEFT) ?? 1) - 1;
    setState(() {
      prefs.setInt(ENTRIES_LEFT, counter);
    });
  }

  void _recharge() async {
    const DEFAULT_RECHARGE_ENTRIES = '10';
    TextEditingController controller = new TextEditingController(text: DEFAULT_RECHARGE_ENTRIES);
    final int entriesRecharge = await Navigator.of(context).push(new MaterialPageRoute<int>(builder: (BuildContext context) {

      return new AppBar(
          title: const Text('Recharge pass'),
          actions: <Widget>[
            new FlatButton(
                onPressed: () {
                  Navigator.of(context).pop(int.parse(controller.text, onError: (source) => 0));
                },
                child: new Text('Recharge'))
          ],
          flexibleSpace: new Center(
              child: new Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[new TextField(controller: controller, keyboardType: TextInputType.number)],
          )));
    }));

    final SharedPreferences prefs = await _prefs;
    final int counter = (prefs.getInt(ENTRIES_LEFT) ?? 0) + entriesRecharge;
    setState(() {
      prefs.setInt(ENTRIES_LEFT, counter);
    });
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
            onPressed: _recharge,
          ),
        ],
      ),
      body: new Center(
        child: new FutureBuilder<SharedPreferences>(
          future: _prefs,
          builder: (BuildContext context, AsyncSnapshot<SharedPreferences> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Text('Loading...');

            final int _entriesLeft = snapshot.requireData.getInt(ENTRIES_LEFT) ?? 0;
            return new Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new Text(
                  'Remaining entries:',
                ),
                new Text(
                  '$_entriesLeft',
                  style: Theme.of(context).textTheme.display1,
                ),
              ]);
          }
        ),
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: _logVisit,
        tooltip: 'Log visit',
        child: new Icon(Icons.add),
      ),
    );
  }
}
