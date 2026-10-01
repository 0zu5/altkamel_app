import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';

/// Retrieves the authenticated customer's contract without putting a bearer
/// token in a URL, then lets the customer choose a visible save location.
class ContractDownloadService {
  final ApiClient apiClient;

  ContractDownloadService({required this.apiClient});

  Future<String> downloadAndOpen() async {
    final response = await apiClient.dio.get<List<int>>(
      '/contract',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('تعذر تنزيل العقد. حاول مرة أخرى.');
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/عقد_التكامل.html');
    await file.writeAsBytes(bytes, flush: true);

    final savedPath = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(sourceFilePath: file.path),
    );
    if (savedPath == null) {
      return 'تم إلغاء اختيار مكان حفظ العقد.';
    }

    final result = await OpenFilex.open(savedPath, type: 'text/html');
    if (result.type != ResultType.done) {
      return 'تم حفظ العقد في الموقع الذي اخترته.';
    }
    return 'تم حفظ العقد وفتحه. يمكنك طباعته أو حفظه كملف PDF من المتصفح.';
  }
}
