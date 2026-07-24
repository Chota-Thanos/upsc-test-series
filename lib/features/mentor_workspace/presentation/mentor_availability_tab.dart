import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/mentor_workspace_service.dart';
import '../models/mentor_workspace_models.dart';

/// Availability Desk: create single slots or bulk-generate a schedule across a
/// date range, and deactivate existing slots. Mirrors the web workspace
/// "Availability Desk" tab.
class MentorAvailabilityTab extends StatefulWidget {
  final MentorWorkspaceService service;
  final int mentorUserId;

  const MentorAvailabilityTab({
    super.key,
    required this.service,
    required this.mentorUserId,
  });

  @override
  State<MentorAvailabilityTab> createState() => _MentorAvailabilityTabState();
}

class _MentorAvailabilityTabState extends State<MentorAvailabilityTab> {
  List<MentorSlot> _slots = [];
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final slots = await widget.service.getMySlots(widget.mentorUserId);
      if (mounted) setState(() => _slots = slots);
    } catch (e) {
      _toast("Failed to load slots: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _createSingleSlot() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 120)),
    );
    if (date == null || !mounted) return;
    final startTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      helpText: "Start time",
    );
    if (startTime == null || !mounted) return;
    final endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (startTime.hour + 1) % 24, minute: 0),
      helpText: "End time",
    );
    if (endTime == null) return;

    final startsAt = DateTime(
        date.year, date.month, date.day, startTime.hour, startTime.minute);
    final endsAt = DateTime(
        date.year, date.month, date.day, endTime.hour, endTime.minute);
    if (!endsAt.isAfter(startsAt)) {
      _toast("End time must be after start time");
      return;
    }

    setState(() => _creating = true);
    try {
      await widget.service.createSlots([
        {
          'starts_at': startsAt.toUtc().toIso8601String(),
          'ends_at': endsAt.toUtc().toIso8601String(),
          'mode': 'video',
          'max_bookings': 1,
          'title': '1-on-1 UPSC Mentorship',
          'description': 'Video consultation with verified UPSC mentor',
        }
      ]);
      _toast("Slot created");
      await _load();
    } catch (e) {
      _toast("Failed: $e");
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _openBulkGenerator() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BulkSlotSheet(service: widget.service),
    );
    if (created == true) await _load();
  }

  Future<void> _deactivate(MentorSlot slot) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Deactivate slot"),
        content: const Text("Deactivate this availability slot?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Deactivate",
                  style: TextStyle(color: AppColors.berry))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.service.deactivateSlot(slot.id);
      _toast("Slot deactivated");
      await _load();
    } catch (e) {
      _toast("Failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _creating ? null : _createSingleSlot,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Add slot"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.civic,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openBulkGenerator,
                  icon: const Icon(Icons.event_repeat_rounded, size: 18),
                  label: const Text("Bulk generate"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.civic,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text("Your Slots (${_slots.length})",
              style: AppTypography.eyebrowSmall
                  .copyWith(color: AppColors.muted)),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_slots.isEmpty)
            _emptyState()
          else
            ..._slots.map(_slotTile),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined,
              size: 40, color: AppColors.muted),
          const SizedBox(height: 12),
          Text("No slots yet",
              style: AppTypography.cardTitle.copyWith(fontSize: 15)),
          const SizedBox(height: 4),
          Text("Add availability so students can book sessions.",
              textAlign: TextAlign.center, style: AppTypography.caption),
        ],
      ),
    );
  }

  Widget _slotTile(MentorSlot slot) {
    final start = DateTime.tryParse(slot.startsAt)?.toLocal();
    final end = DateTime.tryParse(slot.endsAt)?.toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.civic.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_month_rounded,
                color: AppColors.civic, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  start != null ? _formatDate(start) : slot.startsAt,
                  style:
                      AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  start != null && end != null
                      ? "${_formatTime(start)} - ${_formatTime(end)}"
                      : "",
                  style: AppTypography.caption,
                ),
                if (slot.isBooked)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text("Booked",
                        style: AppTypography.eyebrowSmall
                            .copyWith(color: AppColors.emerald)),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.berry),
            onPressed: () => _deactivate(slot),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }
}

/// Bottom sheet to bulk-generate slots across a date range for chosen weekdays
/// and time ranges.
class _BulkSlotSheet extends StatefulWidget {
  final MentorWorkspaceService service;
  const _BulkSlotSheet({required this.service});

