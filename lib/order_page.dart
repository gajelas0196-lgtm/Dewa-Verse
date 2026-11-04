import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'api_config.dart';

// ─── Warna Tema (samakan dengan dashboard_page.dart) ──────────────────
const Color kBgRole      = Color(0xFF0B0C10);
const Color kCardRole    = Color(0xFF121420);
const Color kBorderRole  = Color(0xFF3A2E5C);
const Color kCyanRole    = Color(0xFF66FCF1);
const Color kGreenRole   = Color(0xFF00E676);
const Color kOrangeRole  = Color(0xFFFF9F00);
const Color kWhiteRole   = Colors.white;
const Color kWhite54Role = Colors.white54;

class BuyRolePage extends StatefulWidget {
  final String sessionKey;
  const BuyRolePage({super.key, required this.sessionKey});

  @override
  State<BuyRolePage> createState() => _BuyRolePageState();
}

class _BuyRolePageState extends State<BuyRolePage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  String _selectedRole = 'reseller';
  String? _invoiceId;
  String? _qrString;
  int? _amount;
  bool _isPaid = false;
  bool _isLoading = false;
  bool _isCreatingOrder = false;
  Timer? _pollTimer;

  final Map<String, int> _prices = {
    'member': 50000,
    'reseller': 250000,
    'owner': 500000,
  };

  final Map<String, Color> _roleColors = {
    'member': kCyanRole,
    'reseller': kGreenRole,
    'owner': kOrangeRole,
  };

  @override
  void dispose() {
    _pollTimer?.cancel();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _createOrder() async {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      _showSnack('Username dan password wajib diisi', Colors.redAccent);
      return;
    }

    setState(() => _isCreatingOrder = true);

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/order/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'role': _selectedRole,
          'username': user,
          'password': pass,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);

      if (data['success'] == true) {
        setState(() {
          _invoiceId = data['invoice_id'];
          _qrString  = data['qr_string'];
          _amount    = data['amount'];
          _isPaid    = false;
        });
        _startPolling();
      } else {
        _showSnack(data['error'] ?? 'Gagal membuat order', Colors.redAccent);
      }
    } catch (e) {
      _showSnack('Koneksi gagal: $e', Colors.redAccent);
    } finally {
      setState(() => _isCreatingOrder = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_invoiceId == null || _isPaid) return;

      try {
        final res = await http.get(
          Uri.parse('$baseUrl/api/order/status/$_invoiceId'),
        );
        final data = jsonDecode(res.body);

        if (data['status'] == 'paid' && !_isPaid) {
          _pollTimer?.cancel();
          setState(() => _isPaid = true);
          await Future.delayed(const Duration(milliseconds: 800));
          await _completeOrder();
        }
      } catch (_) {}
    });
  }

  Future<void> _completeOrder() async {
    setState(() => _isLoading = true);

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/order/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'invoice_id': _invoiceId,
          'username': _userCtrl.text.trim(),
          'password': _passCtrl.text.trim(),
          'role': _selectedRole,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);

      if (data['success'] == true) {
        _showSuccessDialog(data);
      } else {
        _showSnack(data['error'] ?? 'Gagal membuat akun', Colors.redAccent);
      }
    } catch (e) {
      _showSnack('Koneksi gagal: $e', Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(Map data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kCardRole,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kGreenRole.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(color: kGreenRole.withOpacity(0.2), blurRadius: 30, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kGreenRole.withOpacity(0.15),
                  border: Border.all(color: kGreenRole, width: 2),
                ),
                child: const Icon(Icons.check_rounded, color: kGreenRole, size: 36),
              ),
              const SizedBox(height: 16),
              const Text('PEMBAYARAN BERHASIL',
                  style: TextStyle(
                    color: kWhiteRole, fontSize: 16, fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron', letterSpacing: 1)),
              const SizedBox(height: 20),
              _buildInfoRow('Username', data['username'] ?? '-'),
              _buildInfoRow('Password', data['password'] ?? '-'),
              _buildInfoRow('Role', (data['role'] ?? '-').toString().toUpperCase()),
              _buildInfoRow('UID', data['uid'] ?? '-'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreenRole,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SELESAI',
                      style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron', letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: kWhite54Role, fontSize: 12)),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: kBgRole,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorderRole.withOpacity(0.5)),
              ),
              child: Text(value,
                  style: const TextStyle(
                    color: kWhiteRole, fontSize: 12,
                    fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgRole,
      appBar: AppBar(
        backgroundColor: kBgRole,
        elevation: 0,
        iconTheme: const IconThemeData(color: kWhiteRole),
        title: const Text('BELI ROLE',
            style: TextStyle(
              color: kWhiteRole, fontSize: 16, fontWeight: FontWeight.bold,
              fontFamily: 'Orbitron', letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _invoiceId == null ? _buildOrderForm() : _buildPaymentView(),
      ),
    );
  }

  Widget _buildOrderForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        const Text('Pilih Role', style: TextStyle(color: kWhiteRole, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        ..._prices.keys.map((role) => _buildRoleOption(role)).toList(),
        const SizedBox(height: 20),
        const Text('Data Akun Baru',
            style: TextStyle(color: kWhiteRole, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        _buildInput('Username', _userCtrl, Icons.person_outline_rounded),
        const SizedBox(height: 12),
        _buildInput('Password', _passCtrl, Icons.lock_outline_rounded, obscure: true),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isCreatingOrder ? null : _createOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: _roleColors[_selectedRole],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 6,
            ),
            child: _isCreatingOrder
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                : Text(
                    'BELI ${_selectedRole.toUpperCase()} • Rp ${_prices[_selectedRole]!.toString()}',
                    style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold,
                      fontFamily: 'Orbitron', fontSize: 13, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [kCyanRole.withOpacity(0.15), kBgRole],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: Border.all(color: kCyanRole.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kCyanRole.withOpacity(0.15),
              border: Border.all(color: kCyanRole, width: 2),
            ),
            child: const Icon(Icons.shopping_cart_rounded, color: kCyanRole, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Upgrade Role Kamu',
                    style: TextStyle(
                      color: kWhiteRole, fontWeight: FontWeight.bold, fontSize: 15,
                      fontFamily: 'Orbitron')),
                SizedBox(height: 4),
                Text('Bayar via QRIS, otomatis aktif',
                    style: TextStyle(color: kWhite54Role, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleOption(String role) {
    final isSelected = _selectedRole == role;
    final color = _roleColors[role]!;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? color.withOpacity(0.1) : kCardRole,
          border: Border.all(
            color: isSelected ? color : kBorderRole.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 16, spreadRadius: 1)]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
                border: Border.all(color: color.withOpacity(0.6)),
              ),
              child: Icon(_roleIcon(role), color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? color : kWhiteRole,
                        fontWeight: FontWeight.bold, fontSize: 14,
                        fontFamily: 'Orbitron', letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(_roleDesc(role),
                      style: const TextStyle(color: kWhite54Role, fontSize: 11)),
                ],
              ),
            ),
            Text('Rp ${_prices[role]}',
                style: TextStyle(
                  color: isSelected ? color : kWhiteRole,
                  fontWeight: FontWeight.bold, fontSize: 13,
                  fontFamily: 'Orbitron')),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? color : kWhite54Role,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'owner':    return Icons.workspace_premium_rounded;
      case 'reseller': return Icons.storefront_rounded;
      default:         return Icons.person_rounded;
    }
  }

  String _roleDesc(String role) {
    switch (role) {
      case 'owner':    return 'Akses penuh + kelola semua user';
      case 'reseller': return 'Bisa jual & kelola akun member';
      default:         return 'Akses dasar member';
    }
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon,
      {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: kWhiteRole, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kWhite54Role, fontSize: 13),
        prefixIcon: Icon(icon, color: kCyanRole, size: 20),
        filled: true,
        fillColor: kCardRole,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: kBorderRole.withOpacity(0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kCyanRole, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPaymentView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kCardRole,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorderRole.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Text('Total Pembayaran',
                  style: TextStyle(color: kWhite54Role.withOpacity(0.8), fontSize: 13)),
              const SizedBox(height: 8),
              Text('Rp $_amount',
                  style: TextStyle(
                    color: _isPaid ? kGreenRole : kOrangeRole,
                    fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
              const SizedBox(height: 4),
              Text('Invoice: $_invoiceId',
                  style: const TextStyle(color: kWhite54Role, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: kCyanRole.withOpacity(0.2), blurRadius: 20, spreadRadius: 2),
            ],
          ),
          child: QrImageView(
            data: _qrString ?? '',
            version: QrVersions.auto,
            size: 240,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text('Scan QR di atas dengan aplikasi e-wallet / m-banking',
            textAlign: TextAlign.center,
            style: TextStyle(color: kWhite54Role, fontSize: 12)),
        const SizedBox(height: 20),
        if (!_isPaid)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kOrangeRole.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kOrangeRole.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: kOrangeRole, strokeWidth: 2.5),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text('Menunggu pembayaran...',
                      style: TextStyle(color: kOrangeRole, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kGreenRole.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kGreenRole.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(_isLoading ? Icons.sync : Icons.check_circle,
                    color: kGreenRole, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _isLoading ? 'Membuat akun...' : 'Pembayaran diterima!',
                    style: const TextStyle(color: kGreenRole, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () {
            _pollTimer?.cancel();
            setState(() {
              _invoiceId = null;
              _qrString = null;
              _amount = null;
              _isPaid = false;
            });
          },
          child: const Text('Batal / Buat Ulang',
              style: TextStyle(color: kWhite54Role, fontSize: 12)),
        ),
      ],
    );
  }
}