import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

final uuid = const Uuid();
final formatter = DateFormat.yMd();

enum ExpenseCategory { housing, food, commute, electronics, corporate, personal }

const categoryIcons = {
  ExpenseCategory.housing: Icons.home_rounded,
  ExpenseCategory.food: Icons.restaurant_rounded,
  ExpenseCategory.commute: Icons.directions_car_rounded,
  ExpenseCategory.electronics: Icons.memory_rounded,
  ExpenseCategory.corporate: Icons.business_center_rounded,
  ExpenseCategory.personal: Icons.person_rounded,
};

class Expense {
  Expense({required this.title, required this.amount, required this.date, required this.category, String? id}) : id = id ?? uuid.v4();
  final String id; final String title; final double amount; final DateTime date; final ExpenseCategory category;

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'amount': amount, 'date': date.toIso8601String(), 'category': category.name,
  };
  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'], title: json['title'], amount: json['amount'], date: DateTime.parse(json['date']),
    category: ExpenseCategory.values.firstWhere((e) => e.name == json['category']),
  );
}

class ExpenseNotifier extends StateNotifier<List<Expense>> {
  ExpenseNotifier() : super([]) { _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('expenses');
    if (data != null) {
      final List decoded = jsonDecode(data);
      state = decoded.map((e) => Expense.fromJson(e)).toList();
    }
  }
  Future<void> _save(List<Expense> newState) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('expenses', jsonEncode(newState.map((e) => e.toJson()).toList()));
  }
  void addExpense(Expense expense) { state = [...state, expense]; _save(state); }
  void removeExpense(Expense expense) { state = state.where((e) => e.id != expense.id).toList(); _save(state); }
}
final expenseProvider = StateNotifierProvider<ExpenseNotifier, List<Expense>>((ref) => ExpenseNotifier());

void main() => runApp(const ProviderScope(child: MyApp()));

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(primary: Colors.white, secondary: Colors.redAccent, surface: Color(0xFF121212)),
        textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black, elevation: 0),
        cardTheme: CardTheme(color: const Color(0xFF1A1A1A), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Color(0xFF121212)),
      ),
      home: const DashboardScreen(),
    );
  }
}

class NewExpenseForm extends ConsumerStatefulWidget {
  const NewExpenseForm({super.key});
  @override
  ConsumerState<NewExpenseForm> createState() => _NewExpenseFormState();
}

class _NewExpenseFormState extends ConsumerState<NewExpenseForm> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _selectedDate;
  ExpenseCategory _selectedCategory = ExpenseCategory.personal;

  void _submit() {
    final amount = double.tryParse(_amountController.text);
    if (_titleController.text.trim().isEmpty || amount == null || amount <= 0 || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid title, amount, and date.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      return;
    }
    ref.read(expenseProvider.notifier).addExpense(Expense(title: _titleController.text, amount: amount, date: _selectedDate!, category: _selectedCategory));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 48, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('NEW EXPENSE', style: GoogleFonts.spaceMono(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 16),
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()), style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: TextField(controller: _amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹ ', border: OutlineInputBorder()), style: const TextStyle(color: Colors.white))),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(_selectedDate == null ? 'No Date' : formatter.format(_selectedDate!)),
                    IconButton(icon: const Icon(Icons.calendar_month), onPressed: () async {
                      final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                      setState(() => _selectedDate = date);
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ExpenseCategory>(
            value: _selectedCategory,
            dropdownColor: const Color(0xFF1A1A1A),
            items: ExpenseCategory.values.map((c) => DropdownMenuItem(value: c, child: Row(children: [Icon(categoryIcons[c], size: 18), const SizedBox(width: 10), Text(c.name.toUpperCase())]))).toList(),
            onChanged: (val) => setState(() => _selectedCategory = val!),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              onPressed: _submit,
              child: const Text('SAVE RECORD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          )
        ],
      ),
    );
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expenseProvider);
    final total = expenses.fold(0.0, (sum, e) => sum + e.amount);

    List<PieChartSectionData> getChartData() {
      if (expenses.isEmpty) return [PieChartSectionData(value: 1, color: Colors.grey.withOpacity(0.2), radius: 20, showTitle: false)];
      final Map<ExpenseCategory, double> totals = {};
      for (var c in ExpenseCategory.values) { totals[c] = 0; }
      for (var e in expenses) { totals[e.category] = totals[e.category]! + e.amount; }
      final colors = [Colors.white, Colors.redAccent, Colors.grey, Colors.blueGrey, Colors.orangeAccent, Colors.greenAccent];
      return totals.entries.where((e) => e.value > 0).map((e) => PieChartSectionData(value: e.value, radius: 25, title: '', color: colors[e.key.index % colors.length])).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('FINANCE OS', style: GoogleFonts.spaceMono(fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [IconButton(icon: const Icon(Icons.add_circle_outline, size: 28), onPressed: () => showModalBottomSheet(isScrollControlled: true, context: context, builder: (c) => const NewExpenseForm()))],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.1))),
            child: Row(
              children: [
                SizedBox(height: 100, width: 100, child: PieChart(PieChartData(sections: getChartData(), centerSpaceRadius: 35, sectionsSpace: 4))),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL SPENT', style: TextStyle(color: Colors.grey[400], letterSpacing: 1, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('₹${total.toStringAsFixed(2)}', style: GoogleFonts.spaceMono(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: expenses.isEmpty
              ? Center(child: Text('NO RECORDS FOUND', style: GoogleFonts.spaceMono(color: Colors.grey)))
              : ListView.builder(
                  itemCount: expenses.length,
                  itemBuilder: (ctx, i) {
                    final e = expenses.reversed.toList()[i];
                    return Dismissible(
                      key: ValueKey(e.id),
                      background: Container(color: Colors.redAccent, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                      onDismissed: (direction) => ref.read(expenseProvider.notifier).removeExpense(e),
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.white.withOpacity(0.1), child: Icon(categoryIcons[e.category], color: Colors.white, size: 20)),
                          title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${e.category.name.toUpperCase()} • ${formatter.format(e.date)}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          trailing: Text('₹${e.amount.toStringAsFixed(2)}', style: GoogleFonts.spaceMono(fontWeight: FontWeight.bold, fontSize: 16)),
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
