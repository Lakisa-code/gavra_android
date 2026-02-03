import 'package:flutter/material.dart';

import '../services/ml_champion_service.dart';
import '../services/ml_dispatch_autonomous_service.dart';
import '../services/ml_finance_autonomous_service.dart';
import '../services/ml_vehicle_autonomous_service.dart';
import '../services/vozila_service.dart';
import 'ml_dnevnik_screen.dart';

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
    _tabController = TabController(length: 9, vsync: this);
    MLChampionService().addListener(_onChampionUpdate);
    MLFinanceAutonomousService().addListener(_onFinanceUpdate);
    MLDispatchAutonomousService().addListener(_onDispatchUpdate);
    MLVehicleAutonomousService().addListener(_onVehicleUpdate);
  }

  void _onChampionUpdate() {
    if (mounted) setState(() {});
  }

  void _onFinanceUpdate() {
    if (mounted) setState(() {});
  }

  void _onDispatchUpdate() {
    if (mounted) setState(() {});
  }

  void _onVehicleUpdate() {
    if (mounted) setState(() {});
  }

  // --- AUTOPILOT TOGGLES ---
  void _toggleDispatchAutopilot(bool val) {
    setState(() {
      MLDispatchAutonomousService().toggleAutopilot(val);
    });
  }

  void _toggleChampionAutopilot(bool val) {
    setState(() {
      MLChampionService().toggleAutopilot(val);
    });
  }

  void _toggleFinanceAutopilot(bool val) {
    setState(() {
      MLFinanceAutonomousService().toggleAutopilot(val);
    });
  }

  @override
  void dispose() {
    MLChampionService().removeListener(_onChampionUpdate);
    MLFinanceAutonomousService().removeListener(_onFinanceUpdate);
    MLDispatchAutonomousService().removeListener(_onDispatchUpdate);
    MLVehicleAutonomousService().removeListener(_onVehicleUpdate);
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
            Tab(icon: Icon(Icons.local_shipping), text: 'Vozači'),
            Tab(icon: Icon(Icons.engineering), text: 'Radnici'),
            Tab(icon: Icon(Icons.school), text: 'Učenici'),
            Tab(icon: Icon(Icons.calendar_today), text: 'Dnevni'),
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
          const MLDnevnikScreen(showOnlyVozaci: true),
          const MLDnevnikScreen(showOnlyPutnici: true, onlyType: 'radnik'),
          const MLDnevnikScreen(showOnlyPutnici: true, onlyType: 'ucenik'),
          const MLDnevnikScreen(showOnlyPutnici: true, onlyType: 'dnevni'),
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
                            const Text('HYBRID NEURAL LINK ACTIVE 🧠🔗',
                                style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
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

          _buildBabyTalkPanel('Fizičar kaže:', [
            'Primećujem korelacije između brzine i potrošnje. 📉',
            if (knowledge['correlations'] != null)
              'Našao sam ${(knowledge['correlations'] as Map).length} zanimljivih veza u podacima. 🔗',
            'Svemir (baza podataka) se širi, pratim nove objekte. 🌌',
          ]),
          const SizedBox(height: 24),

          // 📜 KNJIGA BEBA-LOGIKE (FIZIČAR)
          if (inferences.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Knjiga Beba-Logike (Fizičar)',
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
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${inference.timestamp.hour}:${inference.timestamp.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              height: 2,
                              width: 100,
                              decoration: BoxDecoration(
                                color: _getInferenceColor(inference.type).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(1),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: inference.probability,
                                child: Container(color: _getInferenceColor(inference.type)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],

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
        ],
      ),
    );
  }

  Color _getFuelColor(double liters) {
    if (liters < 100) return Colors.redAccent;
    if (liters < 300) return Colors.orangeAccent;
    return Colors.greenAccent;
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
          // 🤖 AUTOPILOT CONTROL
          Card(
            color: service.isAutopilotEnabled ? Colors.green.shade50 : Colors.blueGrey.shade50,
            child: SwitchListTile(
              title: const Text('100% AUTONOMIJA (Autopilot)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(service.isAutopilotEnabled
                  ? 'Beba sama donosi odluke i rešava probleme.'
                  : 'Beba samo daje savete. Ti odlučuješ.'),
              value: service.isAutopilotEnabled,
              activeColor: Colors.green,
              onChanged: _toggleDispatchAutopilot,
              secondary: Icon(
                service.isAutopilotEnabled ? Icons.auto_mode : Icons.pan_tool,
                color: service.isAutopilotEnabled ? Colors.green : Colors.blueGrey,
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MALI DISPEČER', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('100% AUTONOMNA (Data Flow)',
                            style: TextStyle(fontSize: 10, color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
                        Text('Naučeni afiniteti: ${service.learnedAffinityCount.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 📜 KNJIGA BEBA-LOGIKE (DISPEČER)
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber),
              SizedBox(width: 8),
              Text('Knjiga Beba-Logike (Dispečer)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          if (advices.isEmpty)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(40),
              child: Text('Nema kritičnih gužvi za sada. Tabela je čista.'),
            ))
          else
            ...advices.map((DispatchAdvice advice) => Card(
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
                        const SizedBox(height: 4),
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
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {}, // Akcija će zavisiti od tipa saveta
                          style: ElevatedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text(advice.action, style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    trailing: Text(
                      '${advice.timestamp.hour}:${advice.timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  /// Tab 3: Champion (Passenger Reputation)
  Widget _buildChampionTab() {
    final MLChampionService service = MLChampionService();
    final List<PassengerStats> legends = service.topLegends;
    final List<PassengerStats> problematic = service.problematicOnes;
    final List<PassengerStats> anomalies = service.anomalies;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🤖 AUTOPILOT CONTROL
          Card(
            color: service.isAutopilotEnabled ? Colors.amber.shade50 : Colors.blueGrey.shade50,
            child: SwitchListTile(
              title: const Text('100% AUTONOMIJA (Autopilot)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(service.isAutopilotEnabled
                  ? 'Beba sama šalje poruke i nagrađuje putnike.'
                  : 'Beba samo predlaže poruke. Ti ih šalješ.'),
              value: service.isAutopilotEnabled,
              activeColor: Colors.amber,
              onChanged: _toggleChampionAutopilot,
              secondary: Icon(
                service.isAutopilotEnabled ? Icons.auto_awesome : Icons.pan_tool,
                color: service.isAutopilotEnabled ? Colors.amber : Colors.blueGrey,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 🏆 CHAMPION STATUS CARD
          Card(
            color: Colors.amber.shade50,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.stars, size: 40, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ŠAMPION (COMMUNITY AI)', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('HYBRID (Stats + Reputation)',
                            style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'Srednji skor: ${service.globalMeanScore.toStringAsFixed(2)} (±${service.globalStdDev.toStringAsFixed(2)})',
                          style: TextStyle(fontSize: 10, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          _buildBabyTalkPanel('Šampion kaže:', [
            'Danas su svi bili dobri, ponosan sam! 👶',
            if (service.proposedMessages.isNotEmpty)
              'Imam ${service.proposedMessages.length} predloženih poruka koje čekaju tvoj AMIN. 📝',
            if (anomalies.isNotEmpty)
              'Primetio sam anomalije kod ${anomalies.length} putnika. Možda planiraju bekstvo? 🧐',
          ]),
          const SizedBox(height: 24),

          // 📜 KNJIGA BEBA-LOGIKE (ŠAMPION)
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber),
              SizedBox(width: 8),
              Text('Knjiga Beba-Logike (Šampion)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),

          if (service.proposedMessages.isEmpty && anomalies.isEmpty)
            const Center(child: Text('Knjiga je trenutno prazna. Svi su uzorni građani!'))
          else ...[
            if (service.proposedMessages.isNotEmpty) ...[
              const Text('Predložene Poruke:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              ...service.proposedMessages.map((msg) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.chat_bubble_outline, color: Colors.purple),
                      title: Text('Za: ${msg.userName}',
                          overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kontekst: ${msg.context}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text('"${msg.message}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.check, size: 14),
                                label: const Text('Odobri', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.withOpacity(0.1),
                                  foregroundColor: Colors.green,
                                  elevation: 0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.close, size: 14),
                                label: const Text('Odbij', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.withOpacity(0.1),
                                  foregroundColor: Colors.red,
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Text(
                        '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )),
            ],
            if (anomalies.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Detektovane Anomalije:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              ...anomalies.map((p) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.psychology, color: Colors.orange),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          'Cancel Rate: ${((p.cancellations / (p.totalTrips + p.cancellations)) * 100).toStringAsFixed(0)}%'),
                      trailing: const Text('Anomalija',
                          style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                  )),
            ],
          ],

          const Divider(height: 40),
          const Text('Top Legende (Izvanredni)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 8),
          if (legends.isEmpty)
            const Text('Svi su u proseku. Nema ekstrema.', style: TextStyle(fontStyle: FontStyle.italic))
          else
            ...legends.map((PassengerStats p) => ListTile(
                  leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100, child: const Icon(Icons.person, color: Colors.green)),
                  title: Text(p.name),
                  subtitle: Text('Skor: ${p.score.toStringAsFixed(1)} | Vožnji: ${p.totalTrips}'),
                  trailing: const Icon(Icons.verified, color: Colors.green),
                )),
          if (problematic.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Statistički Problematični',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            const Text('Putnici koji su značajno ispod proseka zajednice.',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            ...problematic.map((PassengerStats p) => ListTile(
                  leading: CircleAvatar(
                      backgroundColor: Colors.red.shade100, child: const Icon(Icons.person, color: Colors.red)),
                  title: Text(p.name),
                  subtitle: Text('Skor: ${p.score.toStringAsFixed(1)} | Otkazano: ${p.cancellations}'),
                  trailing: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                )),
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
          // 🆕 HYBRID HEADER
          Row(
            children: [
              const Icon(Icons.account_balance, color: Colors.green),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BEBA RAČUNOVOĐA', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('HYBRID (Finance + Physics)',
                      style: TextStyle(fontSize: 10, color: Colors.green.shade900, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 🤖 AUTOPILOT CONTROL
          Card(
            color: service.isAutopilotEnabled ? Colors.green.shade50 : Colors.blueGrey.shade50,
            child: SwitchListTile(
              title: const Text('100% AUTONOMIJA (Autopilot)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(service.isAutopilotEnabled
                  ? 'Beba sama prati dugove i upozorava admine.'
                  : 'Beba samo predlaže radnje. Ti odlučuješ.'),
              value: service.isAutopilotEnabled,
              activeColor: Colors.green,
              onChanged: _toggleFinanceAutopilot,
              secondary: Icon(
                service.isAutopilotEnabled ? Icons.auto_mode : Icons.pan_tool,
                color: service.isAutopilotEnabled ? Colors.green : Colors.blueGrey,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 💰 STVARNO STANJE (FINANCE)
          Card(
            elevation: 8,
            shadowColor: Colors.green.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                    colors: [Colors.green.shade800, Colors.black87],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              child: Column(
                children: [
                  // 1. DUG
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TRENUTNI DUG',
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                          Text('${inventory.totalDebt.toStringAsFixed(0)} din',
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(
                        onPressed: () => service.reconstructFinancialState(),
                        icon: const Icon(Icons.sync, color: Colors.greenAccent),
                        tooltip: 'Osveži',
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 30),
                  // 2. ZALIHE LARI
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NA STANJU (ZALIHE)',
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text('${inventory.litersInStock.toStringAsFixed(1)} L',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 3. BROJČANIK ZALIHA (VIZUELNO)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (inventory.litersInStock / inventory.maxCapacity).clamp(0.0, 1.0),
                          backgroundColor: Colors.white10,
                          color: _getFuelColor(inventory.litersInStock),
                          minHeight: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                          'Procenat popunjenosti: ${((inventory.litersInStock / inventory.maxCapacity) * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white38, fontSize: 10)),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 3,
                child: _buildActionCard(
                  'Nabavka',
                  Icons.add_shopping_cart,
                  Colors.blue,
                  () => _showBulkPurchaseDialog(context, service),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 3,
                child: _buildActionCard(
                  'Sipanje',
                  Icons.local_gas_station,
                  Colors.purple,
                  () => _showVanRefillDialog(context, service),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 3,
                child: _buildActionCard(
                  'Isplata',
                  Icons.payment,
                  Colors.orange,
                  () => _showPaymentDialog(context, service),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 3,
                child: _buildActionCard(
                  'Kalibracija',
                  Icons.tune,
                  Colors.red,
                  () => _showCalibrationDialog(context, service),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 📜 SAVETI BEBE RAČUNOVEĐE
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.amber),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Knjiga Beba-Logike',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
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

  Future<void> _showBulkPurchaseDialog(BuildContext context, MLFinanceAutonomousService service) async {
    final litersController = TextEditingController();
    final priceController = TextEditingController(text: service.inventory.fuelPrice.toString());

    await showDialog<dynamic>(
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
              final priceInput = double.tryParse(priceController.text);
              final price = (priceInput == null || priceInput == 0) ? null : priceInput;

              if (liters > 0) {
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

  Future<void> _showPaymentDialog(BuildContext context, MLFinanceAutonomousService service) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    await showDialog<dynamic>(
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

  Future<void> _showVanRefillDialog(BuildContext context, MLFinanceAutonomousService service) async {
    final litersController = TextEditingController();
    final kmController = TextEditingController();
    final pumpController = TextEditingController();
    String? selectedVehicleId;
    bool isMultiRefill = false;
    final List<String> selectedVehicleIds = [];

    // Preuzmi poslednje stanje brojila za prikaz
    final lastMeter = service.lastPumpMeter;

    await showDialog<dynamic>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isMultiRefill ? 'Višestruko sipanje (Grupno)' : 'Sipanje u kombi (Sa stanja)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Više kombija odjednom'),
                  subtitle: const Text('Sipao sam u 2+ kombija u gužvi'),
                  value: isMultiRefill,
                  onChanged: (val) {
                    setDialogState(() {
                      isMultiRefill = val;
                      selectedVehicleIds.clear();
                      selectedVehicleId = null;
                    });
                  },
                ),
                const Divider(),
                StreamBuilder<List<Vozilo>>(
                  stream: VozilaService.streamVozila(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    final vozila = snapshot.data!;

                    if (isMultiRefill) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Izaberi kombije:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: vozila.map((v) {
                              final isSelected = selectedVehicleIds.contains(v.id);
                              return FilterChip(
                                label: Text(v.registarskiBroj),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setDialogState(() {
                                    if (selected) {
                                      selectedVehicleIds.add(v.id);
                                    } else {
                                      selectedVehicleIds.remove(v.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    }

                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Izaberi kombi'),
                      items: vozila.map((v) {
                        return DropdownMenuItem(
                          value: v.id,
                          child: Text(v.registarskiBroj),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedVehicleId = val;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (!isMultiRefill)
                  TextField(
                      controller: kmController,
                      decoration: const InputDecoration(labelText: 'Kilometar sat (kombi)', hintText: 'npr. 254300'),
                      keyboardType: TextInputType.number),
                TextField(
                    controller: pumpController,
                    decoration: InputDecoration(
                      labelText: 'Novo stanje brojila (pumpa)',
                      hintText: 'Zadnja cifra na satu zaliha',
                      helperText: lastMeter != null ? 'Prethodno stanje: ${lastMeter.toStringAsFixed(1)}L' : null,
                    ),
                    keyboardType: TextInputType.number),
                if (!isMultiRefill)
                  TextField(
                      controller: litersController,
                      decoration: const InputDecoration(labelText: 'Litara (L)', hintText: 'npr. 50'),
                      keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Odustani')),
            ElevatedButton(
              onPressed: () async {
                final pump = double.tryParse(pumpController.text);

                if (isMultiRefill) {
                  // MULTI REFILL LOGIC
                  if (selectedVehicleIds.isEmpty) return;
                  if (pump == null) return;

                  try {
                    await service.recordMultiVanRefill(
                      vehicleIds: selectedVehicleIds,
                      newPumpMeter: pump,
                    );
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Greška: ${e.toString().replaceAll('Exception: ', '')}')),
                      );
                    }
                  }
                } else {
                  // SINGLE REFILL LOGIC
                  final liters = double.tryParse(litersController.text) ?? 0;
                  final km = double.tryParse(kmController.text);
                  if (liters > 0 && selectedVehicleId != null) {
                    service.recordVanRefill(
                      vehicleId: selectedVehicleId!,
                      liters: liters,
                      km: km,
                      pumpMeter: pump,
                    );
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Sipano!'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCalibrationDialog(BuildContext context, MLFinanceAutonomousService service) async {
    final litersController = TextEditingController(text: service.inventory.litersInStock.toString());
    final debtController = TextEditingController(text: service.inventory.totalDebt.toString());

    await showDialog<dynamic>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.tune, color: Colors.red),
            SizedBox(width: 8),
            Text('Ručna Kalibracija'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Unesi trenutno "stvarno" stanje (okvirno). Beba će odavde nastaviti učenje.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
                controller: litersController,
                decoration: const InputDecoration(labelText: 'Stvarne Zalihe (L)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextField(
                controller: debtController,
                decoration: const InputDecoration(labelText: 'Stvarni Dug (din)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Odustani')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
            onPressed: () {
              final liters = double.tryParse(litersController.text);
              final debt = double.tryParse(debtController.text);
              setState(() {
                service.calibrate(liters: liters, debt: debt);
              });
              Navigator.pop(context);
            },
            child: const Text('KALIBRIŠI'),
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
            'Globalna Podešavanja Lab-a',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Omogući Predviđanja'),
                  subtitle: const Text('Live analize i predviđanja budućih događaja.'),
                  value: _enablePredictions,
                  onChanged: (val) => setState(() => _enablePredictions = val),
                  secondary: const Icon(Icons.bolt, color: Colors.amber),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Automatski Trening'),
                  subtitle: const Text('Redovno ažuriranje neuronskih mreža.'),
                  value: _autoTrain,
                  onChanged: (val) => setState(() => _autoTrain = val),
                  secondary: const Icon(Icons.model_training, color: Colors.blue),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Prikupljanje Podataka'),
                  subtitle: const Text('Učenje iz akcija u realnom vremenu.'),
                  value: _collectData,
                  onChanged: (val) => setState(() => _collectData = val),
                  secondary: const Icon(Icons.storage, color: Colors.green),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sistemska Dijagnostika',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.memory, color: Colors.purple),
            title: const Text('Status Neuronskih Linkova'),
            subtitle: const Text('Svi čvorovi operativni (Hybrid Mode)'),
            trailing: const Icon(Icons.check_circle, color: Colors.green),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.red),
            title: const Text('Očisti AI Cache'),
            subtitle: const Text('Resetuje kratkoročnu memoriju beba-logike.'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI Cache očišćen! 🧼')),
              );
            },
          ),
        ],
      ),
    );
  }
}
