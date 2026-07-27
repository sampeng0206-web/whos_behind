import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class BillingService {
  static const String _entitlementId = 'whos-behind Pro';
  static const String _pdfSingleProductId = 'com.sampeng.whosbehind.pdf_single';
  static const String _pdfYearlyProductId = 'com.sampeng.whosbehind.pdf_yearly';

  static bool _revenueCatConfigured = false;
  static bool _isPremiumCached = false;

  static Future<void> initialize() async {
    try {
      // Configure RevenueCat logging
      await Purchases.setLogLevel(LogLevel.debug);

      if (await Purchases.isConfigured) {
        _revenueCatConfigured = true;
        // Pre-fetch active premium status
        await checkPremiumStatus();
      } else {
        _revenueCatConfigured = false;
      }
    } catch (e) {
      _revenueCatConfigured = false;
      debugPrint("RevenueCat initialization failed: $e");
    }
  }

  static Future<bool> checkPremiumStatus() async {
    if (!_revenueCatConfigured) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _isPremiumCached = customerInfo.entitlements.active.containsKey(_entitlementId);
    } catch (e) {
      debugPrint("Failed to fetch customer info from RevenueCat: $e");
    }
    return _isPremiumCached;
  }

  static Future<bool> isPremiumUser() async {
    return await checkPremiumStatus();
  }

  static Future<bool> checkGracePeriod() async {
    return false;
  }

  static Future<bool> makePurchase(String productId) async {
    if (!_revenueCatConfigured) {
      // Mock purchase in development mode
      debugPrint("Mocking purchase success for: $productId");
      _isPremiumCached = true;
      return true;
    }
    try {
      CustomerInfo customerInfo;
      if (productId == _pdfYearlyProductId) {
        final offerings = await Purchases.getOfferings();
        if (offerings.current != null && offerings.current!.annual != null) {
          final result = await Purchases.purchasePackage(offerings.current!.annual!);
          customerInfo = result.customerInfo;
        } else {
          final result = await Purchases.purchaseProduct(productId);
          customerInfo = result.customerInfo;
        }
      } else {
        // Consumable package
        final result = await Purchases.purchaseProduct(productId);
        customerInfo = result.customerInfo;
      }
      
      _isPremiumCached = customerInfo.entitlements.active.containsKey(_entitlementId);
      return true;
    } catch (e) {
      debugPrint("Purchase failed: $e");
      return false;
    }
  }

  static Future<bool> restorePurchases() async {
    if (!_revenueCatConfigured) {
      _isPremiumCached = true;
      return true;
    }
    try {
      final customerInfo = await Purchases.restorePurchases();
      _isPremiumCached = customerInfo.entitlements.active.containsKey(_entitlementId);
      return true;
    } catch (e) {
      debugPrint("Restore purchases failed: $e");
      return false;
    }
  }

  // Helper method to show Paywall Dialog
  static void showPaywallDialog(BuildContext context, VoidCallback onPurchaseSuccess) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const PaywallDialog(),
    ).then((purchased) {
      if (purchased == true) {
        onPurchaseSuccess();
      }
    });
  }
}

class PaywallDialog extends StatefulWidget {
  const PaywallDialog({super.key});

  @override
  State<PaywallDialog> createState() => _PaywallDialogState();
}

class _PaywallDialogState extends State<PaywallDialog> {
  bool _isPurchasing = false;

  Future<void> _handlePurchase(String productId) async {
    setState(() {
      _isPurchasing = true;
    });

    final success = await BillingService.makePurchase(productId);

    setState(() {
      _isPurchasing = false;
    });

    if (success) {
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('購買成功！已解鎖 PDF 產出功能。')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('購買失敗，請重試。')),
        );
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _isPurchasing = true;
    });

    final success = await BillingService.restorePurchases();

    setState(() {
      _isPurchasing = false;
    });

    if (success) {
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已恢復購買紀錄。')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無可恢復的購買紀錄。')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '產出 PDF 法律證據包\nGenerate PDF Evidence Package',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '「你有證據，才有正義」\n"Evidence is the foundation of justice"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Option 1: Consumable
                _buildProductOption(
                  id: BillingService._pdfSingleProductId,
                  titleZh: "單次產出 PDF 法律證據包",
                  titleEn: "Single PDF Evidence Export",
                  price: r"NT$190",
                  note: "適合一次性急需",
                ),
                const SizedBox(height: 16),
                
                // Option 2: Subscription
                _buildProductOption(
                  id: BillingService._pdfYearlyProductId,
                  titleZh: "年訂閱・無限產出・全功能解鎖",
                  titleEn: "Yearly Pro・Unlimited・All Features",
                  price: r"NT$499／年",
                  note: "使用3次即回本，長期保護",
                  isPopular: true,
                ),
                const SizedBox(height: 24),
                
                TextButton(
                  onPressed: _isPurchasing ? null : _handleRestore,
                  child: const Text(
                    '恢復購買 / Restore Purchases',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (_isPurchasing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.redAccent),
                ),
              ),
            ),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductOption({
    required String id,
    required String titleZh,
    required String titleEn,
    required String price,
    required String note,
    bool isPopular = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPopular ? Colors.redAccent : Colors.grey.shade800,
          width: isPopular ? 2.0 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isPurchasing ? null : () => _handlePurchase(id),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isPopular)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '最受歡迎 / POPULAR',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titleZh,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              titleEn,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        price,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• $note',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
