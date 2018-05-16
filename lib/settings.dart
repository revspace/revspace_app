import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'password_field.dart';

class SettingsScaffoldFactory {
  final FlutterSecureStorage secureStorage = new FlutterSecureStorage();

  static Scaffold settingsScaffold() => new Scaffold(
        appBar: new AppBar(
          title: new Text('RevSpace Settings'),
        ),
        body: new SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: new Form(
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
                  print('Name: $value');
                },
              ),
              const SizedBox(height: 24.0),
              new PasswordField(
                hintText: 'RevSpace Wiki password',
                labelText: 'Password',
                onSaved: (String value) {
                  print('Password: $value');
                },
              ),
              const SizedBox(height: 24.0),
            ]),
            onChanged: () {
              print('form changed');
            },
          ),
        ),
      );
}
