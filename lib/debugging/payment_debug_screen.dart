// lib/debugging/payment_debug_screen.dart
// Debug screen to test payment functionality and verify SDK is working
import 'package:flutter/material.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';

class PaymentDebugScreen extends StatefulWidget {
  const PaymentDebugScreen({super.key});

  @override
  State<PaymentDebugScreen> createState() => _PaymentDebugScreenState();
}

class _PaymentDebugScreenState extends State<PaymentDebugScreen> {
  final _identifierController = TextEditingController();
  final _amountController = TextEditingController(text: '1000');
  String _statusText = 'Checking SDK status...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final status = await BreezSparkService.getInitializationStatus();
      setState(() {
        _statusText = '''
SDK Status:
- Initialized: ${status['isInitialized'] ? '✅ YES' : '❌ NO'}
- Exists: ${status['sdkExists'] ? '✅ YES' : '❌ NO'}

${status.containsKey('nodeInfo') ? '''
Node Info:
- ID: ${(status['nodeInfo'] as Map)['nodeId']}
- Balance: ${(status['nodeInfo'] as Map)['balanceSats']} sats
- Channel Balance: ${(status['nodeInfo'] as Map)['channelsBalanceMsat']} msat
- Can Send: ${status['canSend'] ? '✅ YES' : '❌ NO'}
- Can Receive: ${status['canReceive'] ? '✅ YES' : '❌ NO'}

Max Sendable: ${(status['nodeInfo'] as Map)['maxPayableAmountSat']} sats
Max Receivable: ${(status['nodeInfo'] as Map)['maxReceivableAmountSat']} sats
''' : '❌ No node info available'}

${status.containsKey('error') ? 'ERROR: ${status['error']}' : ''}

Timestamp: ${status['timestamp']}
''';
      });
    } catch (e) {
      setState(() {
        _statusText = '❌ Error checking status:\n$e';
      });
    }
  }

  Future<void> _testReceive() async {
    setState(() => _isLoading = true);
    try {
      final amount = int.parse(_amountController.text);
      final response = await BreezSparkService.createInvoice(amount, 'Debug receive');
      setState(() {
        _statusText = '''
✅ Invoice Created Successfully!

Payment Request:
${response.paymentRequest}

Memo: Debug receive
Amount: $amount sats
''';
      });
    } catch (e) {
      setState(() {
        _statusText = '❌ Receive failed:\n$e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testSend() async {
    if (_identifierController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter payment identifier')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final amount = int.parse(_amountController.text);
      final response = await BreezSparkService.sendPayment(
        _identifierController.text,
        sats: amount,
      );
      setState(() {
        _statusText = '''
✅ Payment Sent Successfully!

Payment ID: ${response.payment.id}
Amount: ${BreezSparkService.extractSendAmountSats(response)} sats
Fee: ${BreezSparkService.extractSendFeeSats(response)} sats
''';
      });
    } catch (e) {
      setState(() {
        _statusText = '❌ Send failed:\n$e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Debug'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SDK Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _checkStatus,
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusText,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Test Receive
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Receive Payment',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount (sats)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testReceive,
                      icon: const Icon(Icons.call_received),
                      label: const Text('Create Invoice'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Test Send
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Send Payment',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _identifierController,
                      decoration: const InputDecoration(
                        labelText: 'Payment Identifier (invoice/address/LNURL)',
                        hintText: 'lnbc... or bc1... or user@domain.com',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount (sats)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        _amountController.text = val;
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testSend,
                      icon: const Icon(Icons.send),
                      label: const Text('Send Payment'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debug Instructions:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Check if "Initialized: ✅ YES" and channels > 0\n'
                    '2. If SDK not initialized, check app startup logs\n'
                    '3. If initialized but channels = 0, bootstrap didn\'t work\n'
                    '4. If channels > 0, try "Create Invoice" to test receive\n'
                    '5. Paste invoice to another wallet to test sending\n'
                    '6. Use "Send Payment" to test outbound (needs valid invoice)',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
