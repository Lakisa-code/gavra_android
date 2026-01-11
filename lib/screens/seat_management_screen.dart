import 'dart:async';

import 'package:flutter/material.dart';

import '../services/seat_request_service.dart';
import '../services/theme_manager.dart';
import '../widgets/seat_optimization_widget.dart';

/// 🎛️ SEAT MANAGEMENT ADMIN SCREEN
/// Admin ekran za upravljanje zahtevima za mesta
/// Prikazuje sve zahteve, omogućava odobravanje i optimizaciju

class SeatManagementScreen extends StatefulWidget {
  const SeatManagementScreen({Key? key}) : super(key: key);

  @override
  State<SeatManagementScreen> createState() => _SeatManagementScreenState();
}

class _SeatManagementScreenState extends State<SeatManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  String _selectedGrad = 'BC';
  bool _isLoading = false;
  List<SeatRequest> _requests = [];
  StreamSubscription? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRequests();
    _setupRealtime();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtime() {
    _realtimeSubscription = SeatRequestService.streamRequestsForDate(
      grad: _selectedGrad,
      datum: _selectedDate,
    ).listen((requests) {
      if (mounted) {
        setState(() => _requests = requests);
      }
    });
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);

    try {
      final requests = await SeatRequestService.getRequestsForDate(
        grad: _selectedGrad,
        datum: _selectedDate,
      );

      if (mounted) {
        setState(() {
          _requests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onGradChanged(String? grad) {
    if (grad == null || grad == _selectedGrad) return;
    setState(() => _selectedGrad = grad);
    _realtimeSubscription?.cancel();
    _setupRealtime();
    _loadRequests();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date != null && date != _selectedDate) {
      setState(() => _selectedDate = date);
      _realtimeSubscription?.cancel();
      _setupRealtime();
      _loadRequests();
    }
  }

  Future<void> _approveRequest(SeatRequest request) async {
    final success = await SeatRequestService.updateRequestStatus(
      requestId: request.id!,
      status: SeatRequestStatus.approved,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Odobren zahtev za ${request.putnikIme ?? "putnika"}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _rejectRequest(SeatRequest request) async {
    final success = await SeatRequestService.updateRequestStatus(
      requestId: request.id!,
      status: SeatRequestStatus.cancelled,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zahtev odbijen'), backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: ThemeManager().currentGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Filters
              _buildFilters(),

              // Tab bar
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: const [
                  Tab(icon: Icon(Icons.list), text: 'Zahtevi'),
                  Tab(icon: Icon(Icons.auto_fix_high), text: 'Optimizacija'),
                ],
              ),

              // Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRequestsList(),
                    _buildOptimizationView(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Broj pending zahteva
    final pendingCount = _requests.where((r) => r.status == SeatRequestStatus.pending).length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              '🎫 Upravljanje mestima',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // 🤖 Dugme za batch processing
          if (pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: _processBatch,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text('Procesiraj ($pendingCount)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadRequests,
          ),
        ],
      ),
    );
  }

  /// 🤖 Pokreni batch processing
  Future<void> _processBatch() async {
    setState(() => _isLoading = true);

    final result = await SeatRequestService.processPendingBatch(
      specificDate: _selectedDate,
      specificGrad: _selectedGrad,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.hasError
                ? '❌ Greška: ${result.error}'
                : '✅ Procesirano: ${result.approved} odobreno, ${result.waitlisted} na čekanju',
          ),
          backgroundColor: result.hasError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Reload requests
      _loadRequests();
    }
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Grad selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _selectedGrad,
              dropdownColor: Colors.blueGrey,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              style: const TextStyle(color: Colors.white),
              items: const [
                DropdownMenuItem(value: 'BC', child: Text('🏠 Bela Crkva')),
                DropdownMenuItem(value: 'VS', child: Text('🏙️ Vršac')),
              ],
              onChanged: _onGradChanged,
            ),
          ),
          const SizedBox(width: 12),

          // Date selector
          Expanded(
            child: GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, color: Colors.white.withValues(alpha: 0.5), size: 64),
            const SizedBox(height: 16),
            Text(
              'Nema zahteva za ovaj dan',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Grupiši po statusu
    final pending = _requests.where((r) => r.status == SeatRequestStatus.pending).toList();
    final approved = _requests.where((r) => r.status == SeatRequestStatus.approved).toList();
    final waitlist = _requests.where((r) => r.status == SeatRequestStatus.waitlist).toList();
    final other = _requests
        .where((r) =>
            r.status != SeatRequestStatus.pending &&
            r.status != SeatRequestStatus.approved &&
            r.status != SeatRequestStatus.waitlist)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pending
        if (pending.isNotEmpty) ...[
          _buildSectionHeader('⏳ Čekaju odobrenje', pending.length, Colors.orange),
          ...pending.map((r) => _buildRequestCard(r, showActions: true)),
        ],

        // Waitlist
        if (waitlist.isNotEmpty) ...[
          _buildSectionHeader('📋 Lista čekanja', waitlist.length, Colors.yellow.shade700),
          ...waitlist.map((r) => _buildRequestCard(r)),
        ],

        // Approved
        if (approved.isNotEmpty) ...[
          _buildSectionHeader('✅ Odobreni', approved.length, Colors.green),
          ...approved.map((r) => _buildRequestCard(r)),
        ],

        // Other
        if (other.isNotEmpty) ...[
          _buildSectionHeader('📁 Ostali', other.length, Colors.grey),
          ...other.map((r) => _buildRequestCard(r)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(SeatRequest request, {bool showActions = false}) {
    final statusColor = _getStatusColor(request.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Text(
            request.zeljenoVreme.split(':')[0],
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          request.putnikIme ?? 'Nepoznat putnik',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'Traži: ${request.zeljenoVreme}${request.dodeljenoVreme != null ? ' → ${request.dodeljenoVreme}' : ''}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        trailing: showActions
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => _approveRequest(request),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => _rejectRequest(request),
                  ),
                ],
              )
            : Icon(_getStatusIcon(request.status), color: statusColor),
      ),
    );
  }

  Widget _buildOptimizationView() {
    return SingleChildScrollView(
      child: SeatOptimizationWidget(
        grad: _selectedGrad,
        datum: _selectedDate,
        onOptimizationApplied: _loadRequests,
      ),
    );
  }

  Color _getStatusColor(SeatRequestStatus status) {
    switch (status) {
      case SeatRequestStatus.approved:
        return Colors.green;
      case SeatRequestStatus.confirmed:
        return Colors.green;
      case SeatRequestStatus.pending:
        return Colors.orange;
      case SeatRequestStatus.needsChoice:
        return Colors.blue;
      case SeatRequestStatus.waitlist:
        return Colors.yellow.shade700;
      case SeatRequestStatus.cancelled:
        return Colors.grey;
      case SeatRequestStatus.expired:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(SeatRequestStatus status) {
    switch (status) {
      case SeatRequestStatus.approved:
        return Icons.check_circle;
      case SeatRequestStatus.confirmed:
        return Icons.check_circle;
      case SeatRequestStatus.pending:
        return Icons.hourglass_empty;
      case SeatRequestStatus.needsChoice:
        return Icons.touch_app;
      case SeatRequestStatus.waitlist:
        return Icons.queue;
      case SeatRequestStatus.cancelled:
        return Icons.cancel;
      case SeatRequestStatus.expired:
        return Icons.timer_off;
    }
  }
}
