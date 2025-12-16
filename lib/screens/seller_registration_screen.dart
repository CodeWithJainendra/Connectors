import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SellerRegistrationScreen extends StatefulWidget {
  final String token;
  const SellerRegistrationScreen({super.key, required this.token});

  @override
  State<SellerRegistrationScreen> createState() => _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState extends State<SellerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _bizName = TextEditingController();
  final TextEditingController _category = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _desc = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Seller Registration', style: GoogleFonts.roboto(color: const Color(0xFF1A1A1A))),
        backgroundColor: const Color(0xFFFAF7F0),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFFAF7F0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field('Business Name', _bizName, Icons.storefront),
              const SizedBox(height: 10),
              _field('Category', _category, Icons.category_outlined),
              const SizedBox(height: 10),
              _field('Address', _address, Icons.location_on_outlined),
              const SizedBox(height: 10),
              _field('Phone', _phone, Icons.phone_outlined, keyboard: TextInputType.phone),
              const SizedBox(height: 10),
              _multiline('Description', _desc),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCDDC39),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _submit,
                  child: Text('Submit', style: GoogleFonts.roboto(fontSize: 12, color: const Color(0xFF1A1A1A), fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seller registration submitted', style: GoogleFonts.roboto(fontSize: 12))),
      );
    }
  }

  Widget _field(String label, TextEditingController controller, IconData icon, {TextInputType keyboard = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.roboto(fontSize: 12, color: const Color(0xFF4A4A4A))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF6B7280)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            filled: true,
            fillColor: const Color(0xFFFAF7F0),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.15), width: 1.2),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: Color(0xFFCDDC39), width: 1.4),
            ),
          ),
          style: GoogleFonts.roboto(fontSize: 12),
        ),
      ],
    );
  }

  Widget _multiline(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.roboto(fontSize: 12, color: const Color(0xFF4A4A4A))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            filled: true,
            fillColor: const Color(0xFFFAF7F0),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.15), width: 1.2),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: Color(0xFFCDDC39), width: 1.4),
            ),
          ),
          style: GoogleFonts.roboto(fontSize: 12),
        ),
      ],
    );
  }
}
