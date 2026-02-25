import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import '../models/product.dart';
import '../widgets/sidebar.dart';
import 'package:virtual_keyboard_multi_language/virtual_keyboard_multi_language.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({Key? key}) : super(key: key);

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  TextEditingController? _activeController;

  @override
  void initState() {
    super.initState();
    // Products are already fetched in PosProvider on login, 
    // but we can refresh them here to be safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PosProvider>(context, listen: false).fetchProducts();
    });
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

    // Products list might be filtered by category in the main screen, 
    // but here in settings/management, we want all products.
    final products = provider.products;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                const Sidebar(activePage: 'Products'),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Products', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                            if (provider.isAdmin)
                              ElevatedButton.icon(
                                onPressed: () => _showProductDialog(context),
                                icon: const Icon(Icons.add),
                                label: const Text('New Product'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF6B6B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Expanded(
                          child: provider.isLoading 
                            ? const Center(child: CircularProgressIndicator())
                            : products.isEmpty
                              ? const Center(child: Text('No products found', style: TextStyle(color: Colors.grey)))
                              : GridView.builder(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 3,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                                  itemCount: products.length,
                                  itemBuilder: (context, index) {
                                    final p = products[index];
                                    return Card(
                                      color: const Color(0xFF2A2A3C),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: ListTile(
                                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text('${p.category} | LKR ${p.price.toStringAsFixed(2)} | Stock: ${p.stockCount}'),
                                        trailing: provider.isAdmin 
                                          ? IconButton(
                                              icon: const Icon(Icons.edit, color: Color(0xFFFF6B6B)),
                                              onPressed: () => _showProductDialog(context, product: p),
                                            )
                                          : const Icon(Icons.inventory_2, color: Colors.grey),
                                      ),
                                    );
                                  },
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
                    postKeyPress: (key) => _onKeyPress(key),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showProductDialog(BuildContext context, {Product? product}) {
    final isEditing = product != null;
    
    // We assume the model 'id' is present.
    // SKU is missing from the dart model, but we need it for creation. 
    // Let's generate a random SKU if creating.
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final priceCtrl = TextEditingController(text: product != null ? product.price.toString() : '');
    final categoryCtrl = TextEditingController(text: product?.category ?? '');
    final descCtrl = TextEditingController(text: product?.description ?? '');
    final stockCtrl = TextEditingController(text: product != null ? product.stockCount.toString() : '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A3C),
          title: Text(isEditing ? 'Edit Product' : 'Add New Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField('Product Name', nameCtrl),
                const SizedBox(height: 12),
                _dialogField('Category', categoryCtrl),
                const SizedBox(height: 12),
                _dialogField('Price (LKR)', priceCtrl, isNumber: true),
                const SizedBox(height: 12),
                _dialogField('Initial Stock', stockCtrl, isNumber: true),
                const SizedBox(height: 12),
                _dialogField('Description', descCtrl),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final provider = Provider.of<PosProvider>(context, listen: false);
                
                final valPrice = double.tryParse(priceCtrl.text.trim()) ?? 0;
                final valStock = int.tryParse(stockCtrl.text.trim()) ?? 0;
                final valName = nameCtrl.text.trim();
                
                if (valName.isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Name is required'), backgroundColor: Colors.orange)
                   );
                   return;
                }

                // If creating, we must generate a SKU since backend requires it
                final sku = isEditing ? null : 'SKU-${DateTime.now().millisecondsSinceEpoch}';

                final data = {
                  'name': valName,
                  'description': descCtrl.text.trim(),
                  'price': valPrice,
                  'category': categoryCtrl.text.trim(),
                  'stock_quantity': valStock,
                };
                
                if (!isEditing) {
                  data['sku'] = sku!;
                }

                bool success;
                if (isEditing) {
                  success = await provider.updateProduct(product.id, data);
                } else {
                  success = await provider.createProduct(data);
                }

                if (success) {
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEditing ? 'Product updated' : 'Product added'))
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to save product.'), backgroundColor: Colors.red)
                    );
                  }
                }
              },
              child: const Text('Save'),
            )
          ],
        ),
      ),
    );
  }

  Widget _dialogField(String hint, TextEditingController ctrl, {bool isNumber = false}) {
    final provider = Provider.of<PosProvider>(context, listen: false);
    return TextField(
      controller: ctrl,
      readOnly: provider.useOnScreenKeyboard,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      onTap: () {
        if (provider.useOnScreenKeyboard) {
          setState(() => _activeController = ctrl);
        }
      },
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFF1E1E2C),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
