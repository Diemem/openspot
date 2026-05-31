import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ── MODEL ─────────────────────────────────────────────────────────────────────
class _Msg {
  final String id, senderId, content, time;
  final bool isMe, read, sending;
  final bool edited;
  final String? replyTo;
  const _Msg({required this.id, required this.senderId, required this.content, required this.time, required this.isMe, this.read = true, this.sending = false, this.edited = false, this.replyTo});
  _Msg copyWith({bool? read, bool? sending, bool? edited, String? content}) => _Msg(id: id, senderId: senderId, content: content ?? this.content, time: time, isMe: isMe, read: read ?? this.read, sending: sending ?? this.sending, edited: edited ?? this.edited, replyTo: replyTo);
}

class _Partner {
  final String id, name;
  final String? avatarUrl;
  const _Partner({required this.id, required this.name, this.avatarUrl});
}

// ── SCREEN ────────────────────────────────────────────────────────────────────
class ChatWindowScreen extends StatefulWidget {
  final String conversationId;
  const ChatWindowScreen({super.key, required this.conversationId});

  @override
  State<ChatWindowScreen> createState() => _ChatWindowScreenState();
}

class _ChatWindowScreenState extends State<ChatWindowScreen> {
  final _supabase = Supabase.instance.client;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _inputFocus = FocusNode();

  _Partner? _partner;
  List<_Msg> _messages = [];
  bool _isTyping = false;
  bool _showSearch = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  _Msg? _replyingTo;
  _Msg? _editingMsg;
  String? _activeActions; // message id with open actions
  RealtimeChannel? _sub;

