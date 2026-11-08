import 'package:flutter/material.dart';
import '../app_style.dart';
import 'meal_repository.dart';

const monthNames = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
String monthLabel(DateTime d) => '${monthNames[d.month - 1]} ${d.year}';
String dayLabel(DateTime d) => '${d.day} de ${monthNames[d.month - 1]}';
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class MealCalendar extends StatelessWidget {
  const MealCalendar({
    super.key,
    required this.month,
    required this.selected,
    required this.mealDays,
    required this.onMonth,
    required this.onSelected,
  });
  final DateTime month, selected;
  final Set<String> mealDays;
  final ValueChanged<DateTime> onMonth, onSelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final count = DateUtils.getDaysInMonth(month.year, month.month);
    final offset = first.weekday - 1;
    final rows = ((offset + count) / 7).ceil();
    return SoftCard(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: month.year <= 1900 && month.month == 1
                    ? null
                    : () => onMonth(DateTime(month.year, month.month - 1)),
                icon: Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  monthLabel(month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: month.year >= 2100 && month.month == 12
                    ? null
                    : () => onMonth(DateTime(month.year, month.month + 1)),
                icon: Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppStyle.resolve(context, AppStyle.muted),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 8),
          for (var row = 0; row < rows; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final day = row * 7 + col - offset + 1;
                        if (day < 1 || day > count) {
                          return SizedBox(height: 48);
                        }
                        final date = DateTime(month.year, month.month, day);
                        final selectedDay = sameDay(date, selected);
                        final hasMeals = mealDays.contains(dateKey(date));
                        return Semantics(
                          label:
                              '${dayLabel(date)}${hasMeals ? ', con comidas' : ''}',
                          selected: selectedDay,
                          button: true,
                          child: Tooltip(
                            message: dayLabel(date),
                            child: InkWell(
                              onTap: () => onSelected(date),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                height: 48,
                                margin: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: selectedDay
                                      ? AppStyle.resolve(context, AppStyle.rose)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '$day',
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: selectedDay
                                              ? (Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? AppStyle.ink
                                                    : Colors.white)
                                              : AppStyle.resolve(
                                                  context,
                                                  AppStyle.ink,
                                                ),
                                          fontWeight: selectedDay
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: hasMeals
                                            ? (selectedDay
                                                  ? (Theme.of(
                                                              context,
                                                            ).brightness ==
                                                            Brightness.dark
                                                        ? AppStyle.ink
                                                        : Colors.white)
                                                  : AppStyle.resolve(
                                                      context,
                                                      AppStyle.rose,
                                                    ))
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ],
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
        ],
      ),
    );
  }
}
