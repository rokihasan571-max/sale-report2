import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SalesTrackerApp());
}

class SalesTrackerApp extends StatelessWidget {
  const SalesTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Page Sales Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// Database Helper
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sales_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        imagePath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER,
        productName TEXT,
        quantity INTEGER,
        totalPrice REAL,
        date TEXT
      )
    ''');
  }

  Future<int> insertProduct(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('products', row);
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await instance.database;
    return await db.query('products', orderBy: 'id DESC');
  }

  Future<int> insertSale(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('sales', row);
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    final db = await instance.database;
    return await db.query('sales', orderBy: 'id DESC');
  }
}

// Home Screen with Bottom Navigation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const SellScreen(),
    const ProductsScreen(),
    const ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Sell'),
          NavigationDestination(icon: Icon(Icons.inventory), label: 'Products'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Report'),
        ],
      ),
    );
  }
}

// 1. Sell Screen (Quick Sales Entry)
class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  List<Map<String, dynamic>> products = [];
  Map<String, dynamic>? selectedProduct;
  final TextEditingController qtyController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  void loadProducts() async {
    final data = await DatabaseHelper.instance.getProducts();
    setState(() {
      products = data;
      if (products.isNotEmpty) selectedProduct = products[0];
    });
  }

  void recordSale() async {
    if (selectedProduct == null) return;
    int qty = int.tryParse(qtyController.text) ?? 1;
    double price = selectedProduct!['price'];
    double total = price * qty;

    await DatabaseHelper.instance.insertSale({
      'productId': selectedProduct!['id'],
      'productName': selectedProduct!['name'],
      'quantity': qty,
      'totalPrice': total,
      'date': DateTime.now().toIso8601String(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sale Recorded Successfully!')),
    );
    qtyController.text = '1';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Sale / Quick Sell')),
      body: products.isEmpty
          ? const Center(child: Text('No products found! Please add products first.'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Select Product:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedProduct,
                    items: products.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text('${p['name']} (Tk ${p['price']})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedProduct = val;
                      });
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  if (selectedProduct != null && selectedProduct!['imagePath'] != null)
                    SizedBox(
                      height: 150,
                      child: Image.file(File(selectedProduct!['imagePath']), fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white).wrap(
                    ElevatedButton(
                      onPressed: recordSale,
                      child: const Text('Confirm Sale', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

extension on ButtonStyle {
  Widget wrap(Widget child) => Builder(builder: (context) => SizedBox(width: double.infinity, height: 50, child: child));
}

// 2. Products Management Screen
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> products = [];

  @override
  void initState() {
    super.initState();
    refreshProducts();
  }

  void refreshProducts() async {
    final data = await DatabaseHelper.instance.getProducts();
    setState(() {
      products = data;
    });
  }

  void showAddProductDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    String? imagePath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Product Name')),
                TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling Price (Tk)')),
                const SizedBox(height: 10),
                imagePath == null
                    ? TextButton.icon(
                        onPressed: () async {
                          final picker = ImagePicker();
                          final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                          if (pickedFile != null) {
                            setDialogState(() {
                              imagePath = pickedFile.path;
                            });
                          }
                        },
                        icon: const Icon(Icons.image),
                        label: const Text('Pick Product Picture'),
                      )
                    : Image.file(File(imagePath!), height: 100, width: 100, fit: BoxFit.cover),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
                  await DatabaseHelper.instance.insertProduct({
                    'name': nameController.text,
                    'price': double.parse(priceController.text),
                    'imagePath': imagePath,
                  });
                  refreshProducts();
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Products')),
      body: products.isEmpty
          ? const Center(child: Text('No products added yet. Click + to add.'))
          : ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final p = products[index];
                return ListTile(
                  leading: p['imagePath'] != null
                      ? Image.file(File(p['imagePath']), width: 50, height: 50, fit: BoxFit.cover)
                      : const Icon(Icons.image, size: 50),
                  title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Price: Tk ${p['price']}'),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddProductDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// 3. Reports & Dashboard Screen
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> sales = [];

  @override
  void initState() {
    super.initState();
    loadSales();
  }

  void loadSales() async {
    final data = await DatabaseHelper.instance.getSales();
    setState(() {
      sales = data;
    });
  }

  double calculateTotal(bool isWeekly) {
    double total = 0;
    DateTime now = DateTime.now();
    for (var s in sales) {
      DateTime saleDate = DateTime.parse(s['date']);
      if (isWeekly) {
        if (now.difference(saleDate).inDays <= 7) {
          total += s['totalPrice'];
        }
      } else {
        if (saleDate.month == now.month && saleDate.year == now.year) {
          total += s['totalPrice'];
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    double weeklyTotal = calculateTotal(true);
    double monthlyTotal = calculateTotal(false);

    return Scaffold(
      appBar: AppBar(title: const Text('Sales Reports')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('Weekly Sales', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Tk $weeklyTotal', style: const TextStyle(fontSize: 18, color: Colors.blue)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('Monthly Sales', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Tk $monthlyTotal', style: const TextStyle(fontSize: 18, color: Colors.green)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent Sales History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: sales.isEmpty
                  ? const Center(child: Text('No sales recorded yet.'))
                  : ListView.builder(
                      itemCount: sales.length,
                      itemBuilder: (context, index) {
                        var s = sales[index];
                        return ListTile(
                          title: Text('${s['productName']} (Qty: ${s['quantity']})'),
                          subtitle: Text(s['date'].toString().substring(0, 16)),
                          trailing: Text('Tk ${s['totalPrice']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