  @override
  void initState() {
    super.initState();
    _loadPartner();
    _loadMessages();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    _searchCtrl.dispose();
    _sub?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadPartner() async {
    final id = widget.conversationId;
    if (id.startsWith('mock')) {
      setState(() => _partner = const _Partner(id: 'mock', name: 'Sarah Wanjiku', avatarUrl: 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100'));
      return;
    }
    final res = await _supabase.from('profiles').select('id, full_name, avatar_url').eq('id', id).maybeSingle();
    if (res != null) setState(() => _partner = _Partner(id: res['id'], name: res['full_name'] ?? 'User', avatarUrl: res['avatar_url']));
  }

  Future<void> _loadMessages() async {
    final user = _supabase.auth.currentUser;
    final id = widget.conversationId;

    if (user == null || id.startsWith('mock')) {
      _loadMockMessages(id);
      return;
    }

    final res = await _supabase
        .from('messages')
        .select('id, sender_id, receiver_id, content, created_at, read')
        .or('and(sender_id.eq.${user.id},receiver_id.eq.$id),and(sender_id.eq.$id,receiver_id.eq.${user.id})')
        .order('created_at', ascending: true);

    if (res.isEmpty) { _loadMockMessages(id); return; }

    setState(() {
      _messages = (res as List).map((m) => _Msg(
        id: m['id'].toString(),
        senderId: m['sender_id'],
        content: m['content'] ?? '',
        time: _formatTime(m['created_at']),
        isMe: m['sender_id'] == user.id,
        read: m['read'] ?? false,
      )).toList();
    });

    _scrollToBottom();
    _subscribeRealtime(user.id, id);
  }

  void _loadMockMessages(String partnerId) {
    setState(() {
      _messages = [
        _Msg(id: '1', senderId: partnerId, content: "Hey! I saw your roommate profile. Are you still looking?", time: '10:00 AM', isMe: false, read: true),
        _Msg(id: '2', senderId: 'me', content: "Yes! I'm looking for someone to share a 2-bedroom apartment near campus.", time: '10:02 AM', isMe: true, read: true),
        _Msg(id: '3', senderId: partnerId, content: "Perfect! What's your budget range?", time: '10:05 AM', isMe: false, read: true),
        _Msg(id: '4', senderId: 'me', content: "Around KSh 20,000–30,000 per month. Does that work for you?", time: '10:07 AM', isMe: true, read: true),
        _Msg(id: '5', senderId: partnerId, content: "That works! I was thinking the same range. Are you a student?", time: '10:10 AM', isMe: false, read: true),
      ];
    });
    _scrollToBottom();
  }

  void _subscribeRealtime(String userId, String partnerId) {
    _sub = _supabase
        .channel('chat_${userId}_$partnerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final msg = payload.newRecord;
            if ((msg['sender_id'] == userId && msg['receiver_id'] == partnerId) ||
                (msg['sender_id'] == partnerId && msg['receiver_id'] == userId)) {
              setState(() => _messages.add(_Msg(
                id: msg['id'].toString(),
                senderId: msg['sender_id'],
                content: msg['content'] ?? '',
                time: _formatTime(msg['created_at']),
                isMe: msg['sender_id'] == userId,
                read: false,
              )));
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _editingMsg != null ? _inputCtrl.text.trim() : _inputCtrl.text.trim();
    if (text.isEmpty) return;

    if (_editingMsg != null) {
      setState(() {
        _messages = _messages.map((m) => m.id == _editingMsg!.id ? m.copyWith(content: text, edited: true) : m).toList();
        _editingMsg = null;
      });
      _inputCtrl.clear();
      return;
    }

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _messages.add(_Msg(id: tempId, senderId: 'me', content: text, time: timeStr, isMe: true, sending: true, replyTo: _replyingTo?.content));
      _replyingTo = null;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    final user = _supabase.auth.currentUser;
    if (user != null && !widget.conversationId.startsWith('mock')) {
      final err = await _supabase.from('messages').insert({'sender_id': user.id, 'receiver_id': widget.conversationId, 'content': text});
      if (err != null) {
        setState(() => _messages = _messages.where((m) => m.id != tempId).toList());
      } else {
        setState(() => _messages = _messages.map((m) => m.id == tempId ? m.copyWith(sending: false) : m).toList());
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _messages = _messages.map((m) => m.id == tempId ? m.copyWith(sending: false) : m).toList());
    }
  }

  void _startEdit(_Msg msg) {
    setState(() { _editingMsg = msg; _activeActions = null; });
    _inputCtrl.text = msg.content;
    _inputFocus.requestFocus();
  }

  void _deleteMsg(String id) {
    setState(() { _messages = _messages.where((m) => m.id != id).toList(); _activeActions = null; });
  }

  void _copyMsg(String content) {
    Clipboard.setData(ClipboardData(text: content));
    setState(() => _activeActions = null);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
  }

  List<_Msg> get _filtered => _searchQuery.isEmpty ? _messages : _messages.where((m) => m.content.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      body: Column(
        children: [
          // ── HEADER ─────────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)])),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                    child: Row(children: [
                      IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.go('/messages')),
                      // Avatar
                      _partner?.avatarUrl != null
                          ? CircleAvatar(radius: 22, backgroundImage: NetworkImage(_partner!.avatarUrl!))
                          : CircleAvatar(radius: 22, backgroundColor: Colors.white24, child: Text(_partner?.name.substring(0, 1).toUpperCase() ?? 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_partner?.name ?? 'Chat', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(_isTyping ? 'typing...' : 'online', style: const TextStyle(color: Color(0xFFE0E7FF), fontSize: 12)),
                      ])),
                      IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () => setState(() => _showSearch = !_showSearch)),
                      IconButton(icon: const Icon(Icons.phone_outlined, color: Colors.white), onPressed: () {}),
                      IconButton(icon: const Icon(Icons.videocam_outlined, color: Colors.white), onPressed: () {}),
                      IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
                    ]),
                  ),
                  // Search bar
                  if (_showSearch)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const SizedBox(width: 12),
                          const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(
                            controller: _searchCtrl,
                            autofocus: true,
                            decoration: const InputDecoration(hintText: 'Search messages...', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10)),
                            onChanged: (v) => setState(() => _searchQuery = v),
                          )),
                          if (_searchQuery.isNotEmpty)
                            IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); }),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── MESSAGES ───────────────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeActions = null),
              child: filtered.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle), child: const Icon(Icons.send_outlined, size: 48, color: Color(0xFF4F46E5))),
                      const SizedBox(height: 16),
                      const Text('Start the Conversation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                      const SizedBox(height: 8),
                      Text('Send a message to begin chatting with ${_partner?.name ?? "this user"}', style: const TextStyle(color: Color(0xFF6B7280)), textAlign: TextAlign.center),
                    ]))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _MessageBubble(
                        msg: filtered[i],
                        partner: _partner,
                        showAvatar: !filtered[i].isMe && (i == 0 || filtered[i - 1].isMe),
                        showActions: _activeActions == filtered[i].id,
                        onTap: () => setState(() => _activeActions = _activeActions == filtered[i].id ? null : filtered[i].id),
                        onReply: () { setState(() { _replyingTo = filtered[i]; _activeActions = null; }); _inputFocus.requestFocus(); },
                        onCopy: () => _copyMsg(filtered[i].content),
                        onEdit: filtered[i].isMe ? () => _startEdit(filtered[i]) : null,
                        onDelete: filtered[i].isMe ? () => _deleteMsg(filtered[i].id) : null,
                      ),
                    ),
            ),
          ),

          // ── REPLY PREVIEW ──────────────────────────────────────────────────
          if (_replyingTo != null)
            Container(
              color: const Color(0xFFEEF2FF),
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(children: [
                const Icon(Icons.reply, size: 16, color: Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Replying to', style: TextStyle(fontSize: 11, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
                  Text(_replyingTo!.content, style: const TextStyle(fontSize: 12, color: Color(0xFF374151)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                IconButton(icon: const Icon(Icons.close, size: 16, color: Color(0xFF4F46E5)), onPressed: () => setState(() => _replyingTo = null)),
              ]),
            ),

          // ── EDIT INDICATOR ─────────────────────────────────────────────────
          if (_editingMsg != null)
            Container(
              color: const Color(0xFFFFF7ED),
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(children: [
                const Icon(Icons.edit_outlined, size: 16, color: Color(0xFFF97316)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Editing message', style: TextStyle(fontSize: 11, color: Color(0xFFF97316), fontWeight: FontWeight.w600)),
                  Text(_editingMsg!.content, style: const TextStyle(fontSize: 12, color: Color(0xFF374151)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                IconButton(icon: const Icon(Icons.close, size: 16, color: Color(0xFFF97316)), onPressed: () { setState(() => _editingMsg = null); _inputCtrl.clear(); }),
              ]),
            ),

          // ── INPUT BAR ──────────────────────────────────────────────────────
          SafeArea(
            top: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE5E7EB))),
                    child: Row(children: [
                      const SizedBox(width: 16),
                      Expanded(child: TextField(
                        controller: _inputCtrl,
                        focusNode: _inputFocus,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: _editingMsg != null ? 'Edit message...' : 'Type a message...',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      )),
                      IconButton(icon: const Icon(Icons.attach_file_outlined, color: Color(0xFF9CA3AF), size: 20), onPressed: () {}),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 48, height: 48,
                    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]), shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── MESSAGE BUBBLE ────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final _Msg msg;
  final _Partner? partner;
  final bool showAvatar, showActions;
  final VoidCallback onTap, onReply, onCopy;
  final VoidCallback? onEdit, onDelete;

  const _MessageBubble({required this.msg, required this.partner, required this.showAvatar, required this.showActions, required this.onTap, required this.onReply, required this.onCopy, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Partner avatar
              if (!msg.isMe) ...[
                if (showAvatar)
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: partner?.avatarUrl != null ? NetworkImage(partner!.avatarUrl!) : null,
                    backgroundColor: const Color(0xFF4F46E5),
                    child: partner?.avatarUrl == null ? Text(partner?.name.substring(0, 1).toUpperCase() ?? 'U', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)) : null,
                  )
                else
                  const SizedBox(width: 32),
                const SizedBox(width: 8),
              ],

              // Bubble
              GestureDetector(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: msg.isMe ? const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]) : null,
                      color: msg.isMe ? null : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(msg.isMe ? 18 : 4),
                        bottomRight: Radius.circular(msg.isMe ? 4 : 18),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      // Reply preview
                      if (msg.replyTo != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: msg.isMe ? Colors.white.withOpacity(0.2) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            const Icon(Icons.reply, size: 12, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 4),
                            Expanded(child: Text(msg.replyTo!, style: TextStyle(fontSize: 11, color: msg.isMe ? Colors.white70 : const Color(0xFF6B7280)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ]),
                        ),
                      Text(msg.content, style: TextStyle(fontSize: 14, color: msg.isMe ? Colors.white : const Color(0xFF111827), height: 1.4)),
                      const SizedBox(height: 4),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        if (msg.edited)
                          Text('edited  ', style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: msg.isMe ? Colors.white60 : const Color(0xFF9CA3AF))),
                        Text(msg.time, style: TextStyle(fontSize: 10, color: msg.isMe ? Colors.white60 : const Color(0xFF9CA3AF))),
                        if (msg.isMe) ...[
                          const SizedBox(width: 4),
                          Icon(msg.sending ? Icons.check : msg.read ? Icons.done_all : Icons.done_all, size: 14, color: msg.sending ? Colors.white38 : msg.read ? Colors.blue[200] : Colors.white60),
                        ],
                      ]),
                    ]),
                  ),
                ),
              ),

              if (msg.isMe) const SizedBox(width: 4),
            ],
          ),

          // Actions menu
          if (showActions)
            Container(
              margin: EdgeInsets.only(top: 4, left: msg.isMe ? 0 : 40, right: msg.isMe ? 4 : 0),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12)]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Emoji reactions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: ['👍', '❤️', '😂', '😮', '😢', '😡'].map((e) =>
                    GestureDetector(onTap: () {}, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(e, style: const TextStyle(fontSize: 20))))
                  ).toList()),
                ),
                const Divider(height: 1),
                _ActionItem(icon: Icons.reply_outlined, label: 'Reply', onTap: onReply),
                _ActionItem(icon: Icons.copy_outlined, label: 'Copy', onTap: onCopy),
                if (onEdit != null) _ActionItem(icon: Icons.edit_outlined, label: 'Edit', onTap: onEdit!),
                if (onDelete != null) _ActionItem(icon: Icons.delete_outline, label: 'Delete', onTap: onDelete!, color: const Color(0xFFEF4444)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _ActionItem({required this.icon, required this.label, required this.onTap, this.color = const Color(0xFF374151)});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
