import 'package:flutter/material.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';
import 'settings_extra.dart';

String formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return switch (AppPrefs.dateFormat.value) {
    'MM/DD/YYYY' => '${two(d.month)}/${two(d.day)}/${d.year}',
    'YYYY-MM-DD' => '${d.year}-${two(d.month)}-${two(d.day)}',
    _ => '${two(d.day)}/${two(d.month)}/${d.year}',
  };
}

/// "Set a reminder": a note to yourself, on a day you choose, once or repeating. Returns true when it was saved.
Future<bool> showReminderSheet(BuildContext context, {DateTime? date}) async {
  final today = DateTime.now();
  var on = date ?? DateTime(today.year, today.month, today.day + 1);
  final about = TextEditingController();
  final every = TextEditingController(text: '7');
  var repeat = false, saving = false;
  String? error;
  final saved = await showSheet<bool>(
    context,
    StatefulBuilder(
      builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: H2('Set a reminder')),
          IconButton(onPressed: () => Navigator.pop(ctx, false), icon: Icon(Icons.close_rounded, color: C.muted)),
        ]),
        const SizedBox(height: 8),
        const Text('Remind me on', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(context: ctx, initialDate: on, firstDate: DateTime(today.year, today.month, today.day), lastDate: DateTime(today.year + 2));
            if (picked != null) set(() => on = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(rMd), border: Border.all(color: C.border)),
            child: Row(children: [
              Expanded(child: Text(formatDate(on), style: const TextStyle(fontSize: 16))),
              Icon(Icons.calendar_today_rounded, size: 20, color: C.muted),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Field('About', controller: about, lines: 3, hint: 'Call the Hendersons about their review'),
        Row(children: [
          Checkbox(value: repeat, activeColor: C.primary, onChanged: (v) => set(() => repeat = v ?? false)),
          const Text('Repeat every', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: TextField(
              controller: every,
              enabled: repeat,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: C.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(rMd), borderSide: BorderSide(color: C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(rMd), borderSide: BorderSide(color: C.border)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('days', style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: TextStyle(color: C.rec, fontSize: 13))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            flex: 2,
            child: AppButton(saving ? 'Saving…' : 'Set reminder', icon: Icons.notifications_active_outlined, loading: saving, onTap: saving
                ? null
                : () async {
                    final days = repeat ? int.tryParse(every.text.trim()) : null;
                    if (about.text.trim().isEmpty) return set(() => error = 'Say what the reminder is about');
                    if (repeat && (days == null || days < 1 || days > 365)) return set(() => error = 'Repeat every 1 to 365 days');
                    set(() {
                      error = null;
                      saving = true;
                    });
                    try {
                      await webRepo.createReminder(date: on, about: about.text.trim(), repeatEveryDays: days);
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (_) {
                      set(() {
                        saving = false;
                        error = "Couldn't save the reminder. Try again.";
                      });
                    }
                  }),
          ),
          const SizedBox(width: 10),
          Expanded(child: AppButton('Cancel', style: BtnStyle.ghost, onTap: () => Navigator.pop(ctx, false))),
        ]),
      ]),
    ),
  );
  if (saved == true && context.mounted) showSuccess(context, 'Reminder set for ${formatDate(on)}');
  return saved == true;
}
