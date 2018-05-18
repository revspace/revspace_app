import 'dart:io';
import 'dart:convert';

class RevWikiTools {
  //static final Uri wikiApi = Uri.parse('https://revspace.nl/api.php');
  static final wikiAPI = Uri.parse('http://192.168.111.234/api.php');
  List<Cookie> _sessionCookies;
  HttpClient _wikiClient;
  bool _loggedIn = false;

  RevWikiTools() {
    _wikiClient = new HttpClient();
    _wikiClient.userAgent = 'RevSpaceApp (Dart ${Platform.version})';
  }

  bool login(String username, String password, Function callback(bool success)) {
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
      response.listen((data) {
        String token = json.decode(new String.fromCharCodes(data))['login']['token'];
        _wikiClient.postUrl(wikiAPI).then((HttpClientRequest request) {
          String data = 'format=json&action=login'
              '&lgname=${Uri.encodeQueryComponent(username)}'
              '&lgpassword=${Uri.encodeQueryComponent(password)}'
              '&lgtoken=${Uri.encodeQueryComponent(token)}';
          request.headers.contentType = new ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
          request.headers.contentLength = data.length;
          request.cookies.addAll(response.cookies);
          request.write(data);
          return request.close();
        }).then((HttpClientResponse response) {
          response.listen((data) {
            callback(json.decode(new String.fromCharCodes(data))['login']['result'] == 'Success');
          });
        });
      });
    });
  }
}
