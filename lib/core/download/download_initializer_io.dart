import 'dart:ui';

import 'package:flutter_downloader/flutter_downloader.dart';

Future<void> initializeDownloader({bool debug = false}) async {
  await FlutterDownloader.initialize(debug: debug);
  FlutterDownloader.registerCallback(downloadCallback);
}

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  final sendPort = IsolateNameServer.lookupPortByName('flutter_downloader_port');
  sendPort?.send([id, status, progress]);
}
