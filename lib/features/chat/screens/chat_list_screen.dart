import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';

// ── MOCK DATA ─────────────────────────────────────────────────────────────────
class _Chat {
  final String id, name, lastMessage, timestamp, avatarUrl, lastSeen;
  final int unread;
  final bool online, pinned, typing;
  const _Chat({required this.id, required this.name, required this.lastMessage, required this.timestamp, required this.avatarUrl, required this.lastSeen, required this.unread, required this.online, required this.pinned, required this.typing});
}

const _mockChats = [
  _Chat(id: '1', name: 'Sarah Wanjiku', lastMessage: 'Hey! Are you still looking for a roommate?', timestamp: '2m ago', avatarUrl: 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100', lastSeen: 'Active now', unread: 2, online: true, pinned: false, typing: false),
  _Chat(id: '2', name: 'John Kamau', lastMessage: "Perfect! What's your budget range?", timestamp: '15m ago', avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100', lastSeen: '15 minutes ago', unread: 0, online: false, pinned: true, typing: false),
  _Chat(id: '3', name: 'Grace Achieng', lastMessage: '📷 Photo', timestamp: '1h ago', avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100', lastSeen: '1 hour ago', unread: 0, online: false, pinned: false, typing: false),
  _Chat(id: '4', name: 'David Omondi', lastMessage: "Thanks for the info! I'll check it out.", timestamp: '3h ago', avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100', lastSeen: '3 hours ago', unread: 0, online: false, pinned: false, typing: false),
  _Chat(id: '5', name: 'Mary Njeri', lastMessage: '🎤 Voice message', timestamp: '1d ago', avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100', lastSeen: 'Yesterday', unread: 1, online: false, pinned: false, typing: false),
];

// ── SCREEN ────────────────────────────────────────────────────────────────────
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;
  String _search = '';
  String _sortBy = 'recent';
  bool _showSortSheet = false;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<_Chat> get _filtered {
    var list = _mockChats.where((c) =>
      _search.isEmpty || c.name.toLowerCase().contains(_search.toLowerCase())
    ).toList();
    // Pinned first
    list.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      if (_sortBy == 'unread') return b.unread - a.unread;
      if (_sortBy == 'name') return a.name.compareTo(b.name);
      return 0;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final chats = _filtered;

    if (user == null) {
      return Scaffold(
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.message_outlined, size: 64, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 16),
          const Text('Sign in to view messages', style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => context.push('/signin'), child: const Text('Sign In')),
        ])),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Gradient header
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // Top bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Row(children: [
                          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.go('/')),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Messages', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('${chats.length} conversations', style: const TextStyle(fontSize: 12, color: Color(0xFFE0E7FF))),
                          ])),
                          IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () => setState(() => _showSearch = !_showSearch)),
                          IconButton(icon: const Icon(Icons.sort, color: Colors.white), onPressed: () => setState(() => _showSortSheet = true)),
                          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
                        ]),
                      ),
                      // Search bar
                      if (_showSearch)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(20)),
                            child: Row(children: [
                              const SizedBox(width: 12),
                              const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(
                                controller: _searchCtrl,
                                autofocus: true,
                                decoration: const InputDecoration(hintText: 'Search conversations...', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10)),
                                onChanged: (v) => setState(() => _search = v),
                              )),
                            ]),
                          ),
                        ),
                      // Tabs
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Row(children: [
                          _HeaderTab(label: 'All', count: chats.length, active: true),
                          const SizedBox(width: 8),
                          _HeaderTab(label: 'Archived', count: 0, active: false),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),

              // Chat list
              Expanded(
                child: chats.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.message_outlined, size: 64, color: Color(0xFF6366F1)),
                        const SizedBox(height: 16),
                        const Text('No messages yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                        const SizedBox(height: 8),
                        const Text('Start connecting with landlords and property owners', style: TextStyle(color: Color(0xFF6B7280)), textAlign: TextAlign.center),
                      ]))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: chats.length,
                        itemBuilder: (_, i) => _ChatCard(chat: chats[i], onTap: () => context.push('/chat/${chats[i].id}')),
                      ),
              ),
            ],
          ),

          // Sort sheet
          if (_showSortSheet)
            _SortSheet(current: _sortBy, onSelect: (v) => setState(() { _sortBy = v; _showSortSheet = false; }), onClose: () => setState(() => _showSortSheet = false)),
        ],
      ),
    );
  }
}

