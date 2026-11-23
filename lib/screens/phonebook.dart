import 'package:flutter/material.dart';
import '../async_view.dart';
import '../data.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'import.dart';
import 'contact_detail.dart';
import 'invite_composer.dart';

/// Business Phonebook: all customers, approve / skip / invite.
class PhonebookScreen extends StatelessWidget {
  const PhonebookScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<List<Customer>>(
        load: repo.customers,
        builder: (context, list, refresh) => _PhonebookBody(initial: list, refresh: refresh),
      );
}

class _PhonebookBody extends StatefulWidget {
  final List<Customer> initial;
  final Future<void> Function() refresh;
  const _PhonebookBody({required this.initial, required this.refresh});
  @override
  State<_PhonebookBody> createState() => _PhonebookBodyState();
}

class _PhonebookBodyState extends State<_PhonebookBody> {
  static const filters = ['all', 'suggested', 'approved', 'invited', 'recorded', 'skipped'];
  late final List<Customer> list = widget.initial;
  String filter = 'all';
  String q = '';

  Future<void> _set(Customer c, String status) async {
    final prev = c.status;
    setState(() => c.status = status);
    try {
      await repo.setCustomerStatus(c.id, status);
    } catch (_) {
      if (mounted) {
        setState(() => c.status = prev);
        showMsg(context, "Couldn't update ${c.name}. Try again.");
      }
    }
  }

  void _addContact() {
    final name = TextEditingController(), phone = TextEditingController(), job = TextEditingController();
    showSheet(
      context,
      StatefulBuilder(
        builder: (ctx, set) {
          var saving = false;
          return StatefulBuilder(
            builder: (ctx, setSaving) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const H2('Add a contact'),
              const SizedBox(height: 14),
              Field('Name', controller: name, hint: 'Jane Smith'),
              Field('Mobile or email', controller: phone, hint: '+44 7700 900123', keyboard: TextInputType.emailAddress),
              Field('Job done', controller: job, hint: 'Roof repair'),
              AppButton(saving ? 'Saving…' : 'Save contact', onTap: saving
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty) {
                        showMsg(ctx, 'Please enter a name');
                        return;
                      }
                      setSaving(() => saving = true);
                      try {
                        final c = await repo.addCustomer(name: name.text.trim(), job: job.text.trim().isEmpty ? 'Job' : job.text.trim(), contact: phone.text.trim());
                        if (!mounted) return;
                        setState(() => list.insert(0, c));
                        Navigator.pop(ctx);
                        showMsg(context, 'Contact added');
                      } catch (_) {
                        setSaving(() => saving = false);
                        if (ctx.mounted) showMsg(ctx, "Couldn't save the contact. Try again.");
                      }
                    }),
            ]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = list.where((c) => (filter == 'all' || c.status == filter) && c.name.toLowerCase().contains(q.toLowerCase())).toList();
    final pending = list.where((c) => c.status == 'suggested').toList();
    return RefreshIndicator(
      onRefresh: widget.refresh,
      child: AppPage(children: [
        Row(children: [
          Expanded(child: StatCard(icon: Icons.people_outline_rounded, label: 'Contacts', value: '${list.length}')),
          const SizedBox(width: 12),
          Expanded(child: StatCard(icon: Icons.mark_email_unread_rounded, label: 'Ready to invite', value: '${list.where((c) => c.status == 'approved').length}')),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: AppButton('Add contact', icon: Icons.person_add_alt_rounded, small: true, onTap: _addContact)),
          const SizedBox(width: 8),
          Expanded(
            child: AppButton('Import list', icon: Icons.upload_file_rounded, small: true, style: BtnStyle.ghost, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImportScreen()))),
          ),
        ]),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => q = v),
          decoration: InputDecoration(
            hintText: 'Search contacts',
            hintStyle: TextStyle(color: C.muted),
            prefixIcon: Icon(Icons.search_rounded, size: 18, color: C.muted),
            filled: true,
            fillColor: C.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.primary)),
          ),
        ),
        const SizedBox(height: 12),
        Pills([for (final f in filters) f[0].toUpperCase() + f.substring(1)], filters.indexOf(filter), (i) => setState(() => filter = filters[i])),
        const SizedBox(height: 12),
        if (pending.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppButton('Approve all ${pending.length} suggested', icon: Icons.done_all_rounded, small: true, onTap: () {
              for (final c in List.of(pending)) {
                _set(c, 'approved');
              }
            }),
          ),
        for (final c in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ContactDetailScreen(customer: c))).then((_) {
                if (mounted) setState(() {});
              }),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Avatar(c.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Muted('${c.job} · ${c.date}', size: 13),
                    ]),
                  ),
                  StatusBadge(c.status),
                ]),
                const SizedBox(height: 10),
                Text(c.reason, style: TextStyle(color: C.muted, fontSize: 12, fontStyle: FontStyle.italic)),
                if (c.status == 'suggested') ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: AppButton('Approve', small: true, onTap: () => _set(c, 'approved'))),
                    const SizedBox(width: 8),
                    Expanded(child: AppButton('Skip', small: true, style: BtnStyle.ghost, onTap: () => _set(c, 'skipped'))),
                  ]),
                ],
                if (c.status == 'approved') ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: AppButton('Send invitation', icon: Icons.send_rounded, small: true, onTap: () => _set(c, 'invited'))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton('Customise', icon: Icons.edit_rounded, small: true, style: BtnStyle.ghost,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InviteComposerScreen(to: c.name)))),
                    ),
                  ]),
                ],
                if (c.status == 'invited') ...[
                  const SizedBox(height: 12),
                  AppButton('Send reminder', icon: Icons.notifications_active_rounded, small: true, style: BtnStyle.ghost, onTap: () => showMsg(context, 'Reminder sent to ${c.name}')),
                ],
              ]),
            ),
          ),
        if (shown.isEmpty) const EmptyState(Icons.contacts_rounded, 'No contacts here', 'Add or import customers to start asking.'),
        const SizedBox(height: 80),
      ]),
    );
  }
}
