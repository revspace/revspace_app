import 'dart:io' as IO;
import 'dart:math' as Math;
import 'dart:async' as Async;
import 'dart:convert' as Convert;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as HTTP;

import 'main.dart';

class RevWikiClient extends HTTP.BaseClient {
  final HTTP.Client _inner = new HTTP.Client();
  final String ua;

  RevWikiClient(this.ua);

  Async.Future<HTTP.StreamedResponse> send(HTTP.BaseRequest request) {
    request.headers['user-agent'] = ua;
    request.headers['cookie'] = RevWikiTools.cookies;
    return _inner.send(request);
  }
}

class RevWikiTools {
  static final Uri wikiURL = Uri.parse('https://revspace.nl/api.php');

  static String cookies = ';';
  RevWikiClient _wikiClient;
  bool _loggedIn = false;
  String _userName;
  String _csrfToken;

  RevWikiTools() {
    _wikiClient = new RevWikiClient('RevSpaceApp (Dart ${IO.Platform.version})');
  }

  Async.Future<void> loginFromSecureStorage(Function callback(bool success)) async {
    final FlutterSecureStorage secureStorage = new FlutterSecureStorage();

    return login(
      await secureStorage.read(key: 'wikiUsername'),
      await secureStorage.read(key: 'wikiPassword'),
      callback,
    );
  }

  void login(String username, String password, Function callback(bool success)) {
    // FIXME: this code is written for mediawiki 1.2, it throws warnings
    // about deprecation in 1.28 and might stop working in the near future.
    // See https://www.mediawiki.org/wiki/API:Login for details

    if (!_loggedIn) {
      _wikiClient.post(wikiURL, body: {
        'format': 'json',
        'action': 'login',
        'lgname': username,
      }).then((response) {
        cookies = response.headers['set-cookie'].toString().split(';')[0];
        String token = Convert.json.decode(response.body)['login']['token'];
        _wikiClient.post(wikiURL, body: {
          'format': 'json',
          'action': 'login',
          'lgname': username,
          'lgpassword': password,
          'lgtoken': token,
        }).then((response) {
          bool success = Convert.json.decode(response.body)['login']['result'] == 'Success';
          _loggedIn = success;
          _userName = username;
          if (success) {
            _wikiClient.post(wikiURL, body: {
              'format': 'json',
              'action': 'query',
              'meta': 'tokens',
            }).then((response) {
              _csrfToken = Convert.json.decode(response.body)['query']['tokens']['csrftoken'];
            });
          }
          callback(success);
        });
      });
    }
  }

  Async.Future<List<String>> getAllProjects() async {
    if (!_loggedIn) {
      throw new WikiNotLoggedInException();
    }

    HTTP.Response response = await _wikiClient.post(wikiURL, body: {
      'format': 'json',
      'action': 'ask',
      'query': '[[Category:Project]]|sort=Project Last Update|order=desc|limit=1000',
    });
    
    return Convert.json.decode(response.body)['query']['results'].keys.toList();
  }

  void uploadImage(RevImage im, State state) async {
    const int numChunks = 42;

    String fileName = 'RevSpaceApp_IMG_'
        '${DateTime.now().toIso8601String().replaceAll('T', '_').replaceAll(':', '-')}.jpg';

    debugPrint('Uploading $im\n as $fileName');

    int chunkSize = (im.resizedJpeg.length / (numChunks - 0.5)).round();

    for (int i = 1; i < numChunks; i++) {
      List<int> chunk = im.resizedJpeg.sublist(i * chunkSize, Math.min((i + 1) * chunkSize, im.resizedJpeg.length));
      int thisChunkSize = chunk.length;

      await new Async.Future.delayed(const Duration(milliseconds: 200)); // FIXME: dummy upload code. lame!

      state.setState(() {
        im.progress = Math.min(im.progress += 0.8 / numChunks, 1.0);
      });
    }
    await new Async.Future.delayed(const Duration(milliseconds: 1000));

    debugPrint('Done! $im');
    state.setState(() {
      im.progress = 1.0;
    });
  }
}

class WikiNotLoggedInException implements Exception {
  final String msg;

  const WikiNotLoggedInException([this.msg]);

  @override
  String toString() => msg ?? 'WikiNotLoggedInException: You have to be logged in before doing this.';
}
