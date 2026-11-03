import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/supermarket.dart';
import '../providers/supermarkets_provider.dart';
import '../widgets/confirm_dialog.dart';

class SupermarketsScreen extends StatelessWidget {
  const SupermarketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final supermarkets = context.watch<SupermarketsProvider>().supermarkets;

    return Scaffold(
      appBar: AppBar(title: const Text('Supermercados')),
      body: supermarkets.isEmpty
          ? const Center(child: Text('Aún no hay supermercados'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: supermarkets.length,
              itemBuilder: (context, index) {
                final s = supermarkets[index];
                return ListTile(
                  key: Key('supermarket-tile-${s.id}'),
                  title: Text(
                    s.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: Key('edit-supermarket-${s.id}'),
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showNameDialog(context, existing: s),
                      ),
                      IconButton(
                        key: Key('delete-supermarket-${s.id}'),
                        tooltip: 'Eliminar',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, s),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-supermarket'),
        onPressed: () => _showNameDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
      ),
    );
  }

  Future<void> _showNameDialog(BuildContext context, {Supermarket? existing}) {
    final provider = context.read<SupermarketsProvider>();
    return showDialog<void>(
      context: context,
      builder: (_) => _NameDialog(
        title: existing == null ? 'Añadir supermercado' : 'Editar supermercado',
        confirmLabel: existing == null ? 'Añadir' : 'Guardar',
        initialName: existing?.name ?? '',
        onSubmit: (name) async {
          if (name.trim().isEmpty) return 'El nombre no puede estar vacío';
          final ok = existing == null
              ? await provider.add(name)
              : await provider.rename(existing.id, name);
          return ok ? null : 'Ya existe un supermercado con ese nombre';
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Supermarket s) async {
    final provider = context.read<SupermarketsProvider>();
    final confirmed = await confirmDialog(
      context,
      title: 'Eliminar supermercado',
      message:
          '¿Eliminar "${s.name}"? Los productos de este supermercado '
          'no se borran: pasarán a "Otros".',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed) return;
    await provider.remove(s.id);
  }
}

/// Diálogo de texto que se queda abierto mostrando el error si `onSubmit`
/// devuelve un mensaje; se cierra solo cuando devuelve `null`.
class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.confirmLabel,
    required this.onSubmit,
    this.initialName = '',
  });

  final String title;
  final String confirmLabel;
  final String initialName;
  final Future<String?> Function(String name) onSubmit;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    final error = await widget.onSubmit(_controller.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = error;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: 'Nombre', errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
