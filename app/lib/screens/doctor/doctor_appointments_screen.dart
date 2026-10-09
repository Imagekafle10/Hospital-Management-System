import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/appointment_tile.dart';
import '../../widgets/common.dart';
import '../shared/appointment_detail_screen.dart';

class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() =>
      _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  String? _statusFilter;

  /// IDs of appointments the doctor has already opened. `null` until loaded
  /// from disk, so we don't flash everything as "new" on startup.
  Set<int>? _seen;

  String get _prefsKey {
    final uid = context.read<AuthProvider>().session?.userId ?? 0;
    return 'seen_appointments_$uid';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppointmentProvider>().fetchMine();
      _loadSeen();
    });
  }

  Future<void> _loadSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_prefsKey) ?? const [];
    if (!mounted) return;
    setState(() => _seen = ids.map(int.parse).toSet());
  }

  Future<void> _markSeen(int id) async {
    final seen = _seen;
    if (seen == null || seen.contains(id)) return;
    setState(() => seen.add(id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _prefsKey, seen.map((e) => e.toString()).toList());
  }

  bool _isNew(Appointment a) => _seen != null && !_seen!.contains(a.id);

  /// Unopened appointments first (most recently booked on top); the rest keep
  /// the provider's existing order.
  List<Appointment> _ordered(List<Appointment> input) {
    final fresh = input.where(_isNew).toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    final opened = input.where((a) => !_isNew(a));
    return [...fresh, ...opened];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentProvider>();
    final filtered = _statusFilter == null
        ? provider.appointments
        : provider.appointments
            .where((a) => a.status == _statusFilter)
            .toList();
    final list = _ordered(filtered);

    return Scaffold(
      appBar: AppBar(title: const Text('Swosthya')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _Chip(
                      label: 'All',
                      selected: _statusFilter == null,
                      onTap: () => setState(() => _statusFilter = null)),
                  ...AppointmentStatus.all.map((s) => _Chip(
                        label: s,
                        selected: _statusFilter == s,
                        onTap: () => setState(() => _statusFilter = s),
                      )),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.fetchMine(),
              child: _buildBody(provider, list),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppointmentProvider provider, List<Appointment> list) {
    if (provider.loading && provider.appointments.isEmpty) {
      return const LoadingView();
    }
    if (provider.error != null && provider.appointments.isEmpty) {
      return ErrorView(
          message: provider.error!, onRetry: () => provider.fetchMine());
    }
    if (list.isEmpty) {
      return const EmptyView(
        message: 'No appointments in this filter.',
        icon: Icons.event_available_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final a = list[i];
        final isNew = _isNew(a);
        final tile = AppointmentTile(
          appointment: a,
          title: a.patientName ?? 'Patient',
          onTap: () {
            _markSeen(a.id);
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => AppointmentDetailScreen(appointment: a)),
            );
          },
        );
        if (!isNew) return tile;
        return Stack(
          children: [
            tile,
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('NEW',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFDCE6E5)),
      ),
    );
  }
}
