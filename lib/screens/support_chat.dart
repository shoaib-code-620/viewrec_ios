import 'package:flutter/material.dart';
import '../async_view.dart';
import '../models.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';
import 'lead_thread.dart';

/// The ViewRec team's side of Support: the same conversation as the Inbox, with the ViewRec team.
class SupportConversation extends ConversationSource {
  @override
  Future<List<ThreadMessage>> load() => webRepo.supportThread();
  @override
  Future<ThreadMessage> sendText(String text) => webRepo.sendSupportMessage(text);
  @override
  Future<ThreadMessage> sendAttachment({required String kind, required String path, required String name, int size = 0, int durationMs = 0, void Function(double)? onProgress}) =>
      webRepo.sendSupportAttachment(kind: kind, path: path, name: name, size: size, durationMs: durationMs, onProgress: onProgress);
  @override
  Future<ThreadMessage> edit(String messageId, String text) => webRepo.editSupportMessage(messageId, text);
  @override
  Future<void> delete(String messageId) => webRepo.deleteSupportMessage(messageId);
}

/// Support: a conversation with the ViewRec team. Text, photos, files and voice notes, with ticks, edit and delete.
class SupportChatScreen extends StatelessWidget {
  const SupportChatScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<List<ThreadMessage>>(
        load: webRepo.supportThread,
        skeletonCards: 2,
        builder: (context, msgs, refresh) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: C.primarySoft), child: Icon(Icons.support_agent_rounded, color: C.primary)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Text('ViewRec support', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Muted('We usually reply within a day', size: 12),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: ConversationBody(
              source: SupportConversation(),
              initial: msgs,
              quick: const ['I need help with my plan', 'A recording did not upload', 'How do I embed my reviews?'],
              avoidTabBar: true,
            ),
          ),
        ]),
      );
}
