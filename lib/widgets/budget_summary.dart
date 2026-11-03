import 'package:flutter/material.dart';

import '../logic/list_grouping.dart';
import '../utils/price_format.dart';

class BudgetSummary extends StatelessWidget {
  const BudgetSummary({super.key, required this.total, required this.budget});

  final ListTotal total;
  final double? budget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final budget = this.budget;

    final over = budget != null && total.isOverBudget(budget);
    // Mismos tonos de 1.0.1: shade700 en claro, shade300 en oscuro.
    final color = over
        ? (dark ? Colors.red.shade300 : Colors.red.shade700)
        : (dark ? Colors.green.shade300 : Colors.green.shade700);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total: ${total.label}',
              key: const Key('list-total'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (budget != null) ...[
              const SizedBox(height: 4),
              Text.rich(
                key: const Key('list-budget'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                TextSpan(
                  style: theme.textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: 'Presupuesto ${formatPrice(budget)} · Restante: ',
                    ),
                    TextSpan(
                      text: total.remainingLabel(budget),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                key: const Key('budget-progress'),
                value: budget > 0
                    ? (total.total / budget).clamp(0.0, 1.0).toDouble()
                    : 0,
                color: color,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
