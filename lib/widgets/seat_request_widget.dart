import 'package:flutter/material.dart';

import '../config/route_config.dart';
import '../services/seat_request_service.dart';
import '../services/theme_manager.dart';
import '../utils/schedule_utils.dart';

/// 🎫 SEAT REQUEST WIDGET
/// Widget za slanje zahteva za mesto u kombiju (fleksibilni putnici)
/// Prikazuje dostupnost termina i omogućava slanje zahteva

class SeatRequestWidget extends StatefulWidget {
  final String putnikId;
  final String? putnikIme;
  final String grad; // 'BC' ili 'VS'
  final DateTime datum;
  final VoidCallback? onRequestSent;

  const SeatRequestWidget({
    Key? key,
    required this.putnikId,
    this.putnikIme,
    required this.grad,
    required this.datum,
    this.onRequestSent,
  }) : super(key: key);

  @override
  State<SeatRequestWidget> createState() => _SeatRequestWidgetState();
}

class _SeatRequestWidgetState extends State<SeatRequestWidget> {
  bool _isLoading = true;
  String? _selectedTime;
  Map<String, SeatAvailabilityResult> _availability = {};
  SeatRequest? _existingRequest;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Proveri da li već postoji zahtev za ovaj dan
      final existing = await SeatRequestService.getExistingRequest(
        putnikId: widget.putnikId,
        grad: widget.grad,
        datum: widget.datum,
      );

      // 2. Učitaj dostupnost za sva vremena
      final jeZimski = isZimski(widget.datum);
      final vremena = widget.grad == 'BC'
          ? (jeZimski ? RouteConfig.bcVremenaZimski : RouteConfig.bcVremenaLetnji)
          : (jeZimski ? RouteConfig.vsVremenaZimski : RouteConfig.vsVremenaLetnji);

      final availabilityMap = <String, SeatAvailabilityResult>{};
      for (final vreme in vremena) {
        final result = await SeatRequestService.checkAvailability(
          grad: widget.grad,
          datum: widget.datum,
          vreme: vreme,
        );
        if (result != null) {
          availabilityMap[vreme] = result;
        }
      }

