import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/db_helper.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  List<EvidenceRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });
    
    final records = await DatabaseHelper.instance.fetchEvidences();
    
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  Future<void> _deleteRecord(int id) async {
    await DatabaseHelper.instance.deleteEvidence(id);
    _loadRecords();
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
    } catch (e) {
      return timestamp;
    }
  }

  void _showImageDialog(String imagePath) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(File(imagePath)),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('關閉'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_records.isEmpty) {
      return const Center(
        child: Text(
          '目前沒有任何存證紀錄。',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRecords,
      child: ListView.builder(
        itemCount: _records.length,
        itemBuilder: (context, index) {
          final record = _records[index];
          
          final isPhone = record.type == 'phone';
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: isPhone
                  ? const CircleAvatar(
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.phone, color: Colors.white),
                    )
                  : GestureDetector(
                      onTap: record.imagePath != null
                          ? () => _showImageDialog(record.imagePath!)
                          : null,
                      child: CircleAvatar(
                        backgroundImage: record.imagePath != null
                            ? FileImage(File(record.imagePath!))
                            : null,
                        backgroundColor: Colors.redAccent,
                        child: record.imagePath == null
                            ? const Icon(Icons.image, color: Colors.white)
                            : null,
                      ),
                    ),
              title: Text(
                isPhone ? (record.content ?? '未知號碼') : '圖片存證',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(_formatTimestamp(record.timestamp)),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.grey),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('確認刪除'),
                      content: const Text('確定要刪除這筆存證紀錄嗎？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            if (record.id != null) {
                              _deleteRecord(record.id!);
                            }
                          },
                          child: const Text('刪除', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              onTap: isPhone ? null : (record.imagePath != null ? () => _showImageDialog(record.imagePath!) : null),
            ),
          );
        },
      ),
    );
  }
}
