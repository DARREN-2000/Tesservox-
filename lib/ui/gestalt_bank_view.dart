import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/gestalt.dart';
import '../state/providers.dart';

/// Provides the global [GestaltBank].
final gestaltBankProvider = ChangeNotifierProvider<GestaltBank>((ref) {
  // Pre-load with some common gestalt scripts for demonstration.
  return GestaltBank(
    initialPhrases: const [
      GestaltPhrase(
        id: '1',
        text: 'I need a break',
        label: 'Break',
      ),
      GestaltPhrase(
        id: '2',
        text: 'Can you help me please?',
        label: 'Help',
      ),
      GestaltPhrase(
        id: '3',
        text: 'I love you',
        label: 'I love you',
      ),
    ],
  );
});

/// UI Component for viewing and triggering Gestalt Phrases.
class GestaltBankView extends ConsumerWidget {
  const GestaltBankView({
    super.key,
    required this.onTriggerPhrase,
  });

  /// Called when a user selects a phrase to trigger immediately.
  final void Function(String text) onTriggerPhrase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gestaltBank = ref.watch(gestaltBankProvider);
    final phrases = gestaltBank.phrases;

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              'Gestalt Phrases',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E7E),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: phrases.length,
              itemBuilder: (context, index) {
                final phrase = phrases[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8.0),
                    onTap: () => onTriggerPhrase(phrase.text),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        phrase.displayText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
