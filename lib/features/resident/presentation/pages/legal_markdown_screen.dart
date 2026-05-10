import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';

/// In-app Privacy Policy / Terms viewer (bundled Markdown assets).
class LegalMarkdownScreen extends StatefulWidget {
  const LegalMarkdownScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  State<LegalMarkdownScreen> createState() => _LegalMarkdownScreenState();
}

class _LegalMarkdownScreenState extends State<LegalMarkdownScreen> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = rootBundle.loadString(widget.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: FutureBuilder<String>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load this document.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Markdown(
            data: snapshot.data!,
            selectable: true,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
              h1: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              h2: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              h3: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              blockquote: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        },
      ),
    );
  }
}
