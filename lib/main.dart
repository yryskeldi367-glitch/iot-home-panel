// main.dart -- точка входа панели «Умный дом».
// Cupertino-интерфейс, тема автоматически светлая/тёмная по системе.
import 'package:flutter/cupertino.dart';

import 'app_state.dart';
import 'tabs.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  // ignore: discarded_futures
  state.init();
  runApp(HomePanelApp(state: state));
}

class HomePanelApp extends StatelessWidget {
  final AppState state;

  const HomePanelApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Умный дом',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        barBackgroundColor: null,
        textTheme: CupertinoTextThemeData(
          primaryColor: CupertinoColors.systemBlue,
        ),
      ),
      home: CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          items: const [
            BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.house_fill), label: 'Дом'),
            BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.lightbulb_fill), label: 'Реле'),
            BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.chart_bar_alt_fill), label: 'История'),
            BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.gear_solid), label: 'Настройки'),
          ],
        ),
        tabBuilder: (context, index) {
          switch (index) {
            case 1:
              return CupertinoTabView(builder: (_) => RelaysTab(state: state));
            case 2:
              return CupertinoTabView(builder: (_) => HistoryTab(state: state));
            case 3:
              return CupertinoTabView(builder: (_) => SettingsTab(state: state));
            default:
              return CupertinoTabView(builder: (_) => HomeTab(state: state));
          }
        },
      ),
    );
  }
}
