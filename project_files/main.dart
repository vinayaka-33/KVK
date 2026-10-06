import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

const uuid = Uuid();

// 1. Domain Modeling
enum Category { rent, personal, food, utilities }

class Expense {
  Expense({required this.title, required this.amount, required this.date, required this.category})
      : id = uuid.v4();
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final Category category;
}

class ExpenseBucket {
  const ExpenseBucket({required this.category, required this.expenses});
  final Category category;
  final List<Expense> expenses;

  double get totalExpenses {
    double sum = 0;
    for (final expense in expenses) {
      sum += expense.amount;
    }
    return sum;
  }
}

// 2. State Management via Riverpod
class ExpenseNotifier extends StateNotifier<List<Expense>> {
  ExpenseNotifier() : super([]);
  void addExpense(Expense expense) => state = [...state, expense];
}
final expenseProvider = StateNotifierProvider<ExpenseNotifier, List<Expense>>((ref) => ExpenseNotifier());

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) { _loadTheme(); }
  
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? false;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) => ThemeNotifier());

// 3. Application Root and Theming
void main() => runApp(const ProviderScope(child: MyApp()));

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    var kColorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    var kDarkColorScheme = ColorScheme.fromSeed(brightness: Brightness.dark, seedColor: Colors.indigo);

    return MaterialApp(
      themeMode: themeMode,
      theme: ThemeData().copyWith(
        colorScheme: kColorScheme,
        cardTheme: const CardTheme().copyWith(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: kDarkColorScheme,
        cardTheme: const CardTheme().copyWith(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
      ),
      home: const ExpenseTrackerApp(),
    );
  }
}

// 4. Data Visualization & UI
class ExpenseTrackerApp extends ConsumerWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expenseProvider);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    List<PieChartSectionData> getChartData() {
      if (expenses.isEmpty) return [PieChartSectionData(value: 1, color: Colors.grey, title: '')];
      
      final Map<Category, double> totals = {
        Category.rent: 0, Category.personal: 0, Category.food: 0, Category.utilities: 0
      };
      for (var e in expenses) { totals[e.category] = totals[e.category]! + e.amount; }
      
      return totals.entries.where((e) => e.value > 0).map((e) {
        return PieChartSectionData(
          value: e.value,
          title: '\$${e.value.toStringAsFixed(0)}',
          radius: 60,
          color: e.key == Category.rent ? Colors.red : e.key == Category.personal ? Colors.blue : e.key == Category.food ? Colors.green : Colors.orange,
        );
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(!isDark),
          )
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: 250, child: PieChart(PieChartData(sections: getChartData(), centerSpaceRadius: 40))),
          Expanded(
            child: ListView.builder(
              itemCount: expenses.length,
              itemBuilder: (ctx, index) => Card(
                child: ListTile(
                  title: Text(expenses[index].title),
                  subtitle: Text(expenses[index].category.name.toUpperCase()),
                  trailing: Text('\$${expenses[index].amount.toStringAsFixed(2)}'),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ref.read(expenseProvider.notifier).addExpense(
            Expense(title: 'Demo Rent', amount: 1500, date: DateTime.now(), category: Category.rent)
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
