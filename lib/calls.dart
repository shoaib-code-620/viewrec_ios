import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';
import 'widgets.dart';

/// Offers to call [phone] with the phone's own dialer (the number is filled in, the person taps the green button).
/// [onCalled] runs after the dialer has opened, so the call can be noted in the conversation.
void callPhone(BuildContext context, {required String name, required String phone, VoidCallback? onCalled}) {
  final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (number.length < 5) {
    showMsg(context, 'There is no phone number saved for $name yet.');
    return;
  }
  HapticFeedback.selectionClick();
  showSheet(
    context,
    Column(mainAxisSize: MainAxisSize.min, children: [
      Avatar(name, size: 64),
      const SizedBox(height: 12),
      Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
      const SizedBox(height: 4),
      Muted(phone, size: 14),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
          child: AppButton('Copy number', icon: Icons.copy_rounded, small: true, style: BtnStyle.ghost, onTap: () async {
            await Clipboard.setData(ClipboardData(text: phone));
            if (context.mounted) {
              Navigator.pop(context);
              showMsg(context, 'Number copied');
            }
          }),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppButton('Call', icon: Icons.call_rounded, small: true, onTap: () async {
            Navigator.pop(context);
            var ok = false;
            try {
              ok = await launchUrl(Uri(scheme: 'tel', path: number));
            } catch (_) {}
            if (!context.mounted) return;
            if (ok) {
              onCalled?.call();
            } else {
              showMsg(context, 'This device cannot make calls. The number is $phone.');
            }
          }),
        ),
      ]),
      const SizedBox(height: 6),
    ]),
  );
}

/// A small round call button for headers.
class CallButton extends StatelessWidget {
  final VoidCallback onTap;
  const CallButton({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: C.green.withValues(alpha: 0.16),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Icon(Icons.call_rounded, size: 19, color: C.green)),
        ),
      );
}
