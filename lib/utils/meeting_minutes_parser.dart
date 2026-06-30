/// 将后端 Markdown 纪要解析为结构化区块（议题 / 决议 / 待办 / 总结）。
class MeetingTodoRow {
  const MeetingTodoRow({
    required this.item,
    this.owner = '',
    this.deadline = '',
    this.status = '',
  });

  final String item;
  final String owner;
  final String deadline;
  final String status;
}

class ParsedMeetingMinutes {
  const ParsedMeetingMinutes({
    this.summary = '',
    this.agenda = '',
    this.resolutions = '',
    this.todosMarkdown = '',
    this.todos = const [],
    this.rawMarkdown = '',
  });

  final String summary;
  final String agenda;
  final String resolutions;
  final String todosMarkdown;
  final List<MeetingTodoRow> todos;
  final String rawMarkdown;

  bool get todosIsTable =>
      todos.isNotEmpty &&
      todos.any((t) => t.owner.isNotEmpty || t.deadline.isNotEmpty || t.status.isNotEmpty);

  bool get hasStructure =>
      agenda.isNotEmpty ||
      resolutions.isNotEmpty ||
      todosMarkdown.isNotEmpty ||
      todos.isNotEmpty;
}

ParsedMeetingMinutes parseMeetingMinutes(String markdown) {
  final raw = markdown.trim();
  if (raw.isEmpty) return const ParsedMeetingMinutes();

  final sections = <String, String>{};
  var preamble = StringBuffer();
  var currentKey = '';
  var currentBody = StringBuffer();

  void flushSection() {
    if (currentKey.isEmpty) return;
    sections[currentKey] = currentBody.toString().trim();
    currentBody = StringBuffer();
  }

  for (final line in raw.split('\n')) {
    final h2 = _h2Title(line);
    if (h2 != null) {
      flushSection();
      if (currentKey.isEmpty && preamble.isNotEmpty) {
        // keep preamble for summary fallback
      }
      currentKey = h2;
      continue;
    }
    final h1 = _h1Title(line);
    if (h1 != null) {
      continue;
    }
    if (currentKey.isEmpty) {
      preamble.writeln(line);
    } else {
      currentBody.writeln(line);
    }
  }
  flushSection();

  var summary = '';
  var agenda = '';
  var resolutions = '';
  var todosMarkdown = '';
  var todos = <MeetingTodoRow>[];

  for (final entry in sections.entries) {
    final key = entry.key;
    final body = entry.value;
    if (_isSummaryHeading(key)) {
      summary = body;
    } else if (_isAgendaHeading(key)) {
      agenda = body;
    } else if (_isResolutionsHeading(key)) {
      resolutions = body;
    } else if (_isTodosHeading(key)) {
      todosMarkdown = body;
      todos = _parseTodos(body);
    }
  }

  if (summary.isEmpty) {
    summary = preamble.toString().trim();
    summary = summary.replaceAll(RegExp(r'^#+\s*'), '').trim();
  }

  return ParsedMeetingMinutes(
    summary: summary,
    agenda: agenda,
    resolutions: resolutions,
    todosMarkdown: todosMarkdown,
    todos: todos,
    rawMarkdown: raw,
  );
}

String? _h1Title(String line) {
  final m = RegExp(r'^#\s+(.+?)\s*$').firstMatch(line.trim());
  return m?.group(1)?.trim();
}

String? _h2Title(String line) {
  final m = RegExp(r'^##\s+(.+?)\s*$').firstMatch(line.trim());
  return m?.group(1)?.trim();
}

bool _isSummaryHeading(String title) {
  final t = title.replaceAll(' ', '');
  return t.contains('AI总结') ||
      t.contains('总结') ||
      t.contains('概览') ||
      t.contains('摘要');
}

bool _isAgendaHeading(String title) => title.contains('议题');

bool _isResolutionsHeading(String title) => title.contains('决议');

bool _isTodosHeading(String title) => title.contains('待办');

List<MeetingTodoRow> _parseTodos(String body) {
  final lines = body.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (lines.isEmpty) return const [];

  final tableRows = lines.where((l) => l.startsWith('|') && l.endsWith('|')).toList();
  if (tableRows.length >= 2) {
    final header = _splitTableRow(tableRows.first);
    final dataRows = tableRows.skip(2).map(_splitTableRow).where((r) => r.isNotEmpty).toList();
    if (header.isNotEmpty && dataRows.isNotEmpty) {
      return dataRows.map((row) {
        String col(int i) => i < row.length ? row[i].trim() : '';
        return MeetingTodoRow(
          item: _pickCol(row, header, const ['事项', '任务', '内容']),
          owner: _pickCol(row, header, const ['负责人', '责任']),
          deadline: _pickCol(row, header, const ['截止时间', '时间', '日期']),
          status: _pickCol(row, header, const ['状态']),
        );
      }).where((e) => e.item.isNotEmpty).toList();
    }
  }

  return lines
      .where((l) => !l.startsWith('|'))
      .map((l) => MeetingTodoRow(item: l.replaceFirst(RegExp(r'^[-*]\s*'), '')))
      .where((e) => e.item.isNotEmpty)
      .toList();
}

List<String> _splitTableRow(String line) {
  final inner = line.substring(1, line.length - 1);
  return inner.split('|').map((e) => e.trim()).toList();
}

String _pickCol(List<String> row, List<String> header, List<String> keys) {
  for (var i = 0; i < header.length; i++) {
    final h = header[i];
    if (keys.any((k) => h.contains(k))) {
      return i < row.length ? row[i] : '';
    }
  }
  return '';
}
