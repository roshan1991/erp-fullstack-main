import 'dart:io' show Process, File, Directory;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order.dart';

class ReceiptService {
  /// Enumerates ALL installed printers (local + network/shared) using
  /// PowerShell [Get-Printer], which is the modern Windows API that correctly
  /// returns network printers. Falls back to wmic if PowerShell fails.
  static Future<List<String>> listPrinters() async {
    if (kIsWeb) return [];
    // Primary: PowerShell Get-Printer (works on Windows 8+ / Server 2012+)
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NonInteractive',
          '-Command',
          r"Get-Printer | Select-Object -ExpandProperty Name",
        ],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        final printers = (result.stdout as String)
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        if (printers.isNotEmpty) return printers;
      }
    } catch (_) {}

    // Fallback: wmic (older Windows)
    try {
      final result = await Process.run(
        'wmic',
        ['printer', 'get', 'name', '/format:list'],
        runInShell: true,
      );
      return (result.stdout as String)
          .split('\n')
          .where((l) => l.trim().startsWith('Name='))
          .map((l) => l.trim().replaceFirst('Name=', '').trim())
          .where((l) => l.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }


  /// Generates a plain-text receipt from an [OrderModel].
  static String generateReceiptText(OrderModel order) {
    final now = order.date;
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}  '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final sep  = '=' * 40;
    final dash = '-' * 40;

    final buf = StringBuffer();

    // ── Header ────────────────────────────────────
    buf.writeln(sep);
    buf.writeln(_center('*** RECEIPT ***'));
    buf.writeln(_center('Ahu wears'));
    buf.writeln(_center('ElaraPOS - Retail Management'));
    buf.writeln(_center(dateStr));
    buf.writeln(_center('Order #${order.id}'));
    buf.writeln(sep);
    buf.writeln();

    // ── Items ─────────────────────────────────────
    buf.writeln(_padRow('ITEM', 'QTY', 'PRICE'));
    buf.writeln(dash);
    for (final item in order.items) {
      final name = item.product.name.length > 20
          ? item.product.name.substring(0, 20)
          : item.product.name;
      final qty   = 'x${item.quantity}';
      final price = 'LKR ${item.totalPrice.toStringAsFixed(2)}';
      buf.writeln(_padRow(name, qty, price));
    }
    buf.writeln(dash);
    buf.writeln();

    // ── Totals ────────────────────────────────────
    buf.writeln(_alignRight('Sub Total:', 'LKR ${order.subtotal.toStringAsFixed(2)}'));
    if (order.discount > 0) {
      buf.writeln(_alignRight('Discount:', '-LKR ${order.discount.toStringAsFixed(2)}'));
    }
    buf.writeln(dash);
    buf.writeln(_alignRight('TOTAL:', 'LKR ${order.total.toStringAsFixed(2)}'));
    buf.writeln(dash);
    buf.writeln(_alignRight('Payment:', order.paymentMethod));
    buf.writeln();

    // ── Footer ────────────────────────────────────
    buf.writeln(sep);
    buf.writeln(_center('Thank you for your purchase!'));
    buf.writeln(_center('Please come again'));
    buf.writeln(sep);
    buf.writeln();
    buf.writeln(); // extra feed for cutter

    return buf.toString();
  }

  /// Generates a PDF receipt from an [OrderModel].
  static Future<Uint8List> generateReceiptPdf(OrderModel order) async {
    final pdf = pw.Document();

    // Attempt to load logo
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/image/ahu_logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    final now = order.date;
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}  '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Standard receipt width
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null) ...[
                  pw.Center(child: pw.Image(logoImage, width: 60, height: 60)),
                  pw.SizedBox(height: 10),
                ],
                pw.Text('*** RECEIPT ***', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.SizedBox(height: 4),
                pw.Text('Ahu wears', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.Text('427A/1 Main Street, Maruthamunai, Srilanka', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('ElaraPOS - Retail Management', style: const pw.TextStyle(fontSize: 10)),
                pw.Text(dateStr, style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Order #${order.id}', style: const pw.TextStyle(fontSize: 10)),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 8),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text('ITEM', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Text('QTY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.SizedBox(width: 10),
                    pw.Text('PRICE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ],
                ),
                pw.Divider(thickness: 0.5),

                ...order.items.map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(item.product.name, style: const pw.TextStyle(fontSize: 10)),
                              if (item.product.size != null && item.product.size != 'null')
                                pw.Text('Size: ${item.product.size}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                        pw.Text('x${item.quantity}', style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(width: 10),
                        pw.Text('LKR ${item.totalPrice.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  );
                }).toList(),

                pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 8),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Sub Total:', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('LKR ${order.subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                if (order.discount > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Discount:', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('-LKR ${order.discount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                pw.Divider(thickness: 1),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.Text('LKR ${order.total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  ],
                ),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Payment:', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(order.paymentMethod, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),

                pw.SizedBox(height: 20),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                pw.Text('Thank you for your purchase!', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Returns within 14 days with receipt', style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                pw.Text('Please come again', style: const pw.TextStyle(fontSize: 10)),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Shows a print preview dialog for the given [order].
  static Future<void> showPrintPreview(dynamic context, OrderModel order) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => await generateReceiptPdf(order),
      name: 'Receipt_${order.id}',
    );
  }

  /// Prints [order] to the Windows/network printer named [printerName].
  ///
  /// Uses PowerShell `Out-Printer` which works for any printer installed in
  /// Windows (local USB, Bluetooth, or network shared printers).
  ///
  /// Returns `null` on success, or an error string on failure.
  static Future<String?> printReceipt(
      OrderModel order, String printerName) async {
    if (kIsWeb) return 'Printing is not supported in the browser version.';
    final receiptText = generateReceiptText(order);

    // Write to a temp file
    final tmpDir  = Directory.systemTemp;
    final tmpFile = File('${tmpDir.path}\\pos_receipt_${DateTime.now().millisecondsSinceEpoch}.txt');
    await tmpFile.writeAsString(receiptText);

    try {
      // PowerShell Out-Printer works for local AND network printers.
      // -Name accepts the exact printer name from wmic/print management.
      final safeFile    = tmpFile.path.replaceAll("'", "''");
      final safePrinter = printerName.replaceAll("'", "''");

      final result = await Process.run(
        'powershell',
        [
          '-NonInteractive',
          '-Command',
          "Get-Content -Raw '$safeFile' | Out-Printer -Name '$safePrinter'",
        ],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        final err = (result.stderr as String).trim();
        return err.isEmpty ? 'Print failed (exit ${result.exitCode})' : err;
      }
      return null; // success
    } catch (e) {
      return 'Print error: $e';
    } finally {
      // Clean up temp file (best effort)
      try {
        await tmpFile.delete();
      } catch (_) {}
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _center(String text, {int width = 40}) {
    if (text.length >= width) return text;
    final pad = (width - text.length) ~/ 2;
    return ' ' * pad + text;
  }

  static String _padRow(String left, String mid, String right,
      {int width = 40}) {
    // left ≤ 22 chars, mid ≤ 4, right fills rest
    final l = left.padRight(22).substring(0, 22);
    final m = mid.padLeft(4);
    final r = right.padLeft(width - 22 - 4);
    return '$l$m$r';
  }

  static String _alignRight(String label, String value, {int width = 40}) {
    final total = label.length + value.length;
    if (total >= width) return '$label $value';
    return label + ' ' * (width - total) + value;
  }
}

