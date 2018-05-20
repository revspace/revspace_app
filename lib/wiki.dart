import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RevWikiTools {
  static final Uri wikiAPI = Uri.parse('https://revspace.nl/api.php');

  List<Cookie> _sessionCookies;
  HttpClient _wikiClient;
  bool _loggedIn = false;
  String _userName;

  RevWikiTools() {
    _wikiClient = new HttpClient();
    _wikiClient.userAgent = 'RevSpaceApp (Dart ${Platform.version})';
  }

  Future<void> loginFromSecureStorage(Function callback(bool success)) async {
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

    _wikiClient.postUrl(wikiAPI).then((HttpClientRequest request) {
      String data = 'format=json&action=login'
          '&lgname=${Uri.encodeQueryComponent(username)}';
      request.headers.contentType = new ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      request.headers.contentLength = data.length;
      request.write(data);
      return request.close();
    }).then((HttpClientResponse response) {
      _sessionCookies = response.cookies;
      response.listen((data) {
        String token = json.decode(new String.fromCharCodes(data))['login']['token'];
        _wikiClient.postUrl(wikiAPI).then((HttpClientRequest request) {
          String data = 'format=json&action=login'
              '&lgname=${Uri.encodeQueryComponent(username)}'
              '&lgpassword=${Uri.encodeQueryComponent(password)}'
              '&lgtoken=${Uri.encodeQueryComponent(token)}';
          request.headers.contentType = new ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
          request.headers.contentLength = data.length;
          request.cookies.addAll(_sessionCookies);
          request.write(data);
          return request.close();
        }).then((HttpClientResponse response) {
          response.listen((data) {
            bool success = json.decode(new String.fromCharCodes(data))['login']['result'] == 'Success';
            _loggedIn = success;
            _userName = username;
            callback(success);
          });
        });
      });
    });
  }

  Future<List<String>> getAllProjects() async {
    if(!_loggedIn) {
      throw new WikiNotLoggedInException();
    }

    HttpClientRequest request = await _wikiClient.postUrl(wikiAPI);

    String data = 'format=json&action=ask&query=${Uri.encodeQueryComponent(
        '[[Category:Project]]|sort=Project Last Update|order=desc|limit=1000')}';

    request.headers.contentType = new ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    request.headers.contentLength = data.length;
    request.cookies.addAll(_sessionCookies);
    request.write(data);

    HttpClientResponse response = await request.close();

    Map body = json.decode(new String.fromCharCodes((await response.toList()).expand((x) => x).toList()));
    Map results = body['query']['results'];

    return results.keys.toList();
  }
}

class WikiNotLoggedInException implements Exception {
  final String msg;

  const WikiNotLoggedInException([this.msg]);

  @override
  String toString() => msg ?? 'WikiNotLoggedInException: You have to be logged in before doing this.';
}