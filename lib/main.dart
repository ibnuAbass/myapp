import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/transaction_repository.dart';
import 'data/services/sms_service.dart';
import 'presentation/bloc/transaction_bloc.dart';
import 'presentation/bloc/transaction_event.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/analytics_page.dart';
import 'presentation/pages/transactions_page.dart';
import 'presentation/widgets/bottom_nav_bar.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);
  getIt.registerSingleton<TransactionRepository>(TransactionRepository(prefs));
  getIt.registerSingleton<SmsService>(SmsService());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();
  runApp(const MpesaTrackerApp());
}

class MpesaTrackerApp extends StatelessWidget {
  const MpesaTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          TransactionBloc(getIt<TransactionRepository>(), getIt<SmsService>())
            ..add(const ReadSmsFromDevice()),
      child: MaterialApp(
        title: 'M-PESA Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onViewAllTransactions: () => _switchTab(2)),
      const AnalyticsPage(),
      const TransactionsPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _switchTab,
      ),
    );
  }
}
