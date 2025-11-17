import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../screens/common/pdf_viewer_screen.dart';

Future<void> openRemoteFile(BuildContext context, String url,
    {String title = 'Document'}) async {
  if (url.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file URL available')), 
      );
    }
    return;
  }

  try {
    final ext = url.split('.').last.toLowerCase();

    if (ext == 'pdf') {
      // In-app PDF viewer (with loader + Google Docs)
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(url: url, title: title),
        ),
      );
      return;
    }

    if (['jpg', 'jpeg', 'png'].contains(ext)) {
      // In-app image viewer
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Image')),
            body: InteractiveViewer(
              child: Image.network(url),
            ),
          ),
        ),
      );
      return;
    }

    // Other file types: download then open with open_filex
    final snack = ScaffoldMessenger.of(context);
    snack.showSnackBar(
      const SnackBar(content: Text('Downloading file...')),
    );

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      snack.showSnackBar(
        SnackBar(
          content: Text(
            'Failed to download file (HTTP ${response.statusCode})',
          ),
        ),
      );
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = url.split('/').last;
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    snack.showSnackBar(
      SnackBar(content: Text('Saved to: $fileName')), 
    );

    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      snack.showSnackBar(
        SnackBar(
          content: Text(
            'Cannot open file: install an app that supports .$ext',
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
  }
}
