import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';

/// Retrieves the authenticated customer's contract without putting a bearer
/// token in a URL, then hands the downloaded document to the device viewer.
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

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/عقد_التكامل.html');
    await file.writeAsBytes(bytes, flush: true);

    final result = await OpenFilex.open(file.path, type: 'text/html');
    if (result.type != ResultType.done) {
      throw Exception('تم تنزيل العقد، لكن تعذر فتحه تلقائياً.');
    }
    return 'تم تنزيل العقد وفتحه. يمكنك طباعته أو حفظه كملف PDF من المتصفح.';
  }
}
