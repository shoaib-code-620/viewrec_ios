import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';

/// Bring past customers in: choose a file, match its columns, see what we can reach, approve names.
class ImportScreen extends StatefulWidget {
  final int initialStep;
  const ImportScreen({super.key, this.initialStep = 0});
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  late int step = widget.initialStep;

  // Pretend these are the columns found in the uploaded sheet.
  static const columns = ['Customer name', 'Mobile', 'Email address', 'Service', 'Completed on', 'Notes'];
  static const rows = [
    ['Sarah Mitchell', '07700 900123', 'sarah@example.com', 'Roof replacement', '11 Nov 2026', 'Very happy'],
    ['Daniel Okafor', '07700 900456', 'daniel@example.com', 'Gutter repair', '02 Nov 2026', ''],
    ['Priya Nair', '07700 900789', '', 'Full re-roof', '21 Oct 2026', 'Repeat customer'],
  ];

  // field -> chosen column index (-1 = do not import)
  final Map<String, int> mapping = {'Name': 0, 'Mobile': 1, 'Email': 2, 'Job done': 3, 'Date': 4};
  static const required = {'Name'};
  String? mapError;

  void _next() {
    if (step == 1) {
      if ((mapping['Name'] ?? -1) < 0) {
        setState(() => mapError = 'Choose which column holds the customer name.');
        return;
      }
      if ((mapping['Mobile'] ?? -1) < 0 && (mapping['Email'] ?? -1) < 0) {
        setState(() => mapError = 'Map at least a mobile number or an email so we can reach them.');
        return;
      }
      mapError = null;
    }
    setState(() => step++);
  }

  Widget _row(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(color: C.muted)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _pt(IconData i, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(i, size: 20, color: C.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(t)),
        ]),
      );

  Widget _dropdown(String field) {
    final v = mapping[field] ?? -1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        SizedBox(
          width: 96,
          child: Text.rich(TextSpan(text: field, style: const TextStyle(fontWeight: FontWeight.w600), children: [
            if (required.contains(field)) TextSpan(text: ' *', style: TextStyle(color: C.rec)),
          ])),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(rMd), border: Border.all(color: C.border)),
            child: DropdownButton<int>(
              value: v,
              isExpanded: true,
              underline: const SizedBox(),
              dropdownColor: C.surface,
              items: [
                if (!required.contains(field)) DropdownMenuItem(value: -1, child: Text("Don't import", style: TextStyle(color: C.muted))),
                if (required.contains(field)) DropdownMenuItem(value: -1, child: Text('Choose a column…', style: TextStyle(color: C.muted))),
                for (var i = 0; i < columns.length; i++) DropdownMenuItem(value: i, child: Text(columns[i])),
              ],
              onChanged: (n) => setState(() => mapping[field] = n ?? -1),
            ),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AppPage(children: [
          const BackHeader('Bring your past customers'),
          Row(children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                  decoration: BoxDecoration(color: i <= step ? C.primary : C.surface2, borderRadius: BorderRadius.circular(2)),
                ),
              ),
          ]),
          const SizedBox(height: 24),
          if (step == 0) ...[
            const H1('Export your completed jobs', size: 26),
            const SizedBox(height: 8),
            const Muted('Upload a spreadsheet or CSV with names, phone or email, and the job done. We tell you honestly how many we can reach before anything is promised.'),
            const SizedBox(height: 24),
            AppCard(
              borderColor: C.primary,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              onTap: () => showMsg(context, 'The file picker opens here. Use the sample list for now.'),
              child: SizedBox(
                width: double.infinity,
                child: Column(children: [
                  Icon(Icons.cloud_upload_rounded, size: 34, color: C.primary),
                  const SizedBox(height: 10),
                  const Text('Choose a file', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Muted('.csv or .xlsx · up to 10,000 rows', size: 13),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            AppButton('Use sample list', onTap: _next),
          ],
          if (step == 1) ...[
            const H1('Match your columns', size: 26),
            const SizedBox(height: 8),
            const Muted('We guessed where each detail is. Change anything that looks wrong.'),
            const SizedBox(height: 18),
            for (final f in const ['Name', 'Mobile', 'Email', 'Job done', 'Date']) _dropdown(f),
            if (mapError != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(mapError!, style: TextStyle(color: C.rec, fontSize: 13))),
            const SectionHeader('Preview'),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                for (var r = 0; r < rows.length; r++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Avatar(rows[r][mapping['Name']! >= 0 ? mapping['Name']! : 0], size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(mapping['Name']! >= 0 ? rows[r][mapping['Name']!] : '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Muted([
                            if ((mapping['Mobile'] ?? -1) >= 0 && rows[r][mapping['Mobile']!].isNotEmpty) rows[r][mapping['Mobile']!],
                            if ((mapping['Email'] ?? -1) >= 0 && rows[r][mapping['Email']!].isNotEmpty) rows[r][mapping['Email']!],
                          ].join(' · ').ifEmpty('No contact details'), size: 12),
                          if ((mapping['Job done'] ?? -1) >= 0) Muted('${rows[r][mapping['Job done']!]}${(mapping['Date'] ?? -1) >= 0 ? ' · ${rows[r][mapping['Date']!]}' : ''}', size: 12),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 20),
            AppButton('Continue', onTap: _next),
          ],
          if (step == 2) ...[
            const H1('Here is what we found', size: 26),
            const SizedBox(height: 16),
            AppCard(
              child: Column(children: [
                _row('Rows in your file', '212'),
                _row('Customers we can reach', '143'),
                _row('Opted out or duplicates', '69'),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: C.primarySoft, borderRadius: BorderRadius.circular(rMd)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('REALISTIC ESTIMATE', style: TextStyle(color: C.accentText, fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 4),
                    const Text('12 – 22 videos', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Muted('Past customers answer less often than recent ones. This is the honest range, not the flattering one.', size: 13),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            AppButton('Continue', onTap: _next),
          ],
          if (step == 3) ...[
            const H1('You approve every name', size: 26),
            const SizedBox(height: 8),
            const Muted('We suggest who to ask first and why. You take off anyone the job went badly with.'),
            const SizedBox(height: 16),
            AppCard(
              child: Column(children: [
                _pt(Icons.schedule_rounded, 'Invitations go out 8am–8pm where you are'),
                _pt(Icons.repeat_rounded, 'Never the same person twice in six months'),
                _pt(Icons.back_hand_rounded, 'An opt-out is final, for everyone'),
              ]),
            ),
            const SizedBox(height: 24),
            AppButton('Review suggested customers', icon: Icons.people_rounded, onTap: () => Navigator.of(context).pop()),
          ],
        ]),
      );
}

extension _Fallback on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
