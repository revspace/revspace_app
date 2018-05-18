import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart' show launch;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'password_field.dart';

class RevSettings {
  static final FlutterSecureStorage _secureStorage = new FlutterSecureStorage();
  static final GlobalKey<FormState> _settingsFormKey = new GlobalKey<FormState>();
  static final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  static String _newUsername, _newPassword;
  static bool _snackbarState = false;

  static Scaffold getScaffold(TextEditingController usernameController, TextEditingController passwordController) {
    return new Scaffold(
      key: _scaffoldKey,
      appBar: new AppBar(
        title: new Text('RevSpace Settings'),
      ),
      body: new SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 80.0),
        child: new Form(
          key: _settingsFormKey,
          child: new Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24.0),
              new Row(children: [
                const Expanded(
                  child: const Text('This account should be your RevSpace Wiki account. '
                      'If you don\'t already have a wiki account, please contact a board member.'),
                ),
                new FloatingActionButton(
                    child: const Icon(Icons.email),
                    tooltip: 'Send email to board',
                    mini: true,
                    elevation: 3.0,
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
                controller: usernameController,
                onSaved: (String value) {
                  _newUsername = value;
                },
              ),
              const SizedBox(height: 24.0),
              new PasswordField(
                hintText: 'RevSpace Wiki password',
                labelText: 'Password',
                controller: passwordController,
                onSaved: (String value) {
                  _newPassword = value;
                },
              ),
            ],
          ),
          onChanged: () {
            _settingsFormKey.currentState.save();
            if (!_snackbarState) {
              _snackbarState = true;
              _scaffoldKey.currentState.hideCurrentSnackBar();
              _scaffoldKey.currentState.showSnackBar(new SnackBar(
                duration: new Duration(days: 9001),
                content: new Text(
                  'Your new settings have not been saved yet!',
                  softWrap: true,
                ),
                action: new SnackBarAction(label: 'TEST & SAVE', onPressed: _testSettings),
              ));
            }
          },
        ),
      ),
    );
  }

  static void _testSettings() {
    _snackbarState = false;
    _scaffoldKey.currentState.hideCurrentSnackBar();
    _scaffoldKey.currentState.showSnackBar(new SnackBar(
      duration: new Duration(days: 9001),
      content: new LinearProgressIndicator(),
    ));

    // FIXME: this code is written for mediawiki 1.2, it throws warnings
    // about deprecation in 1.28 and might stop working in the near future.
    // See https://www.mediawiki.org/wiki/API:Login for details

    Uri wikiAPI = Uri.parse('https://revspace.nl/api.php');
    wikiAPI = Uri.parse('http://192.168.111.234/api.php');

    HttpClient wikiClient = new HttpClient();
    wikiClient.userAgent = 'RevSpaceApp (Dart ${Platform.version})';

    wikiClient.postUrl(wikiAPI).then((HttpClientRequest request) {
      String data = 'format=json&action=login'
          '&lgname=${Uri.encodeQueryComponent(_newUsername)}';
      request.headers.contentType = new ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      request.headers.contentLength = data.length;
      request.write(data);
      return request.close();
    }).then((HttpClientResponse response) {
      response.listen((data) {
        String token = json.decode(new String.fromCharCodes(data))['login']['token'];
        wikiClient.postUrl(wikiAPI).then((HttpClientRequest request) {
          String data = 'format=json&action=login'
              '&lgname=${Uri.encodeQueryComponent(_newUsername)}'
              '&lgpassword=${Uri.encodeQueryComponent(_newPassword)}'
              '&lgtoken=${Uri.encodeQueryComponent(token)}';
          request.headers.contentType = new ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
          request.headers.contentLength = data.length;
          request.cookies.addAll(response.cookies);
          request.write(data);
          return request.close();
        }).then((HttpClientResponse response) {
          response.listen((data) {
            _scaffoldKey.currentState.hideCurrentSnackBar();
            if (json.decode(new String.fromCharCodes(data))['login']['result'] == 'Success') {
              _scaffoldKey.currentState.showSnackBar(new SnackBar(
                duration: new Duration(seconds: 5),
                content: new Text(
                  'Your login settings are correct and have been saved!',
                  softWrap: true,
                  style: new TextStyle(fontSize: 16.0),
                ),
              ));
              _secureStorage.write(key: 'wikiUsername', value: _newUsername);
              _secureStorage.write(key: 'wikiPassword', value: _newPassword);
              print('success');
            } else {
              _scaffoldKey.currentState.showSnackBar(new SnackBar(
                duration: new Duration(days: 9001),
                content: new Text(
                  'Your login settings are incorrect!\nPlease try again.',
                  softWrap: true,
                  style: new TextStyle(fontSize: 16.0),
                ),
              ));
              print('fail');
            }
          });
        });
      });
    });
  }
}
