import 'package:ble_message/BLEconnection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFocusNode = FocusNode();
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _text.dispose();
    _scrollController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _cleanEsp32Message(String msg) {
    // Remove common prefixes that ESP32 might send
    if (msg.startsWith('RX: ')) {
      return msg.substring(4);
    }
    if (msg.startsWith('OK: ')) {
      return msg.substring(4);
    }
    if (msg.startsWith('TX: ')) {
      return msg.substring(4);
    }
    return msg;
  }

  void _sendMessage(BleConnection ble) async {
    final msg = _text.text.trim();
    if (msg.isEmpty) return;
    _text.clear();
    await ble.send(msg);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final ble = Get.find<BleConnection>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Chat'),
        actions: [
          Obx(() => IconButton(
            icon: const Icon(Icons.link_off),
            onPressed: ble.isConnected.value ? ble.disconnect : null,
          )),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // STATUS
          Obx(() => Text(
            ble.status.value,
            style: const TextStyle(fontSize: 16),
          )),

          const SizedBox(height: 10),

          // SCAN BUTTON
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ElevatedButton(
              onPressed: ble.isScanning.value ? null : ble.scanDevices,
              child: Obx(() => Text(
                ble.isScanning.value ? 'Scanning...' : 'Scan',
              )),
            ),
          ),

          const Divider(),

          // DEVICES + MESSAGES
          Expanded(
            child: Obx(() {
              if (ble.isConnected.value) {
                // Auto-scroll when new messages arrive
                if (ble.messages.length != _lastMessageCount) {
                  _lastMessageCount = ble.messages.length;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });
                }
                
                // Show chat when connected
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: ble.messages.length,
                  itemBuilder: (_, i) {
                    final msg = ble.messages[i];
                    final isFromMe = msg.startsWith('ME: ');
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Align(
                        alignment: isFromMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isFromMe
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isFromMe 
                                ? msg.substring(4)  // Remove "ME: "
                                : _cleanEsp32Message(msg.substring(6)), // Remove "ESP32: " and clean the message
                            style: TextStyle(
                              color: isFromMe
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              } else {
                // Show device list when not connected
                return ListView.builder(
                  itemCount: ble.results.length,
                  itemBuilder: (context, index) {
                    final r = ble.results[index];
                    final name = r.device.platformName.isNotEmpty
                        ? r.device.platformName
                        : r.advertisementData.advName;

                    return ListTile(
                      title: Text(
                          name.isEmpty ? 'Unknown device' : name),
                      subtitle: Text(r.device.remoteId.str),
                      trailing: ElevatedButton(
                        onPressed: () => ble.connect(r),
                        child: const Text('CONNECT'),
                      ),
                    );
                  },
                );
              }
            }),
          ),

          // SEND BOX
          Obx(() => ble.isConnected.value
              ? Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    focusNode: _textFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Type message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(ble),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(ble),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          )
              : const SizedBox.shrink()),
        ],
      ),
    );
  }
}
