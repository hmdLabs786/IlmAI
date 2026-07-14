import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/library_document.dart';

class DocumentDownloadController extends ChangeNotifier {
  final FirebaseFirestore _db;
  final Map<String, int> _progressByTaskId = {};
  final Map<String, DownloadTaskStatus> _statusByTaskId = {};
  final Map<String, String> _localPathByDocId = {};
  final Map<String, LibraryDocument> _documentByTaskId = {};

  ReceivePort? _receivePort;
  StreamSubscription? _subscription;

  DocumentDownloadController({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance {
    _bindBackgroundIsolate();
  }

  int progressFor(String taskId) => _progressByTaskId[taskId] ?? 0;
  DownloadTaskStatus statusFor(String taskId) =>
      _statusByTaskId[taskId] ?? DownloadTaskStatus.undefined;
  String? localPathFor(String docId) => _localPathByDocId[docId];

  Future<String> downloadAndTrack(LibraryDocument document) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeName = document.title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final savedDir = Directory(
      '${directory.path}${Platform.pathSeparator}ilmai${Platform.pathSeparator}${document.boardName}${Platform.pathSeparator}${document.classId}${Platform.pathSeparator}${document.subjectId}',
    );
    if (!await savedDir.exists()) {
      await savedDir.create(recursive: true);
    }

    final taskId = await FlutterDownloader.enqueue(
      url: document.fileUrl,
      savedDir: savedDir.path,
      fileName: '$safeName.pdf',
      showNotification: true,
      openFileFromNotification: false,
    );

    if (taskId != null) {
      _documentByTaskId[taskId] = document;
      _localPathByDocId[document.id] = '${savedDir.path}${Platform.pathSeparator}$safeName.pdf';
      notifyListeners();
    }

    return taskId ?? '';
  }

  Future<void> markAvailableOffline({
    required LibraryDocument document,
    required String localPath,
  }) async {
    await _db.doc(document.firestorePath).set({
      'localPath': localPath,
      'downloadState': 'Available Offline',
      'downloadedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _localPathByDocId[document.id] = localPath;
    notifyListeners();
  }

  void _bindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('flutter_downloader_port');
    _receivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(
      _receivePort!.sendPort,
      'flutter_downloader_port',
    );
    _subscription = _receivePort!.listen((dynamic data) {
      final taskId = data[0] as String;
      final status = DownloadTaskStatus.fromInt(data[1] as int);
      final progress = data[2] as int;
      _statusByTaskId[taskId] = status;
      _progressByTaskId[taskId] = progress;
      notifyListeners();

      if (status == DownloadTaskStatus.complete) {
        debugPrint('Available Offline');
        final document = _documentByTaskId[taskId];
        final localPath = document == null ? null : _localPathByDocId[document.id];
        if (document != null && localPath != null) {
          markAvailableOffline(document: document, localPath: localPath);
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _receivePort?.close();
    IsolateNameServer.removePortNameMapping('flutter_downloader_port');
    super.dispose();
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final send = IsolateNameServer.lookupPortByName('flutter_downloader_port');
    send?.send([id, status, progress]);
  }
}
