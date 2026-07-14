import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/app_colors.dart';

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final String pdfUrl;

  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.pdfUrl,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _errorMessage;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _fetchPdf();
  }

  Future<void> _fetchPdf() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(widget.pdfUrl));
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>([], (p, e) => p..addAll(e));
        if (mounted) setState(() { _pdfBytes = Uint8List.fromList(bytes); _isLoading = false; });
      } else {
        throw HttpException('Failed to load PDF (Status: ${response.statusCode})');
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  Future<bool> _requestPermissions() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid) return true;
    try {
      final result = await Process.run('getprop', ['ro.build.version.sdk']);
      final sdk = int.tryParse(result.stdout.toString().trim());
      if (sdk != null && sdk >= 33) {
        await Permission.notification.request();
        return true;
      }
    } catch (_) {}
    final status = await Permission.storage.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Permission Required'),
          content: const Text('Storage permission is permanently denied.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); openAppSettings(); },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return false;
    }
    return false;
  }

  Future<String> _saveToDownloads(Uint8List bytes) async {
    String dirPath;
    if (Platform.isAndroid) {
      dirPath = '/storage/emulated/0/Download/IlmAI';
    } else {
      dirPath = '/storage/emulated/0/Download/IlmAI';
    }
    final dir = Directory(dirPath);
    if (!await dir.exists()) await dir.create(recursive: true);

    final safeName = widget.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    var file = File('${dir.path}/$safeName.pdf');

    var counter = 1;
    while (await file.exists()) {
      file = File('${dir.path}/${safeName}_$counter.pdf');
      counter++;
    }

    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> _downloadAll() async {
    if (_pdfBytes == null) return;
    final ok = await _requestPermissions();
    if (!ok) return;
    try {
      await _saveToDownloads(_pdfBytes!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('Saved to Downloads/IlmAI folder', style: TextStyle(fontWeight: FontWeight.w600))),
          ]),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  void _showPageSelector() {
    if (_totalPages == 0) _totalPages = 50;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PageSelector(
        totalPages: _totalPages,
        onDownload: (selected) async {
          Navigator.pop(ctx);
          if (selected.isEmpty || _pdfBytes == null) return;
          final ok = await _requestPermissions();
          if (!ok) return;
          try {
            await _saveToDownloads(_pdfBytes!);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Row(children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Saved to Downloads/IlmAI folder', style: TextStyle(fontWeight: FontWeight.w600))),
                ]),
                backgroundColor: const Color(0xFF22C55E),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Download failed: $e'),
                backgroundColor: Colors.red[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ));
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        elevation: 0, backgroundColor: Colors.white, centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_pdfBytes != null && !_isLoading) ...[
            IconButton(
              icon: const Icon(Icons.select_all_rounded, size: 22),
              onPressed: _totalPages > 0 ? _showPageSelector : null,
              tooltip: 'Select pages',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 22),
              onSelected: (v) {
                if (v == 'download_all') _downloadAll();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'download_all',
                  child: ListTile(
                    leading: Icon(Icons.file_download_rounded),
                    title: Text('Download PDF'),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('Loading PDF...', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
            ]))
          : _errorMessage != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.error_outline_rounded, color: Colors.red[400], size: 64),
                  const SizedBox(height: 16),
                  const Text('Failed to load PDF', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(onPressed: _fetchPdf, icon: const Icon(Icons.refresh_rounded), label: const Text('Try Again'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
                ])))
              : PdfPreview(
                  build: (format) => _pdfBytes!,
                  allowPrinting: false,
                  allowSharing: true,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  dynamicLayout: false,
                  maxPageWidth: 700,
                  pdfPreviewPageDecoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))]),
                ),
    );
  }
}

class _PageSelector extends StatefulWidget {
  final int totalPages;
  final void Function(Set<int> selected) onDownload;

  const _PageSelector({required this.totalPages, required this.onDownload});

  @override
  State<_PageSelector> createState() => _PageSelectorState();
}

class _PageSelectorState extends State<_PageSelector> {
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    final pages = widget.totalPages > 0
        ? List.generate(widget.totalPages, (i) => i + 1)
        : List.generate(10, (i) => i + 1);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Text('Select Pages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                const Spacer(),
                Text('${_selected.length} selected', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.onSurfaceMuted)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _selected.addAll(pages)),
                  icon: const Icon(Icons.select_all_rounded, size: 18),
                  label: const Text('Select All', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _selected.clear()),
                  icon: const Icon(Icons.deselect_rounded, size: 18),
                  label: const Text('Clear', style: TextStyle(fontSize: 13)),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _selected.isNotEmpty ? () => widget.onDownload(Set.from(_selected)) : null,
                  icon: const Icon(Icons.file_download_rounded, size: 16),
                  label: Text('Download (${_selected.length})', style: const TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                controller: scrollCtrl,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.8,
                ),
                itemCount: pages.length,
                itemBuilder: (_, i) {
                  final page = pages[i];
                  final sel = _selected.contains(page);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (sel) { _selected.remove(page); } else { _selected.add(page); }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 1.5 : 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            sel ? Icons.check_circle_rounded : Icons.circle_outlined,
                            size: 20,
                            color: sel ? Colors.white : AppColors.onSurfaceMuted,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$page',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: sel ? Colors.white : AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
