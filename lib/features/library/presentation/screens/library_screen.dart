import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ilmai/features/library/data/models/library_book.dart';
import 'package:ilmai/services/firestore_service.dart';
import 'package:ilmai/services/seed_data_service.dart';
import '../../../../core/app_colors.dart';
import 'pdf_viewer_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _selectedBoard = 'BSEK';
  String _selectedClass = '9';

  final ReceivePort _port = ReceivePort();
  final Map<String, int> _downloadProgress = {};
  final Map<String, DownloadTaskStatus> _downloadStatus = {};
  final Map<String, String> _taskIdToBookId = {};
  final Map<String, String> _bookIdToTaskId = {};

  @override
  void initState() {
    super.initState();
    _bindBackgroundIsolate();
  }

  @override
  void dispose() {
    _unbindBackgroundIsolate();
    super.dispose();
  }

  void _bindBackgroundIsolate() {
    final isSuccess = IsolateNameServer.registerPortWithName(
        _port.sendPort, 'flutter_downloader_port');
    if (!isSuccess) {
      IsolateNameServer.removePortNameMapping('flutter_downloader_port');
      IsolateNameServer.registerPortWithName(
          _port.sendPort, 'flutter_downloader_port');
    }
    _port.listen((dynamic data) {
      final id = data[0] as String;
      final status = DownloadTaskStatus.fromInt(data[1] as int);
      final progress = data[2] as int;
      if (mounted) {
        setState(() {
          _downloadProgress[id] = progress;
          _downloadStatus[id] = status;
        });
        if (status == DownloadTaskStatus.complete) {
          final bookId = _taskIdToBookId[id];
          if (bookId != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Row(children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text('Book saved to Downloads/IlmAI folder!',
                    style: TextStyle(fontWeight: FontWeight.w600))),
              ]),
              backgroundColor: const Color(0xFF22C55E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ));
          }
        }
      }
    });
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('flutter_downloader_port');
  }

  Future<bool> _requestPermissions() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid) return true;
    // Android 13+ only needs notification permission
    if (await _isAndroid13OrAbove()) {
      await Permission.notification.request();
      return true;
    }
    // Android 10-12 needs storage permission
    final status = await Permission.storage.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      await _showPermissionDeniedDialog();
      return false;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Storage permission is required to download books.'),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
    return false;
  }

  Future<bool> _isAndroid13OrAbove() async {
    if (!Platform.isAndroid) return false;
    try {
      final result =
          await Process.run('getprop', ['ro.build.version.sdk']);
      final sdk = int.tryParse(result.stdout.toString().trim());
      return sdk != null && sdk >= 33;
    } catch (_) {
      return true;
    }
  }

  Future<void> _showPermissionDeniedDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.folder_off_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 10),
          Text('Permission Required'),
        ]),
        content: const Text(
            'Storage permission is permanently denied. Please enable it from App Settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadBook(LibraryBook book) async {
    final hasPermission = await _requestPermissions();
    if (!hasPermission) return;

    String downloadPath;
    if (Platform.isAndroid) {
      downloadPath = '/storage/emulated/0/Download/IlmAI';
    } else {
      downloadPath = '/storage/emulated/0/Download/IlmAI';
    }

    final savedDir = Directory(downloadPath);
    try {
      if (!await savedDir.exists()) {
        await savedDir.create(recursive: true);
      }
    } catch (_) {}

    final safeName = book.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_');

    final existingFile = File('${savedDir.path}/$safeName.pdf');
    if (await existingFile.exists()) {
      try { await existingFile.delete(); } catch (_) {}
    }

    final taskId = await FlutterDownloader.enqueue(
      url: book.pdfUrl,
      savedDir: savedDir.path,
      fileName: '$safeName.pdf',
      showNotification: true,
      openFileFromNotification: true,
    );

    if (taskId != null) {
      setState(() {
        _taskIdToBookId[taskId] = book.id;
        _bookIdToTaskId[book.id] = taskId;
        _downloadProgress[taskId] = 0;
        _downloadStatus[taskId] = DownloadTaskStatus.enqueued;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.file_download_rounded,
              color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Downloading: ${book.title}...',
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Future<void> _initializeLibrary() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.sync_rounded, color: Colors.white, size: 20),
        SizedBox(width: 10),
        Expanded(child: Text('Initializing library...')),
      ]),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
    try {
      final service = SeedDataService();
      await service.forceReseedAll();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Expanded(child: Text('Library initialized!')),
        ]),
        backgroundColor: Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Failed: $e'),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  void _viewBook(LibraryBook book) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              PdfViewerScreen(title: book.title, pdfUrl: book.pdfUrl)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final boards = ['BSEK', 'BIEK'];
    final classes =
        _selectedBoard == 'BSEK' ? ['9', '10'] : ['11', '12'];

    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Library',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.onSurface)),
                  const SizedBox(height: 6),
                  const Text('Browse textbooks by board and class.',
                      style: TextStyle(
                          color: AppColors.onSurfaceMuted, fontSize: 14)),
                ],
              ),
            ),
            Container(
              height: 48,
              margin:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4))),
              child: Row(
                children: boards.map((b) {
                  final sel = _selectedBoard == b;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedBoard = b;
                        _selectedClass = classes.first;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                            color: sel
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: Text(b,
                            style: TextStyle(
                                fontWeight: sel
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: sel
                                    ? AppColors.onSurface
                                    : AppColors.onSurfaceMuted,
                                fontSize: 14)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: classes.map((cl) {
                  final sel = _selectedClass == cl;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('Class $cl',
                          style: TextStyle(
                              color: sel
                                  ? Colors.white
                                  : AppColors.primary,
                              fontWeight: sel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13)),
                      selected: sel,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                          color: sel
                              ? AppColors.primary
                              : AppColors.primary
                                  .withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      onSelected: (v) {
                        if (v) setState(() => _selectedClass = cl);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<LibraryBook>>(
                stream: firestoreService.getLibraryBooks(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error: ${snapshot.error}'));
                  }
                  final allBooks = snapshot.data ?? [];
                  final filtered = allBooks
                      .where((b) =>
                          b.boardName == _selectedBoard &&
                          b.classId == _selectedClass)
                      .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.library_books_outlined,
                                  size: 80,
                                  color: AppColors.onSurfaceMuted
                                      .withValues(alpha: 0.4)),
                              const SizedBox(height: 20),
                              const Text('No Books Yet',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.onSurface)),
                              const SizedBox(height: 12),
                              const Text(
                                  'Textbooks will appear here once available.\nTap below to seed the library.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: AppColors.onSurfaceMuted,
                                      fontSize: 14)),
                              const SizedBox(height: 28),
                              FilledButton.icon(
                                onPressed: _initializeLibrary,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Initialize Library'),
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 14)),
                              ),
                            ]),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final book = filtered[i];
                      final taskId = _bookIdToTaskId[book.id];
                      final progress = taskId != null
                          ? (_downloadProgress[taskId] ?? 0)
                          : 0;
                      final status = taskId != null
                          ? (_downloadStatus[taskId] ??
                              DownloadTaskStatus.undefined)
                          : DownloadTaskStatus.undefined;
                      final isDownloading = status ==
                              DownloadTaskStatus.running ||
                          status == DownloadTaskStatus.enqueued;
                      final isCompleted =
                          status == DownloadTaskStatus.complete;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.primary
                                    .withValues(alpha: 0.4))),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 64,
                                height: 88,
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.08),
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  border: Border.all(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.4)),
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.menu_book_rounded,
                                        color: AppColors.primary,
                                        size: 28),
                                    const SizedBox(height: 4),
                                    Text(book.subjectId,
                                        style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow:
                                            TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(book.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: AppColors.onSurface),
                                        maxLines: 2,
                                        overflow:
                                            TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(book.subjectId,
                                        style: const TextStyle(
                                            color:
                                                AppColors.onSurfaceMuted,
                                            fontSize: 11,
                                            fontWeight:
                                                FontWeight.w500)),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        _ActionChip(
                                          icon: Icons.visibility_rounded,
                                          label: 'View',
                                          onTap: () =>
                                              _viewBook(book),
                                        ),
                                        const SizedBox(width: 8),
                                        if (isDownloading)
                                          Flexible(
                                            child: Row(children: [
                                              Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  LinearProgressIndicator(
                                                      value: progress /
                                                          100.0,
                                                      backgroundColor:
                                                          AppColors
                                                              .border,
                                                      color: AppColors
                                                          .primary,
                                                      borderRadius: BorderRadius
                                                          .circular(
                                                              10)),
                                                  const SizedBox(
                                                      height: 2),
                                                  Text('$progress%',
                                                      style: TextStyle(
                                                          fontSize: 9,
                                                          color: AppColors
                                                              .onSurfaceMuted,
                                                          fontWeight:
                                                              FontWeight
                                                                  .bold)),
                                                ]),
                                              ),
                                              const SizedBox(width: 6),
                                              const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color:
                                                        AppColors.primary,
                                                  )),
                                            ]),
                                          )
                                        else if (isCompleted)
                                          _ActionChip(
                                            icon: Icons.check_circle,
                                            label: 'Saved',
                                            color:
                                                const Color(0xFF22C55E),
                                          )
                                        else
                                          _ActionChip(
                                            icon: Icons
                                                .file_download_rounded,
                                            label: 'Download',
                                            onTap: () =>
                                                _downloadBook(book),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  const _ActionChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final c = color;
    return onTap != null
        ? Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: c.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13, color: c),
                      const SizedBox(width: 4),
                      Text(label,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: c)),
                    ]),
              ),
            ),
          )
        : Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: c.withValues(alpha: 0.4))),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: c),
                  const SizedBox(width: 4),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c)),
                ]),
          );
  }
}
