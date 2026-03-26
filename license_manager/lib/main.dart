import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'generator_service.dart';

void main() {
  runApp(const LicenseGeneratorApp());
}

class LicenseGeneratorApp extends StatelessWidget {
  const LicenseGeneratorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ahu ERP License Generator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E), // Deep midnight blue
        primaryColor: const Color(0xFF00A8FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00A8FF),
          onPrimary: Colors.white,
          secondary: Color(0xFF673AB7), // Purple/Deep blue accent
          surface: Color(0xFF242445), // Slightly lighter blue for cards
        ),
        cardTheme: CardThemeData(
           color: const Color(0xFF242445),
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           elevation: 8,
        ),
        textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const GeneratorScreen(),
    );
  }
}

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({Key? key}) : super(key: key);

  @override
  _GeneratorScreenState createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _resultController = TextEditingController();
  
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  bool _isAnyDevice = false;

  void _generate() {
    String deviceId = _isAnyDevice ? "ANY" : _deviceIdController.text.trim();
    if (deviceId.isEmpty && !_isAnyDevice) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text("Please enter a Machine ID or check 'Universal Key'")),
       );
       return;
    }

    final key = GeneratorService.generateKey(
      deviceId: deviceId,
      expiry: _expiryDate,
      licensedTo: _customerController.text.isNotEmpty ? _customerController.text : null,
    );

    setState(() {
      _resultController.text = key;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: const Color(0xFF242445),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar branding
          Container(
            width: 300,
            color: const Color(0xFF0F0F23),
            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(Icons.security_rounded, size: 40, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: 30),
                Text(
                  "License\nGenerator",
                  style: GoogleFonts.outfit(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Generate secure, encrypted product keys for Ahu ERP clients.",
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  "© 2026 Admin Panel",
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                ),
              ],
            ),
          ),
          
          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(60.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Create New Product Key",
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 40),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left form
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputField(
                                label: "Target Customer Name",
                                controller: _customerController,
                                icon: Icons.person_rounded,
                                hint: "e.g., Al-Mulla Supermarket",
                              ),
                              const SizedBox(height: 25),
                              
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInputField(
                                      label: "Target Machine ID",
                                      controller: _deviceIdController,
                                      icon: Icons.laptop_mac_rounded,
                                      hint: "Paste the ID from client app",
                                      enabled: !_isAnyDevice,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 25),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: _isAnyDevice,
                                          onChanged: (v) => setState(() => _isAnyDevice = v!),
                                          activeColor: Theme.of(context).primaryColor,
                                        ),
                                        const Text("Universal Key"),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 25),
                              
                              Text("License Valid Until", style: TextStyle(color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 20, color: Colors.blueAccent),
                                      const SizedBox(width: 15),
                                      Text(
                                        DateFormat('MMMM dd, yyyy').format(_expiryDate),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 40),
                        
                        // Right result area
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 150), // alignment padding
                              ElevatedButton(
                                onPressed: _generate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 55),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text("GENERATE KEY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 30),
                    
                    // Result area
                    Text("Encrypted Product Key", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _resultController,
                      readOnly: true,
                      maxLines: 4,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded, color: Colors.blueAccent),
                          onPressed: () {
                            if (_resultController.text.isNotEmpty) {
                              Clipboard.setData(ClipboardData(text: _resultController.text));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Key copied!")));
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label, 
    required TextEditingController controller, 
    required IconData icon, 
    String? hint,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(color: enabled ? Colors.white : Colors.white24),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white10),
            prefixIcon: Icon(icon, color: Colors.white38),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueAccent)),
          ),
        ),
      ],
    );
  }
}
