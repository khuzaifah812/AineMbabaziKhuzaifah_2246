import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await DatabaseHelper.instance.database;
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(db),
      child: const POSApp(),
    ),
  );
}

// ===========================================================================
// 1. DATABASE HELPER (Offline Storage)
// ===========================================================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos_retail.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_name TEXT,
        email TEXT UNIQUE,
        password TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        price REAL,
        stock INTEGER,
        category TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        phone TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total REAL,
        payment_method TEXT,
        date TEXT
      )
    ''');

    // Insert default inventory
    await db.insert('products', {'name': 'Coca Cola', 'price': 2500.0, 'stock': 50, 'category': 'Beverages'});
    await db.insert('products', {'name': 'Bread', 'price': 3000.0, 'stock': 20, 'category': 'Food'});
    await db.insert('products', {'name': 'Water 1L', 'price': 1500.0, 'stock': 100, 'category': 'Beverages'});
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}

// ===========================================================================
// 2. STATE MANAGEMENT
// ===========================================================================
class AppState extends ChangeNotifier {
  final Database db;
  AppState(this.db);

  bool isLoggedIn = false;
  String businessName = "My Store";
  Color primaryColor = const Color(0xFF1A56DB);

  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> sales = [];

  double get todayTotal {
    final today = DateTime.now();
    double total = 0;
    for (var sale in sales) {
      DateTime d = DateTime.parse(sale['date']);
      if (d.day == today.day && d.month == today.month && d.year == today.year) {
        total += sale['total'];
      }
    }
    return total;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    businessName = prefs.getString('bizName') ?? "My Store";
    await loadData();
    notifyListeners();
  }

  Future<void> loadData() async {
    products = await db.query('products');
    customers = await db.query('customers');
    sales = await db.query('sales', orderBy: 'date DESC');
    notifyListeners();
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<String?> register(String bizName, String email, String password) async {
    try {
      await db.insert('users', {
        'business_name': bizName,
        'email': email,
        'password': _hashPassword(password),
      });
      await login(email, password);
      return null; // Success
    } catch (e) {
      return "Account with this email already exists.";
    }
  }

  Future<bool> login(String email, String password) async {
    final res = await db.query('users', where: 'email = ? AND password = ?', whereArgs: [email, _hashPassword(password)]);
    if (res.isNotEmpty) {
      isLoggedIn = true;
      businessName = res.first['business_name'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('bizName', businessName);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    isLoggedIn = false;
    notifyListeners();
  }

  Future<void> addProduct(String name, double price, int stock, String category) async {
    await db.insert('products', {'name': name, 'price': price, 'stock': stock, 'category': category});
    await loadData();
  }

  Future<void> addCustomer(String name, String phone) async {
    await db.insert('customers', {'name': name, 'phone': phone});
    await loadData();
  }

  Future<void> processSale(List<Map<String, dynamic>> cart, double total, String method) async {
    // 1. Save Sale Record
    await db.insert('sales', {
      'total': total,
      'payment_method': method,
      'date': DateTime.now().toIso8601String(),
    });

    // 2. Deduct Inventory (Offline Sync)
    for (var item in cart) {
      int newStock = (item['stock'] as int) - (item['qty'] as int);
      if (newStock < 0) newStock = 0;
      await db.update('products', {'stock': newStock}, where: 'id = ?', whereArgs: [item['id']]);
    }

    await loadData();
  }
}

// ===========================================================================
// 3. APP ROOT
// ===========================================================================
class POSApp extends StatelessWidget {
  const POSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POS Retail Pro',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: context.watch<AppState>().primaryColor), useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF3F4F6)),
      home: const AppLoader(),
    );
  }
}

class AppLoader extends StatefulWidget {
  const AppLoader({super.key});
  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  @override
  void initState() {
    super.initState();
    context.read<AppState>().init();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Simple loading check
    if (!state.isLoggedIn && state.businessName == "My Store" && state.products.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return state.isLoggedIn ? const MainNavigation() : const LoginScreen();
  }
}

// ===========================================================================
// 4. LOGIN / REGISTER
// ===========================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = true;
  final _bizCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  void _submit() async {
    final state = context.read<AppState>();
    if (isLogin) {
      bool success = await state.login(_emailCtrl.text, _passCtrl.text);
      if (!success) _showError('Invalid credentials');
    } else {
      String? error = await state.register(_bizCtrl.text, _emailCtrl.text, _passCtrl.text);
      if (error != null) _showError(error);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 50),
              const Icon(Icons.shopping_cart, size: 80, color: Color(0xFF1A56DB)),
              const SizedBox(height: 20),
              const Text('POS Retail Pro', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Text('Offline Ready & Secure', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              if (!isLogin) TextField(controller: _bizCtrl, decoration: const InputDecoration(labelText: 'Business Name', border: OutlineInputBorder())),
              if (!isLogin) const SizedBox(height: 15),
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
              const SizedBox(height: 30),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _submit, child: Text(isLogin ? 'Login' : 'Register'))),
              TextButton(onPressed: () => setState(() => isLogin = !isLogin), child: Text(isLogin ? "Create Account" : "Login Instead")),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// 5. MAIN NAVIGATION & DASHBOARD
// ===========================================================================
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0;
  final screens = const [DashboardScreen(), InventoryScreen(), ReportsScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: context.read<AppState>().primaryColor,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currency = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: Text(state.businessName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: state.primaryColor, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Today's Revenue", style: TextStyle(color: Colors.white70)),
                  Text(currency.format(state.todayTotal), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewSaleScreen())),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Start New Sale'),
            ),
            const SizedBox(height: 30),
            const Align(alignment: Alignment.centerLeft, child: Text('Recent Sales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ...state.sales.take(5).map((s) => Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(s['payment_method']),
                subtitle: Text(DateFormat.yMMMd().add_jm().format(DateTime.parse(s['date']))),
                trailing: Text(currency.format(s['total'])),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 6. INVENTORY & ADD PRODUCT
// ===========================================================================
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currency = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.products.length,
        itemBuilder: (context, index) {
          final p = state.products[index];
          return Card(
            child: ListTile(
              title: Text(p['name']),
              subtitle: Text('Stock: ${p['stock']}'),
              trailing: Text(currency.format(p['price'])),
              onTap: () {
                if (p['stock'] > 0) Navigator.push(context, MaterialPageRoute(builder: (_) => NewSaleScreen(initialProduct: p)));
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: state.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen())),
      ),
    );
  }
}

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});
  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Product Name')),
            TextField(controller: _price, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
            TextField(controller: _stock, decoration: const InputDecoration(labelText: 'Initial Stock'), keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_name.text.isNotEmpty) {
                  context.read<AppState>().addProduct(_name.text, double.parse(_price.text), int.parse(_stock.text), 'General');
                  Navigator.pop(context);
                }
              },
              child: const Text('Save Product'),
            )
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 7. NEW SALE (POS) & PAYMENT
// ===========================================================================
class NewSaleScreen extends StatefulWidget {
  final Map<String, dynamic>? initialProduct;
  const NewSaleScreen({super.key, this.initialProduct});
  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  List<Map<String, dynamic>> cart = [];
  final currency = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    if (widget.initialProduct != null) {
      cart.add({...widget.initialProduct!, 'qty': 1});
    }
  }

  double get total => cart.fold(0.0, (sum, item) => sum + (item['price'] * item['qty']));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Sale')),
      body: Column(
        children: [
          Expanded(
            child: cart.isEmpty 
              ? const Center(child: Text('Select items from Inventory.')) 
              : ListView.builder(
                  itemCount: cart.length,
                  itemBuilder: (context, i) {
                    final item = cart[i];
                    return ListTile(
                      title: Text(item['name']),
                      subtitle: Text(currency.format(item['price'])),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.remove), onPressed: () => setState(() { if(item['qty'] > 1) item['qty']--; else cart.removeAt(i); })),
                          Text('${item['qty']}'),
                          IconButton(icon: const Icon(Icons.add), onPressed: () => setState(() { if(item['qty'] < item['stock']) item['qty']++; })),
                        ],
                      ),
                    );
                  },
                ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total'), Text(currency.format(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))]),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  onPressed: cart.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(cart: cart, total: total))),
                  child: const Text('Proceed to Payment'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cart;
  final double total;
  const PaymentScreen({super.key, required this.cart, required this.total});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String method = 'Cash';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Total: ${NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0).format(widget.total)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            RadioListTile(title: const Text('Cash'), value: 'Cash', groupValue: method, onChanged: (v) => setState(() => method = v!)),
            RadioListTile(title: const Text('Credit/Debit Card'), value: 'Card', groupValue: method, onChanged: (v) => setState(() => method = v!)),
            RadioListTile(title: const Text('Mobile Money'), value: 'Mobile', groupValue: method, onChanged: (v) => setState(() => method = v!)),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: () async {
                await context.read<AppState>().processSale(widget.cart, widget.total, method);
                if (mounted) {
                  Navigator.popUntil(context, (route) => route.isFirst);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale Completed & Saved Offline')));
                }
              },
              child: const Text('Complete Payment'),
            )
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 8. REPORTS
// ===========================================================================
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currency = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
    final totalRev = state.sales.fold(0.0, (sum, s) => sum + (s['total'] as double));

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('Total Revenue (Database)'),
                  Text(currency.format(totalRev), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Total Transactions: ${state.sales.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ===========================================================================
// 9. SETTINGS
// ===========================================================================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(leading: const Icon(Icons.store), title: Text(state.businessName), subtitle: const Text('Logged in securely')),
          const Divider(),
          const ListTile(leading: Icon(Icons.security), title: Text('Security'), subtitle: Text('Passwords hashed with SHA-256'), trailing: Icon(Icons.check, color: Colors.green)),
          const ListTile(leading: Icon(Icons.offline_bolt), title: Text('Offline Database'), subtitle: Text('SQLite Active'), trailing: Icon(Icons.check, color: Colors.green)),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(onPressed: () => state.logout(), child: const Text('Logout')),
          )
        ],
      ),
    );
  }
}