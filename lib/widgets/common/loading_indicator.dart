/// `LoadingIndicator` — spinner centralizado.
import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(label!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