class _HeaderTab extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  const _HeaderTab({required this.label, required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.message_outlined, size: 14, color: Color(0xFF4F46E5)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? const Color(0xFF4F46E5) : Colors.white)),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: active ? const Color(0xFFEEF2FF) : Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: active ? const Color(0xFF4F46E5) : Colors.white)),
          ),
        ],
      ]),
    );
  }
}

// ── CHAT CARD ─────────────────────────────────────────────────────────────────
class _ChatCard extends StatelessWidget {
  final _Chat chat;
  final VoidCallback onTap;
  const _ChatCard({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Row(children: [
          // Avatar
          Stack(children: [
            CircleAvatar(radius: 28, backgroundImage: NetworkImage(chat.avatarUrl), backgroundColor: const Color(0xFF4F46E5), onBackgroundImageError: (_, __) {}),
            if (chat.online)
              Positioned(bottom: 0, right: 0, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: const Color(0xFF22C55E), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
            if (chat.unread > 0)
              Positioned(top: -2, right: -2, child: Container(
                width: 20, height: 20,
                decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: Center(child: Text('${chat.unread}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              )),
          ]),
          const SizedBox(width: 12),
          // Content
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Row(children: [
                if (chat.pinned) ...[const Icon(Icons.push_pin, size: 12, color: Color(0xFF4F46E5)), const SizedBox(width: 4)],
                Expanded(child: Text(chat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827)), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ])),
              Text(chat.timestamp, style: TextStyle(fontSize: 11, color: chat.unread > 0 ? const Color(0xFF4F46E5) : const Color(0xFF9CA3AF), fontWeight: chat.unread > 0 ? FontWeight.w600 : FontWeight.normal)),
            ]),
            const SizedBox(height: 4),
            if (chat.typing)
              Row(children: [
                const Text('typing', style: TextStyle(fontSize: 13, color: Color(0xFF4F46E5), fontWeight: FontWeight.w500)),
                const SizedBox(width: 4),
                ...List.generate(3, (i) => Container(
                  margin: EdgeInsets.only(right: i < 2 ? 2 : 0),
                  width: 4, height: 4,
                  decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle),
                )),
              ])
            else
              Text(chat.lastMessage, style: TextStyle(fontSize: 13, color: chat.unread > 0 ? const Color(0xFF111827) : const Color(0xFF6B7280), fontWeight: chat.unread > 0 ? FontWeight.w500 : FontWeight.normal), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (!chat.online && !chat.typing)
              Text(chat.lastSeen, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          ])),
        ]),
      ),
    );
  }
}

// ── SORT SHEET ────────────────────────────────────────────────────────────────
class _SortSheet extends StatelessWidget {
  final String current;
  final void Function(String) onSelect;
  final VoidCallback onClose;
  const _SortSheet({required this.current, required this.onSelect, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sort By', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ...[('recent', 'Most Recent', Icons.access_time), ('unread', 'Unread First', Icons.message_outlined), ('name', 'Name (A–Z)', Icons.people_outline)].map((o) =>
                    GestureDetector(
                      onTap: () => onSelect(o.$1),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: current == o.$1 ? const Color(0xFFEEF2FF) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: current == o.$1 ? const Color(0xFF4F46E5) : Colors.transparent, width: 2),
                        ),
                        child: Row(children: [
                          Icon(o.$3, size: 20, color: const Color(0xFF6B7280)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(o.$2, style: TextStyle(fontWeight: FontWeight.w500, color: current == o.$1 ? const Color(0xFF4F46E5) : const Color(0xFF374151)))),
                          if (current == o.$1) const Icon(Icons.check_circle, color: Color(0xFF4F46E5), size: 20),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
