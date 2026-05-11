import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/db_helper.dart';

class PhoneSearchScreen extends StatefulWidget {
  const PhoneSearchScreen({super.key});

  @override
  State<PhoneSearchScreen> createState() => _PhoneSearchScreenState();
}

class _PhoneSearchScreenState extends State<PhoneSearchScreen> {
  final _phoneController = TextEditingController();
  bool _isSearching = false;

  Future<void> _searchAndSavePhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入電話號碼')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // 1. 存證
      final record = EvidenceRecord(
        type: 'phone',
        content: phone,
        timestamp: DateTime.now().toIso8601String(),
      );
      await DatabaseHelper.instance.insertEvidence(record);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('電話號碼已自動存入清單作為證據。即將開啟搜尋...')),
        );
      }

      // 2. 搜尋
      final searchUrl = Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(phone)}');
      if (!await launchUrl(searchUrl, mode: LaunchMode.externalApplication)) {
        throw Exception('無法開啟瀏覽器搜尋');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('發生錯誤: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('電話號碼查詢'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '查詢並存證電話號碼',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '輸入懷疑惡意散布或詐騙的電話號碼。系統會將此號碼加入存證清單，並自動在 Google 搜尋此號碼是否出現在可疑的網站或論壇中。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '輸入可疑電話號碼',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 24),
            if (_isSearching)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton.icon(
                onPressed: _searchAndSavePhone,
                icon: const Icon(Icons.search),
                label: const Text('搜尋並存證'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
