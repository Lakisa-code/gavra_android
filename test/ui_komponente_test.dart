import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('🔲 WIDGET TESTOVI - Dugmad i UI Komponente', () {
    // Test osnovnih UI komponenti
    testWidgets('Osnovne UI komponente - Card', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Card(
              child: Text('Test Card'),
            ),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Test Card'), findsOneWidget);
    });

    testWidgets('Osnovne UI komponente - Button', (WidgetTester tester) async {
      bool buttonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () => buttonPressed = true,
              child: const Text('Test Button'),
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Test Button'), findsOneWidget);

      // Test dugme pritisak
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(buttonPressed, true);
    });

    testWidgets('Icon buttons', (WidgetTester tester) async {
      int iconPressCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconButton(
              icon: const Icon(Icons.payment),
              onPressed: () => iconPressCount++,
            ),
          ),
        ),
      );

      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byIcon(Icons.payment), findsOneWidget);

      // Test icon pritisak
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(iconPressCount, 1);
    });

    testWidgets('Text field validation', (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Test Input',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Test Input'), findsOneWidget);

      // Test unos teksta
      await tester.enterText(find.byType(TextField), 'Test vrednost');
      expect(controller.text, 'Test vrednost');
    });

    testWidgets('Dialog testiranje', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => const AlertDialog(
                      title: Text('Test Dialog'),
                      content: Text('Dialog sadržaj'),
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      // Inicijalno nema dialog
      expect(find.text('Test Dialog'), findsNothing);

      // Pritisnemo dugme da otvorimo dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Sada dialog treba da postoji
      expect(find.text('Test Dialog'), findsOneWidget);
      expect(find.text('Dialog sadržaj'), findsOneWidget);
    });

    testWidgets('Scroll view testiranje', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 100,
              itemBuilder: (context, index) => ListTile(
                title: Text('Item $index'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 99'), findsNothing); // Nije vidljiv bez skrolovanja

      // Test skrolovanje
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      // Sada možda vidimo druge elemente
      expect(find.byType(ListTile), findsWidgets);
    });

    // Test responsive layout
    testWidgets('Responsive layout test', (WidgetTester tester) async {
      // Test mali ekran
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                return Text('Width: ${constraints.maxWidth}');
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('Width: 400'), findsOneWidget);

      // Test veliki ekran
      tester.view.physicalSize = const Size(800, 1200);
      await tester.pump();

      expect(find.textContaining('Width: 800'), findsOneWidget);

      // Resetuj view
      addTearDown(tester.view.reset);
    });

    testWidgets('FloatingActionButton test', (WidgetTester tester) async {
      bool fabPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Text('Test Body'),
            floatingActionButton: FloatingActionButton(
              onPressed: () => fabPressed = true,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(fabPressed, true);
    });

    testWidgets('SnackBar test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Test SnackBar')),
                  );
                },
                child: const Text('Show SnackBar'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test SnackBar'), findsNothing);

      await tester.tap(find.text('Show SnackBar'));
      await tester.pump();

      expect(find.text('Test SnackBar'), findsOneWidget);
    });

    testWidgets('Checkbox test', (WidgetTester tester) async {
      bool checkboxValue = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Checkbox(
                value: checkboxValue,
                onChanged: (value) {
                  setState(() {
                    checkboxValue = value ?? false;
                  });
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Checkbox), findsOneWidget);

      // Test checkbox pritisak
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Checkbox treba da se promeni
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, true);
    });

    testWidgets('Switch test', (WidgetTester tester) async {
      bool switchValue = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Switch(
                value: switchValue,
                onChanged: (value) {
                  setState(() {
                    switchValue = value;
                  });
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pump();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, true);
    });

    testWidgets('Slider test', (WidgetTester tester) async {
      double sliderValue = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Slider(
                value: sliderValue,
                max: 100.0,
                onChanged: (value) {
                  setState(() {
                    sliderValue = value;
                  });
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Slider), findsOneWidget);

      // Test slider drag
      await tester.drag(find.byType(Slider), const Offset(50, 0));
      await tester.pump();

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, greaterThan(0.0));
    });

    testWidgets('CircularProgressIndicator test', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('LinearProgressIndicator test', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: LinearProgressIndicator(value: 0.5),
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(indicator.value, 0.5);
    });

    testWidgets('TabBar test', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Scaffold(
              appBar: TabBar(
                tabs: [
                  Tab(text: 'Tab 1'),
                  Tab(text: 'Tab 2'),
                  Tab(text: 'Tab 3'),
                ],
              ),
              body: TabBarView(
                children: [
                  Text('Content 1'),
                  Text('Content 2'),
                  Text('Content 3'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Tab 1'), findsOneWidget);
      expect(find.text('Tab 2'), findsOneWidget);
      expect(find.text('Tab 3'), findsOneWidget);
      expect(find.text('Content 1'), findsOneWidget);

      // Test tab switch
      await tester.tap(find.text('Tab 2'));
      await tester.pumpAndSettle();

      expect(find.text('Content 2'), findsOneWidget);
    });

    testWidgets('Drawer test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Test App')),
            drawer: const Drawer(
              child: ListTile(
                title: Text('Drawer Item'),
              ),
            ),
            body: const Text('Main Content'),
          ),
        ),
      );

      expect(find.text('Main Content'), findsOneWidget);
      expect(find.text('Drawer Item'), findsNothing);

      // Otvori drawer
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('Drawer Item'), findsOneWidget);
    });
  });
}
