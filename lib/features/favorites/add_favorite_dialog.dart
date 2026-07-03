import 'package:flutter/material.dart';

Future<String?> showAddFavoriteDialog({
  required BuildContext context,
  required String suggestedTitle,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _AddFavoriteDialog(suggestedTitle: suggestedTitle),
  );
}

class _AddFavoriteDialog extends StatefulWidget {
  const _AddFavoriteDialog({required this.suggestedTitle});

  final String suggestedTitle;

  @override
  State<_AddFavoriteDialog> createState() => _AddFavoriteDialogState();
}

class _AddFavoriteDialogState extends State<_AddFavoriteDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.suggestedTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      setState(() => _errorText = 'Le titre est obligatoire.');
      return;
    }
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter aux favoris'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Titre de l’œuvre',
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
