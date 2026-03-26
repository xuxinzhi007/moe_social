import 'package:flutter/material.dart';

class MoeSearchBar extends StatefulWidget {
  final String hintText;
  final Function(String) onSearch;
  final Function() onClear;

  const MoeSearchBar({
    super.key,
    required this.hintText,
    required this.onSearch,
    required this.onClear,
  });

  @override
  State<MoeSearchBar> createState() => _MoeSearchBarState();
}

class _MoeSearchBarState extends State<MoeSearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.search, color: Colors.grey),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey[400]),
              ),
              onChanged: widget.onSearch,
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _controller.clear();
                widget.onClear();
              },
              icon: const Icon(Icons.clear, color: Colors.grey),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
