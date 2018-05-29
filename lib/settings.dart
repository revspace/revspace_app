import 'dart:async' as Async;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:url_launcher/url_launcher.dart' as UrlLauncher;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'password_field.dart';
import 'wiki.dart';

class RevSettings extends StatefulWidget {
  static const String routeName = '/settings';
  final FlutterSecureStorage _secureStorage = new FlutterSecureStorage();
  final bool loginFailure = false;

  RevSettings({bool loginFailure = false}) : super();

  @override
  _RevSettingsState createState() => new _RevSettingsState();
}

class _RevSettingsState extends State<RevSettings> {
  static final FlutterSecureStorage _secureStorage = new FlutterSecureStorage();
  static final GlobalKey<FormState> _settingsFormKey = new GlobalKey<FormState>();
  static final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  TextEditingController usernameController, passwordController;

  static String _newUsername, _newPassword;
  static bool _snackbarState = false;

  _RevSettingsState() {
    new Async.Future(() async {
      String user = await _secureStorage.read(key: 'wikiUsername');
      String pass = await _secureStorage.read(key: 'wikiPassword');
      setState(() {
        usernameController = new TextEditingController(text: user);
        passwordController = new TextEditingController(text: pass);
      });
      if (widget.loginFailure) {
        _scaffoldKey.currentState.showSnackBar(new SnackBar(
          duration: new Duration(seconds: 10),
          content: new Text(
            'Failed to login! Please verify that your username and password are correct.',
            softWrap: true,
          ),
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      String mailtoBody = 'Beste Bestuur,\n\n'
                          'Graag zou ik een account krijgen voor de RevSpace Wiki.\n\n'
                          'Mijn nickname is: ${(_newUsername != null) ? _newUsername : ''}\n\n'
                          'Geautomatiseerde groeten,\n\n'
                          'De RevSpace App';
                      String mailtoUri = Uri.encodeFull('mailto:board@revspace.nl'
                          '?subject=Nieuw wiki account&body=$mailtoBody');
                      UrlLauncher.canLaunch(mailtoUri).then((yesWeCan) {
                        if (yesWeCan) {
                          UrlLauncher.launch(mailtoUri);
                        } else {
                          showDialog(
                            context: _scaffoldKey.currentContext,
                            builder: (context) {
                              return new AlertDialog(
                                title: const Text('Email to board'),
                                content: new Column(
                                  children: [
                                    const Text('Your phone does not have a working mail app. '
                                        'Please send the mail manually. '
                                        'You can copy the text below to get started'),
                                    new SizedBox(height: 24.0),
                                    new Text(
                                      mailtoBody,
                                      style: new TextStyle(
                                        fontSize: 12.0,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  new FlatButton(
                                    child: const Text('COPY'),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Clipboard.setData(new ClipboardData(text: mailtoBody));
                                      _scaffoldKey.currentState.showSnackBar(new SnackBar(
                                        duration: new Duration(seconds: 4),
                                        content: new Text(
                                          'The email text has been copied.',
                                          softWrap: true,
                                        ),
                                      ));
                                    },
                                  ),
                                  new FlatButton(
                                    child: const Text('OK'),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      });
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

    RevWikiTools wiki = new RevWikiTools();
    wiki.login(_newUsername, _newPassword, (success) {
      _scaffoldKey.currentState.hideCurrentSnackBar();
      if (success) {
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
  }
}
