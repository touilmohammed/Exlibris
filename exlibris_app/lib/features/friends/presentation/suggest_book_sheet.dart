import 'package:flutter/material.dart';
import '../../../models/friend.dart';

class SuggestBookSheet extends StatefulWidget {
  final Friend friend;

  const SuggestBookSheet({super.key, required this.friend});

  @override
  State<SuggestBookSheet> createState() => _SuggestBookSheetState();
}

class _SuggestBookSheetState extends State<SuggestBookSheet> {
  final _isbnController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _isbnController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    final isbn = _isbnController.text.trim();
    final msg = _messageController.text.trim();

    Navigator.of(context).pop(); // fermer le bottom sheet

    // On utilise msg pour éviter le warning "unused variable"
    final baseText = 'Suggestion envoyée à ${widget.friend.nom}';
    final withIsbn = isbn.isNotEmpty ? ' (ISBN: $isbn)' : '';
    final withMsg = msg.isNotEmpty ? '\nMessage : $msg' : '';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$baseText$withIsbn$withMsg')));

    // Plus tard : appel API /suggestion avec isbn + message
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suggérer un livre à ${widget.friend.nom}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _isbnController,
              decoration: const InputDecoration(
                labelText: 'ISBN du livre (optionnel)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message (optionnel)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send),
                label: const Text('Envoyer la suggestion'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
