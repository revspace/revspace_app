import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart' show launch;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' show Client;

import 'password_field.dart';

class RevSettings {
  static final FlutterSecureStorage _secureStorage = new FlutterSecureStorage();
  static final GlobalKey<FormState> _settingsFormKey = new GlobalKey<FormState>();
  static final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  static String _newUsername;
  static String _newPassword;

  static Scaffold getScaffold() {
    return new Scaffold(
      key: _scaffoldKey,
      appBar: new AppBar(
        title: new Text('RevSpace Settings'),
      ),
      body: new SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: new Form(
          key: _settingsFormKey,
          child: new Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 24.0),
            new Row(children: [
              const Expanded(
                child: const Text('This account should be your revSpace Wiki account.\n\n'
                    'If you don\'t already have a wiki account, please contact a board member.'),
              ),
              new FloatingActionButton(
                  child: const Icon(Icons.email),
                  tooltip: 'Send email to board',
                  mini: true,
                  onPressed: () {
                    launch('mailto:board@revspace.nl?subject=Nieuw wiki account&body='
                        'Beste Bestuur,\n\n'
                        'Graag zou ik een account krijgen voor de RevSpace Wiki.\n\n'
                        'Mijn nickname is: \n\n'
                        'Geautomatiseerde groeten,\n\n'
                        'De RevSpace App');
                  }),
            ]),
            const SizedBox(height: 24.0),
            new TextFormField(
              decoration: const InputDecoration(
                border: const UnderlineInputBorder(),
                filled: true,
                hintText: 'RevSpace Wiki username',
                labelText: 'Username',
              ),
              onSaved: (String value) {
                _newUsername = value;
              },
            ),
            const SizedBox(height: 24.0),
            new PasswordField(
              hintText: 'RevSpace Wiki password',
              labelText: 'Password',
              onSaved: (String value) {
                _newPassword = value;
              },
            ),
            const SizedBox(height: 24.0),
            new Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                new RaisedButton.icon(
                  onPressed: _testSettings,
                  icon: const Icon(Icons.account_box),
                  label: const Text('Test login'),
                ),
              ],
            ),
          ]),
          onChanged: () {
            _settingsFormKey.currentState.save();
          },
        ),
      ),
    );
  }

  static void _testSettings() {
    _scaffoldKey.currentState.showSnackBar(new SnackBar(
      duration: new Duration(days: 9001),
      content: new Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          new CircularProgressIndicator(),
          new SizedBox(width: 24.0),
          new Text('Testing login details...'),
        ],
      ),
    ));

    String url = 'https://revspace.nl/api.php';
    Client wikiClient = new Client();
    wikiClient.post(url, body: {
      'action': 'login',
      'lgname': _newUsername,
    }).then((response) {
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");
    });
  }
}