      if (mounted) {
        setState(() {
          _existingRequest = existing;
          _availability = availabilityMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Greška pri učitavanju: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendRequest() async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izaberite vreme polaska')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final request = await SeatRequestService.createRequest(
        putnikId: widget.putnikId,
        putnikIme: widget.putnikIme,
        grad: widget.grad,
        datum: widget.datum,
        zeljenoVreme: _selectedTime!,
      );

      if (request != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                request.status == SeatRequestStatus.approved
                    ? '✅ Zahtev odobren za $_selectedTime'
                    : '⏳ Zahtev poslat - čeka odobrenje',
              ),
              backgroundColor: request.status == SeatRequestStatus.approved ? Colors.green : Colors.orange,
            ),
          );
          widget.onRequestSent?.call();
          await _loadData(); // Refresh
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelRequest() async {
    if (_existingRequest == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Otkaži zahtev?'),
        content: const Text('Da li ste sigurni da želite da otkažete zahtev?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ne'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Da', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final success = await SeatRequestService.updateRequestStatus(
        requestId: _existingRequest!.id!,
        status: SeatRequestStatus.cancelled,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zahtev otkazan'), backgroundColor: Colors.orange),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: ThemeManager().currentGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_seat, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🎫 Zatraži mesto',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.grad} • ${widget.datum.day}.${widget.datum.month}.${widget.datum.year}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadData,
                ),
              ],
            ),
          ),

          // Content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Colors.white),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          else if (_existingRequest != null)
            _buildExistingRequestView()
          else
            _buildTimeSelectionView(),
        ],
      ),
    );
  }

  /// Prikaz postojećeg zahteva
  Widget _buildExistingRequestView() {
    final req = _existingRequest!;
    final statusColor = _getStatusColor(req.status);
    final statusText = _getStatusText(req.status);
    final statusIcon = _getStatusIcon(req.status);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Vreme info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.access_time, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      req.dodeljenoVreme ?? req.zeljenoVreme,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (req.dodeljenoVreme != null && req.dodeljenoVreme != req.zeljenoVreme)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Traženo: ${req.zeljenoVreme}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 🔔 Prikaz alternativa za needsChoice status
          if (req.status == SeatRequestStatus.needsChoice && req.alternatives != null && req.alternatives!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚠️ Termin popunjen! Izaberi alternativu:',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                // Dugmići za alternative
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final alt in req.alternatives!)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ElevatedButton(
                            onPressed: () => _chooseAlternative(alt),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(alt, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Dugme za čekanje originalnog termina
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _chooseWaitlist(),
                    icon: const Icon(Icons.hourglass_empty, color: Colors.orange),
                    label:
                        Text('Čekaj ${req.zeljenoVreme} (lista čekanja)', style: const TextStyle(color: Colors.orange)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),

          // Dugme za otkazivanje
          if (req.status == SeatRequestStatus.pending || req.status == SeatRequestStatus.approved)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cancelRequest,
                icon: const Icon(Icons.cancel, color: Colors.red),
                label: const Text('Otkaži zahtev', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Putnik bira alternativni termin
  Future<void> _chooseAlternative(String izabranoVreme) async {
    if (_existingRequest == null) return;

    setState(() => _isLoading = true);

    try {
      final success = await SeatRequestService.chooseAlternative(
        requestId: _existingRequest!.id!,
        izabranoVreme: izabranoVreme,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Izabrano vreme: $izabranoVreme'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Putnik bira da čeka originalni termin (lista čekanja)
  Future<void> _chooseWaitlist() async {
    if (_existingRequest == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lista čekanja?'),
        content: Text(
          'Ako izabereš listu čekanja, bićeš obavešten ako se oslobodi mesto za ${_existingRequest!.zeljenoVreme}.\n\n'
          'Napomena: Nije garantovano da će se mesto osloboditi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Čekaj'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final success = await SeatRequestService.chooseAlternative(
        requestId: _existingRequest!.id!,
        izabranoVreme: null, // null = waitlist
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏳ Dodat na listu čekanja'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Prikaz izbora vremena
  Widget _buildTimeSelectionView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Izaberite vreme polaska:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // Grid vremena
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availability.entries.map((entry) {
              final vreme = entry.key;
              final result = entry.value;
              final isSelected = _selectedTime == vreme;
              final hasSpace = result.imaMesta;

              return GestureDetector(
                onTap: hasSpace ? () => setState(() => _selectedTime = vreme) : null,
                child: Container(
                  width: 85,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : hasSpace
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.red.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.white.withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        vreme,
                        style: TextStyle(
                          color: isSelected ? Colors.blue : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasSpace ? '${result.slobodnoMesta} slobodno' : 'Popunjeno',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.blue.shade300
                              : hasSpace
                                  ? Colors.green.shade200
                                  : Colors.red.shade200,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Dugme za slanje
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedTime != null ? _sendRequest : null,
              icon: const Icon(Icons.send),
              label: const Text('Pošalji zahtev'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(SeatRequestStatus status) {
    switch (status) {
      case SeatRequestStatus.approved:
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

  String _getStatusText(SeatRequestStatus status) {
    switch (status) {
      case SeatRequestStatus.approved:
        return 'ODOBRENO ✓';
      case SeatRequestStatus.confirmed:
        return 'POTVRĐENO ✓';
      case SeatRequestStatus.pending:
        return 'ČEKA ODOBRENJE';
      case SeatRequestStatus.needsChoice:
        return 'IZABERI TERMIN';
      case SeatRequestStatus.waitlist:
        return 'LISTA ČEKANJA';
      case SeatRequestStatus.cancelled:
        return 'OTKAZANO';
      case SeatRequestStatus.expired:
        return 'ISTEKLO';
    }
  }

  IconData _getStatusIcon(SeatRequestStatus status) {
    switch (status) {
      case SeatRequestStatus.approved:
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
