import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import '../widgets/sidebar.dart';
import 'package:virtual_keyboard_multi_language/virtual_keyboard_multi_language.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;
  TextEditingController? _activeController;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<PosProvider>(context, listen: false);
    _urlController = TextEditingController(text: provider.serverUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _onKeyPress(VirtualKeyboardKey key) {
    if (_activeController == null) return;
    
    if (key.keyType == VirtualKeyboardKeyType.String) {
      _activeController!.text += key.text!;
    } else if (key.keyType == VirtualKeyboardKeyType.Action) {
      switch (key.action) {
        case VirtualKeyboardKeyAction.Backspace:
          if (_activeController!.text.isNotEmpty) {
            _activeController!.text = _activeController!.text
                .substring(0, _activeController!.text.length - 1);
          }
          break;
        case VirtualKeyboardKeyAction.Return:
          _activeController!.text += '\n';
          break;
        case VirtualKeyboardKeyAction.Space:
          _activeController!.text += ' ';
          break;
        default:
      }
    }
    _activeController!.selection = TextSelection.fromPosition(
        TextPosition(offset: _activeController!.text.length));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                const Sidebar(activePage: 'Settings'),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Settings',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 32),
                        
                        // Keyboard Setting
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A3C),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'On-Screen Keyboard',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Show a virtual keyboard when tapping text fields',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                              Switch(
                                value: provider.useOnScreenKeyboard,
                                onChanged: (value) => provider.setUseOnScreenKeyboard(value),
                                activeColor: const Color(0xFFFF6B6B),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),

                        // Server URL Setting (Admin Only)
                        if (provider.isAdmin)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A3C),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Server Configuration',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _urlController,
                                  readOnly: provider.useOnScreenKeyboard,
                                  onTap: () {
                                    if (provider.useOnScreenKeyboard) {
                                      setState(() => _activeController = _urlController);
                                    }
                                  },
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'API Base URL',
                                    hintText: 'http://localhost:3000/api/v1',
                                    filled: true,
                                    fillColor: const Color(0xFF1E1E2C),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    provider.updateServerUrl(_urlController.text.trim());
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('✅ Server URL updated successfully!')),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6B6B),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Save URL'),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 32),
                        
                        // Logout Button
                        SizedBox(
                          width: 200,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              provider.logout();
                              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                            },
                            icon: const Icon(Icons.logout),
                            label: const Text('Logout'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.1),
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (provider.useOnScreenKeyboard && _activeController != null)
            Container(
              color: const Color(0xFF1A1A28),
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => setState(() => _activeController = null),
                      ),
                    ],
                  ),
                  VirtualKeyboard(
                    height: 250,
                    textColor: Colors.white,
                    fontSize: 20,
                    type: VirtualKeyboardType.Alphanumeric,
                    postKeyPress: _onKeyPress,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