  @override
  State<_BulkSlotSheet> createState() => _BulkSlotSheetState();
}

class _BulkSlotSheetState extends State<_BulkSlotSheet> {
  DateTime? _startDate;
  DateTime? _endDate;
  // 1=Mon ... 6=Sat, 0=Sun
  final Set<int> _days = {1, 2, 3, 4, 5, 6};
  TimeOfDay _rangeStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _rangeEnd = const TimeOfDay(hour: 12, minute: 0);
  bool _generating = false;

  static const _dayLabels = {
    1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 0: 'Sun'
  };

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? now : (_startDate ?? now),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _rangeStart : _rangeEnd,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _rangeStart = picked;
      } else {
        _rangeEnd = picked;
      }
    });
  }

  Future<void> _generate() async {
    if (_startDate == null || _endDate == null) {
      _toast("Pick a start and end date");
      return;
    }
    if (_startDate!.isAfter(_endDate!)) {
      _toast("Start date must be before end date");
      return;
    }
    final startMinutes = _rangeStart.hour * 60 + _rangeStart.minute;
    final endMinutes = _rangeEnd.hour * 60 + _rangeEnd.minute;
    if (endMinutes <= startMinutes) {
      _toast("End time must be after start time");
      return;
    }

    final slots = <Map<String, dynamic>>[];
    var current = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    final last = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
    while (!current.isAfter(last)) {
      // Dart: Mon=1 ... Sun=7; normalise Sun to 0 to match our map.
      final dow = current.weekday == 7 ? 0 : current.weekday;
      if (_days.contains(dow)) {
        final startsAt = DateTime(current.year, current.month, current.day,
            _rangeStart.hour, _rangeStart.minute);
        final endsAt = DateTime(current.year, current.month, current.day,
            _rangeEnd.hour, _rangeEnd.minute);
        slots.add({
          'starts_at': startsAt.toUtc().toIso8601String(),
          'ends_at': endsAt.toUtc().toIso8601String(),
          'mode': 'video',
          'max_bookings': 1,
          'title': '1-on-1 UPSC Mentorship',
          'description': 'Video consultation with verified UPSC mentor',
        });
      }
      current = current.add(const Duration(days: 1));
    }

    if (slots.isEmpty) {
      _toast("No slots match your selection");
      return;
    }

    setState(() => _generating = true);
    try {
      await widget.service.createSlots(slots);
      _toast("Generated ${slots.length} slots");
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _toast("Failed: $e");
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Bulk Generate Slots",
              style: AppTypography.cardTitle.copyWith(fontSize: 17)),
          const SizedBox(height: 4),
          Text("Create slots for a date range across chosen weekdays.",
              style: AppTypography.caption),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _dateButton(
                      "Start", _startDate, () => _pickDate(true))),
              const SizedBox(width: 12),
              Expanded(
                  child:
                      _dateButton("End", _endDate, () => _pickDate(false))),
            ],
          ),
          const SizedBox(height: 16),
          Text("Weekdays",
              style: AppTypography.eyebrowSmall
                  .copyWith(color: AppColors.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [1, 2, 3, 4, 5, 6, 0].map((d) {
              final selected = _days.contains(d);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _days.remove(d);
                  } else {
                    _days.add(d);
                  }
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.civic : Colors.white,
                    border: Border.all(
                        color: selected ? AppColors.civic : AppColors.line),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_dayLabels[d]!,
                      style: AppTypography.caption.copyWith(
                        color: selected ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _dateButton(
                      "From time",
                      null,
                      () => _pickTime(true),
                      valueText: _rangeStart.format(context))),
              const SizedBox(width: 12),
              Expanded(
                  child: _dateButton("To time", null, () => _pickTime(false),
                      valueText: _rangeEnd.format(context))),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _generating ? null : _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.civic,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("Generate Slots"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateButton(String label, DateTime? date, VoidCallback onTap,
      {String? valueText}) {
    final display = valueText ??
        (date != null ? "${date.day}/${date.month}/${date.year}" : "Select");
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTypography.eyebrowSmall
                    .copyWith(color: AppColors.muted)),
            const SizedBox(height: 2),
            Text(display,
                style:
                    AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
