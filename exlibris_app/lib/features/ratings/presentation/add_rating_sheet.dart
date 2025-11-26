import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/book.dart';
import '../data/ratings_repository.dart';
import '../../../models/rating.dart';

class AddRatingSheet extends ConsumerStatefulWidget {
  final Book book;

  const AddRatingSheet({super.key, required this.book});

  @override
  ConsumerState<AddRatingSheet> createState() => _AddRatingSheetState();
}

class _AddRatingSheetState extends ConsumerState<AddRatingSheet> {
  double _currentNote = 0;
  final _commentController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingRating();
  }

  Future<void> _loadExistingRating() async {
    final repo = ref.read(ratingsRepositoryProvider);

    try {
      final Rating? existing = await repo.getMyRatingFor(widget.book.isbn);
      if (existing != null) {
        setState(() {
          _currentNote = existing.note.toDouble();
          _commentController.text = existing.avis ?? '';
        });
      }
    } catch (_) {
      // pour l’instant on ignore les erreurs
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final repo = ref.read(ratingsRepositoryProvider);

    setState(() => _loading = true);

    try {
      await repo.saveRating(
        isbn: widget.book.isbn,
        note: _currentNote.toInt(),
        avis: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pop(); // fermer le bottom sheet

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Note enregistrée pour "${widget.book.titre}" : ${_currentNote.toInt()}/10',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur enregistrement note : $e')),
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: _loading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Noter "${widget.book.titre}"',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),

                // ---- Slider de 0 à 10 ----
                Row(
                  children: [
                    const Text('Note :'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: 10,
                        divisions: 10,
                        value: _currentNote,
                        label: _currentNote.toInt().toString(),
                        onChanged: (value) {
                          setState(() {
                            _currentNote = value; // <--- IMPORTANT
                          });
                        },
                      ),
                    ),
                    Text('${_currentNote.toInt()}/10'),
                  ],
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    labelText: 'Avis (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _loading ? null : _save,
                      child: const Text('Enregistrer'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
