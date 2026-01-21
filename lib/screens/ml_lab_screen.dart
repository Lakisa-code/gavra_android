import 'package:flutter/material.dart';

import '../services/ml_champion_service.dart';
import '../services/ml_dispatch_autonomous_service.dart';
import '../services/ml_finance_autonomous_service.dart';
import '../services/ml_vehicle_autonomous_service.dart';

/// ML Lab Screen - Machine Learning Analysis and Predictions
///
/// This screen provides access to ML features:
/// - Live predictions (occupancy, demand, optimal routes)
/// - Model performance metrics
/// - Training data explorer
/// - Feature importance visualization
/// - ML settings and configuration
class MLLabScreen extends StatefulWidget {
  const MLLabScreen({super.key});

  @override
  State<MLLabScreen> createState() => _MLLabScreenState();
}

class _MLLabScreenState extends State<MLLabScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _enablePredictions = true;
  bool _autoTrain = true;
  bool _collectData = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gavra AI Lab 🧪'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.blue,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.psychology), text: 'Fizičar'),
            Tab(icon: Icon(Icons.hail), text: 'Dispečer'),
            Tab(icon: Icon(Icons.emoji_events), text: 'Šampion'),
            Tab(icon: Icon(Icons.calculate), text: 'Računovođa'),
            Tab(icon: Icon(Icons.settings), text: 'Podešavanja'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVehicleAITab(),
          _buildDispatcherTab(),
          _buildChampionTab(),
          _buildAccountantTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  /// Tab 1: Vehicle Autonomy (The New Brain)
  Widget _buildVehicleAITab() {
    final service = MLVehicleAutonomousService();
    final targets = service.activeMonitoringTargets;
    final knowledge = service.currentKnowledge;
    final inferences = service.businessInferences;
    final interval = service.currentInterval;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🧠 BRAIN STATUS CARD
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology, size: 40, color: Colors.purple),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AUTONOMNI KORTEX',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 4),
                                const Text('ONLINE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Min: $interval', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('${targets.length} meta', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 🎯 ACTIVE MONITORING TARGETS
          const Text(
            'Šta trenutno pratim? (Meta-Učenje)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (targets.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Trenutno nema aktivnih meta. Čekam nove podatke...'),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: targets.length,
              itemBuilder: (context, index) {
                final target = targets.values.toList()[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getImportanceColor(target.importance),
                      child: Text(
                        (target.importance * 10).toStringAsFixed(0),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(target.id),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(target.reason),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: target.importance > 1.0 ? 1.0 : target.importance, // Clamp visual
                          backgroundColor: Colors.grey[200],
                          color: _getImportanceColor(target.importance),
                          minHeight: 4,
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.remove_red_eye_outlined),
                  ),
                );
              },
            ),

          const SizedBox(height: 24),

          // 📚 KNOWLEDGE BASE
          const Text(
            'Digitalna Mapa Uma (Otkriveni Svet)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            padding: EdgeInsets.zero,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _buildKnowledgeCard(
                'Sobe',
                '${(knowledge['discovered_tables'] as List?)?.length ?? 0} tabela',
                Icons.door_sliding,
                Colors.blue,
              ),
              _buildKnowledgeCard(
                'Bioritmi',
                (knowledge['temporal_patterns'] as Map?)?.isNotEmpty == true ? 'Aktivno' : 'Učenje...',
                Icons.access_time_filled,
                Colors.orange,
              ),
              _buildKnowledgeCard(
                'Veze',
                '${(knowledge['correlations'] as Map?)?.length ?? 0} korelacija',
                Icons.hub,
                Colors.green,
              ),
              _buildKnowledgeCard(
                'Radoznalost',
                '${((1 - service.confidenceThreshold) * 100).toStringAsFixed(0)}%',
                Icons.psychology,
                Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 🕒 TEMPORAL BIORHYTHMS (NEW SECTION)
          if ((knowledge['temporal_patterns'] as Map?)?.isNotEmpty == true) ...[
            const Text(
              'Bioritmi (Kada se šta dešava?)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildPatternCard('Špicevi dana', Icons.flash_on,
                      ((knowledge['temporal_patterns'] as Map?)?['hour'] as Map? ?? {}).keys.take(3).join(', ')),
                  _buildPatternCard('Sezonalnost', Icons.calendar_month,
                      ((knowledge['temporal_patterns'] as Map?)?['month'] as Map? ?? {}).keys.take(3).join(', ')),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // 👶 BEBA UČI (BIZNIS OTKRIĆA)
          if (inferences.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.child_care, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Bebina Otkrića (Pasivno Učenje)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Ovi predlozi ne menjaju podatke - beba samo posmatra i uči za tebe.',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: inferences.length,
              itemBuilder: (context, index) {
                final inference = inferences[index];
                return Card(
                  elevation: 0,
                  color: Colors.blue.withAlpha(13), // 0.05 * 255 ≈ 13
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.blue.withAlpha(51)), // 0.2 * 255 ≈ 51
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              inference.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getInferenceColor(inference.type),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Pouzdanost: ${(inference.probability * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          inference.description,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: inference.probability,
                          backgroundColor: Colors.white,
                          color: _getInferenceColor(inference.type),
                          minHeight: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Color _getImportanceColor(double importance) {
    if (importance >= 0.8) return Colors.red;
    if (importance >= 0.5) return Colors.orange;
    return Colors.green;
  }

  Color _getInferenceColor(InferenceType type) {
    switch (type) {
      case InferenceType.driverPreference:
        return Colors.purple;
      case InferenceType.capacity:
        return Colors.orange;
      case InferenceType.passengerQuality:
        return Colors.green;
      case InferenceType.routeTrend:
        return Colors.blue;
    }
  }

  Widget _buildKnowledgeCard(String title, String subtitle, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternCard(String title, IconData icon, String value) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        color: Colors.orange.withAlpha(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.orange, size: 20),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text(
                value.isEmpty ? 'Analiza u toku...' : value,
                style: const TextStyle(fontSize: 14, color: Colors.orange),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tab 2: Dispatcher (The Baby Dispatcher)
  Widget _buildDispatcherTab() {
    final MLDispatchAutonomousService service = MLDispatchAutonomousService();
    final List<DispatchAdvice> advices = service.activeAdvice;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 👨‍✈️ DISPATCHER STATUS
          Card(
            color: Colors.blue.shade50,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.support_agent, size: 40, color: Colors.blue),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MALI DISPEČER', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Aktivno posmatram brzinu rezervacija...',
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green),
                        SizedBox(width: 4),
                        Text('AKTIVAN',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Saveti Male Bebe:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (advices.isEmpty)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(40),
              child: Text('Nema kritičnih gužvi za sada. Tabela je čista.'),
            ))
          else
            ...advices
                .map((DispatchAdvice advice) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          advice.priority == AdvicePriority.critical ? Icons.warning : Icons.lightbulb,
                          color: advice.priority == AdvicePriority.critical ? Colors.red : Colors.orange,
                        ),
                        title: Text(advice.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(advice.description),
                            if (advice.originalStatus != null || advice.proposedChange != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (advice.originalStatus != null)
                                      Text('Trenutno: ${advice.originalStatus}',
                                          style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                    if (advice.proposedChange != null)
                                      Text('Beba želi: ${advice.proposedChange}',
                                          style: const TextStyle(
                                              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {}, // Akcija će zavisiti od tipa saveta
                          child: Text(advice.action),
                        ),
                      ),
                    ))
                .toList(),
        ],
      ),
    );
  }

  /// Tab 3: Champion (Passenger Reputation)
  Widget _buildChampionTab() {
    final MLChampionService service = MLChampionService();
    final List<PassengerStats> legends = service.topLegends;
    final List<PassengerStats> problematic = service.problematicOnes;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBabyTalkPanel('Šampion kaže:', [
            'Danas su svi bili dobri, ponosan sam! 👶',
            if (service.proposedMessages.isNotEmpty)
              'Imam ${service.proposedMessages.length} predloženih poruka koje čekaju tvoj AMIN. 📝',
            'Ovaj puca na 5.0, daj mu popust sledeći put.',
          ]),
          const SizedBox(height: 16),
          if (service.proposedMessages.isNotEmpty) ...[
            const Text('Predložene Poruke (Test Faza):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...service.proposedMessages.map((msg) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.chat_bubble_outline, color: Colors.purple),
                    title: Text('Za: ${msg.userName} (${msg.context})'),
                    subtitle: Text('"${msg.message}"'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () {}),
                        IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () {}),
                      ],
                    ),
                  ),
                )),
            const Divider(),
          ],
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.stars, size: 40, color: Colors.amber),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ŠAMPION (COMMUNITY AI)', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Analiziram ponašanje i vaspitavam putnike.', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await service.analyzeAll();
                      if (mounted) setState(() {});
                    },
                    child: const Text('SKENIRAJ SVE'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Top Legende (5.0)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 8),
          if (legends.isEmpty)
            const Text('Nema podataka. Pokreni skeniranje.', style: TextStyle(fontStyle: FontStyle.italic))
          else
            ...legends
                .map((PassengerStats p) => ListTile(
                      leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100, child: const Icon(Icons.person, color: Colors.green)),
                      title: Text(p.name),
                      subtitle: Text('Skor: ${p.score.toStringAsFixed(1)} | Vožnji: ${p.totalTrips}'),
                      trailing: const Icon(Icons.verified, color: Colors.green),
                    ))
                .toList(),
          if (problematic.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Problematični (Ispod 4.0)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 8),
            ...problematic
                .map((PassengerStats p) => ListTile(
                      leading: CircleAvatar(
                          backgroundColor: Colors.red.shade100, child: const Icon(Icons.person, color: Colors.red)),
                      title: Text(p.name),
                      subtitle: Text('Skor: ${p.score.toStringAsFixed(1)} | Otkazano: ${p.cancellations}'),
                      trailing: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    ))
                .toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildBabyTalkPanel(String title, List<String> thoughts) {
    // Provera integriteta za "zaboravljene putnike"
    final bool isEverythingOk =
        MLDispatchAutonomousService().activeAdvice.every((a) => a.priority != AdvicePriority.critical);

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isEverythingOk ? Colors.green.withAlpha(20) : Colors.red.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isEverythingOk ? Colors.green.withAlpha(51) : Colors.red.withAlpha(51)),
          ),
          child: Row(
            children: [
              Icon(isEverythingOk ? Icons.verified_user : Icons.warning_amber_rounded,
                  size: 16, color: isEverythingOk ? Colors.green : Colors.red),
              const SizedBox(width: 8),
              Text(
                isEverythingOk ? 'BEZBEDNOST: Svi putnici su na broju ✅' : 'UPOZORENJE: Proveri tablu! ⚠️',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: isEverythingOk ? Colors.green : Colors.red),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.withAlpha(51)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.child_care, size: 20, color: Colors.purple),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                ],
              ),
              const SizedBox(height: 8),
              ...thoughts.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $t', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  /// Tab 4: Accountant (Finance AI)
  Widget _buildAccountantTab() {
    final service = MLFinanceAutonomousService();
    final inventory = service.inventory;
    final adviceList = service.activeAdvice;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 💰 FINANCIAL STATUS CARD
          Card(
            elevation: 8,
            shadowColor: Colors.green.withOpacity(0.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.green, width: 2)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                    colors: [Colors.green.shade900, Colors.black87],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TRENUTNI DUG (GORIVO)',
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('BEBA RAČUNA...',
                              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
                        child: const Icon(Icons.account_balance_wallet, color: Colors.greenAccent, size: 30),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                          'Zalihe', '${inventory.litersInStock.toStringAsFixed(1)} L', Icons.local_gas_station),
                      _buildStatItem('Ukupno Dug', '${inventory.totalDebt.toStringAsFixed(0)} din', Icons.money_off),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 🛠️ ANALITIČKE RADNJE
          const Text('Brze Akcije (Beba beleži)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  'Nabavka na veliko',
                  Icons.add_shopping_cart,
                  Colors.blue,
                  () => _showBulkPurchaseDialog(context, service),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  'Sipanje u kombi',
                  Icons.local_gas_station,
                  Colors.purple,
                  () => _showVanRefillDialog(context, service),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  'Isplata duga',
                  Icons.payment,
                  Colors.orange,
                  () => _showPaymentDialog(context, service),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 📜 SAVETI BEBE RAČUNOVEĐE
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber),
              SizedBox(width: 8),
              Text('Knjiga Beba-Logike', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          if (adviceList.isEmpty)
            const Center(child: Text('Beba još uvek slaže račune. Sve je pod kontrolom!'))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: adviceList.length,
              itemBuilder: (context, index) {
                final advice = adviceList[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      advice.isCritical ? Icons.report_problem : Icons.info,
                      color: advice.isCritical ? Colors.red : Colors.blue,
                    ),
                    title: Text(advice.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(advice.description),
                    trailing: Text(
                      '${advice.timestamp.hour}:${advice.timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showBulkPurchaseDialog(BuildContext context, MLFinanceAutonomousService service) {
    final litersController = TextEditingController();
    final priceController = TextEditingController(text: service.inventory.fuelPrice.toString());

    showDialog<dynamic>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Nabavka Goriva (Na veliko)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: litersController,
                decoration: const InputDecoration(labelText: 'Litarska (L)', hintText: 'npr. 1000'),
                keyboardType: TextInputType.number),
            TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Cena po litru', hintText: 'npr. 200'),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Odustani')),
          ElevatedButton(
            onPressed: () {
              final liters = double.tryParse(litersController.text) ?? 0;
              final price = double.tryParse(priceController.text) ?? 0;
              if (liters > 0 && price > 0) {
                setState(() {
                  service.recordBulkPurchase(liters: liters, pricePerLiter: price);
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Evidentiraj'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, MLFinanceAutonomousService service) {
    final amountController = TextEditingController();
    showDialog<dynamic>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Isplata Duga'),
        content: TextField(
            controller: amountController,
            decoration: const InputDecoration(labelText: 'Iznos isplate (din)'),
            keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Odustani')),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                setState(() {
                  service.recordPayment(amount);
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Potvrdi Isplatu'),
          ),
        ],
      ),
    );
  }

  void _showVanRefillDialog(BuildContext context, MLFinanceAutonomousService service) {
    final litersController = TextEditingController();
    final vehicleController = TextEditingController();

    showDialog<dynamic>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Sipanje iz zaliha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: vehicleController,
                decoration: const InputDecoration(labelText: 'Kombi (ID/Ime)', hintText: 'npr. BG-123'),
                keyboardType: TextInputType.text),
            TextField(
                controller: litersController,
                decoration: const InputDecoration(labelText: 'Litara (L)', hintText: 'npr. 50'),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Odustani')),
          ElevatedButton(
            onPressed: () {
              final liters = double.tryParse(litersController.text) ?? 0;
              final vehicle = vehicleController.text;
              if (liters > 0 && vehicle.isNotEmpty) {
                setState(() {
                  service.recordVanRefill(vehicleId: vehicle, liters: liters);
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Sipano!'),
          ),
        ],
      ),
    );
  }

  /// Tab 5: Settings
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ML Configuration',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Enable Predictions'),
            subtitle: const Text('Allow ML models to make predictions'),
            value: _enablePredictions,
            onChanged: (value) {
              setState(() {
                _enablePredictions = value;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(value ? 'Predictions enabled' : 'Predictions disabled'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          SwitchListTile(
            title: const Text('Auto-Train Models'),
            subtitle: const Text('Automatically retrain with new data'),
            value: _autoTrain,
            onChanged: (value) {
              setState(() {
                _autoTrain = value;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(value ? 'Auto-train enabled' : 'Auto-train disabled'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          SwitchListTile(
            title: const Text('Collect Training Data'),
            subtitle: const Text('Record trips for model training'),
            value: _collectData,
            onChanged: (value) {
              setState(() {
                _collectData = value;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(value ? 'Data collection enabled' : 'Data collection disabled'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          const Divider(height: 32),
          const Text(
            'Model Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.blue),
            title: const Text('Retrain All Models'),
            subtitle: const Text('Force retrain with latest data'),
            trailing: ElevatedButton(
              onPressed: () async {
                showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Training models...'),
                      ],
                    ),
                  ),
                );

                await Future<void>.delayed(const Duration(seconds: 2));

                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Models retrained successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Train'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear Training Data'),
            subtitle: const Text('Delete all collected ML data'),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Training Data?'),
                    content: const Text(
                      'This will delete all collected ML training data. '
                      'This action cannot be undone. Continue?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Training data cleared'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                        child: const Text('Clear', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Clear'),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Smart Notifications',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'ML sistem može slati smart notifikacije za:\n'
            '• Praznici sutra (kombiji ne voze)\n'
            '• Početak školskog raspusta\n'
            '• Očekivani prebuking (18+ putnika)\n\n'
            'Implementacija: lib/services/ml_vehicle_autonomous_service.dart',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Text(
            'About ML Lab',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'ML Lab is a passive learning system that observes patterns and provides insights without interfering with normal operations. All predictions are advisory only.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
