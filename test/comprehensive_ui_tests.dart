import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Import real UI components
import '../lib/models/putnik.dart';
import '../lib/widgets/putnik_card.dart';
// Import test helper
import 'test_supabase_setup.dart';

void main() {
  group('🎮 COMPREHENSIVE UI COMPONENTS TESTS', () {
    setUpAll(() async {
      // Initialize real Supabase connection
      await TestSupabaseSetup.initialize();
    });

    testWidgets('📱 Basic Widget Structure Test', (WidgetTester tester) async {
      // Test basic Material App structure
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Test Screen')),
            body: const Center(
              child: Text('Test Content'),
            ),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Test basic screen structure
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Test Screen'), findsOneWidget);
      expect(find.text('Test Content'), findsOneWidget);

      print('✅ Basic widget structure test passed');
    });

    testWidgets('🎯 PutnikCard Widget Test', (WidgetTester tester) async {
      // Create test putnik with required fields
      final testPutnik = Putnik(
        id: 'test-123',
        ime: 'Test',
        polazak: 'Test polazak',
        dan: 'ponedeljak',
        grad: 'Test grad',
        adresa: 'Test adresa',
        brojTelefona: '123456789',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PutnikCard(
              putnik: testPutnik,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test that PutnikCard is rendered
      expect(find.byType(PutnikCard), findsOneWidget);
      expect(find.text('Test'), findsOneWidget);

      print('✅ PutnikCard widget test passed');
    });

    testWidgets('🔄 Widget Interaction Test', (WidgetTester tester) async {
      bool buttonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {
                buttonPressed = true;
              },
              child: const Text('Test Button'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the button
      expect(find.text('Test Button'), findsOneWidget);
      await tester.tap(find.text('Test Button'));
      await tester.pumpAndSettle();

      // Verify button was pressed
      expect(buttonPressed, isTrue);

      print('✅ Widget interaction test passed');
    });

    testWidgets('📋 ListView Rendering Test', (WidgetTester tester) async {
      final testItems = ['Item 1', 'Item 2', 'Item 3'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: testItems.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(testItems[index]),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test ListView and its items
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(3));

      for (final item in testItems) {
        expect(find.text(item), findsOneWidget);
      }

      print('✅ ListView rendering test passed');
    });

    testWidgets('🎨 Theme and Styling Test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            primarySwatch: Colors.blue,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('Themed App')),
            body: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Styled Content'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test themed components
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Themed App'), findsOneWidget);
      expect(find.text('Styled Content'), findsOneWidget);

      print('✅ Theme and styling test passed');
    });

    testWidgets('📱 Responsive Layout Test', (WidgetTester tester) async {
      // Test different screen sizes
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    Container(
                      width: constraints.maxWidth,
                      height: 100,
                      color: Colors.blue,
                      child: const Center(
                        child: Text('Header'),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: constraints.maxWidth,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Text('Content Area'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test responsive components
      expect(find.byType(LayoutBuilder), findsOneWidget);
      expect(find.text('Header'), findsOneWidget);
      expect(find.text('Content Area'), findsOneWidget);

      print('✅ Responsive layout test passed');
    });

    testWidgets('🔍 Search and Filter Test', (WidgetTester tester) async {
      final searchController = TextEditingController();
      final items = ['Apple', 'Banana', 'Cherry', 'Date'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                  ),
                  onChanged: (value) {
                    // Handle search query change
                    print('Search query: $value');
                  },
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(items[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test search field
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search...'), findsOneWidget);

      // Test typing in search field
      await tester.enterText(find.byType(TextField), 'Apple');
      await tester.pumpAndSettle();

      expect(find.text('Apple'), findsNWidgets(2)); // One in list, one in search field

      print('✅ Search and filter test passed');
    });

    testWidgets('🏗️ Form Validation Test', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      final nameController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: nameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Name',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      formKey.currentState?.validate();
                    },
                    child: const Text('Validate'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test form validation
      expect(find.byType(Form), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);

      // Trigger validation with empty field
      await tester.tap(find.text('Validate'));
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.text('Name is required'), findsOneWidget);

      print('✅ Form validation test passed');
    });

    testWidgets('🎭 Animation Test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 100,
              height: 100,
              color: Colors.blue,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test animated container
      expect(find.byType(AnimatedContainer), findsOneWidget);

      print('✅ Animation test passed');
    });

    testWidgets('🔧 Custom Widget Test', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTestWidget(
              title: 'Custom Title',
              subtitle: 'Custom Subtitle',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test custom widget
      expect(find.byType(CustomTestWidget), findsOneWidget);
      expect(find.text('Custom Title'), findsOneWidget);
      expect(find.text('Custom Subtitle'), findsOneWidget);

      print('✅ Custom widget test passed');
    });
  });
}

// Custom test widget for testing
class CustomTestWidget extends StatelessWidget {
  const CustomTestWidget({
    Key? key,
    required this.title,
    required this.subtitle,
  }) : super(key: key);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
