import 'package:flutter/material.dart';

// A minimal horizontal bar chart that shows values per label.
// Not intended to replace a charting library — lightweight and dependency-free.
class SimpleBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final double height;

  const SimpleBarChart({
    super.key,
    required this.labels,
    required this.values,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(labels.length, (i) {
          final v = values[i];
          final ratio = maxVal == 0 ? 0.0 : (v / maxVal);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                    message: '${labels[i]}: ${v.toStringAsFixed(0)}',
                    child: Container(
                      height: (height - 30) * ratio,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
