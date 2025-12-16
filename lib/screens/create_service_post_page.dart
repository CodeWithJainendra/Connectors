import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class CreateServicePostPage extends StatefulWidget {
  const CreateServicePostPage({Key? key}) : super(key: key);

  @override
  State<CreateServicePostPage> createState() => _CreateServicePostPageState();
}

class _CreateServicePostPageState extends State<CreateServicePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();
  
  XFile? _selectedImage;
  String? _selectedCategory;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  
  final List<String> _categories = [
    'Electricals',
    'Electronics',
    'Clothing',
    'Arts & Crafts',
    'Food & Beverages',
    'Home Essentials',
    'Fruits & Veg',
    'Flowers',
    'Beauty & Wellness',
    'Stationery',
    'Hardware',
    'Bakery',
  ];

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _selectedImage = file;
      });
    }
  }

  Future<void> _submitPost() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    
    setState(() => _isUploading = true);

    try {
      // Upload file
      final path = await ApiService().uploadFile(_selectedImage!.path);
      
      // Create caption
      final caption = '''
${_captionController.text}
Category: $_selectedCategory
'''.trim();

      // Create post
      await ApiService().createPost(
        mediaType: 'IMAGE',
        caption: caption,
        filepath: path,
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post shared successfully!', style: GoogleFonts.roboto(fontSize: 12)),
          backgroundColor: const Color(0xFFCDDC39),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}', 
            style: GoogleFonts.roboto(fontSize: 12)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New Post',
          style: GoogleFonts.roboto(
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _submitPost,
            child: Text(
              'Share',
              style: GoogleFonts.roboto(
                color: const Color(0xFFCDDC39),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Image Picker Area
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 300,
                color: const Color(0xFFEDE9DF),
                child: _selectedImage != null
                    ? Image.file(File(_selectedImage!.path), fit: BoxFit.cover)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 48, color: const Color(0xFF1A1A1A).withOpacity(0.4)),
                          const SizedBox(height: 8),
                          Text('Tap to select photo', style: GoogleFonts.roboto(color: const Color(0xFF1A1A1A).withOpacity(0.4))),
                        ],
                      ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Caption
                  TextField(
                    controller: _captionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Write a caption...',
                      hintStyle: GoogleFonts.roboto(color: const Color(0xFF9E9E9E)),
                      border: InputBorder.none,
                    ),
                    style: GoogleFonts.roboto(fontSize: 14),
                  ),
                  const Divider(),
                  
                  // Category Selection
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Category', style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
                    trailing: DropdownButton<String>(
                      value: _selectedCategory,
                      hint: Text('Select', style: GoogleFonts.roboto(fontSize: 14)),
                      underline: Container(),
                      items: _categories.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: GoogleFonts.roboto(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val),
                    ),
                  ),
                  const Divider(),
                ],
              ),
            ),
            
            if (_isUploading)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: CircularProgressIndicator(color: Color(0xFFCDDC39))),
              ),
          ],
        ),
      ),
    );
  }
}
