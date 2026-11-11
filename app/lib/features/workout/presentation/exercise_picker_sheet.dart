import 'package:flutter/material.dart';

import '../data/workout_store.dart';
import '../domain/models.dart';

/// 운동을 검색해 고르거나, 없으면 사용자 정의 운동을 폰에 추가한다(오프라인 가능).
Future<Exercise?> showExercisePicker(BuildContext context, WorkoutStore store) =>
    showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ExercisePicker(store),
    );

class _ExercisePicker extends StatefulWidget {
  final WorkoutStore store;

  const _ExercisePicker(this.store);

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  final _query = TextEditingController();
  final _equipment = TextEditingController();
  late Future<List<Exercise>> _results = widget.store.searchExercises('');
  String? _customName; // null이 아니면 직접 추가 양식을 보인다
  String _bodyPart = bodyPartLabels.keys.first;

  @override
  void dispose() {
    _query.dispose();
    _equipment.dispose();
    super.dispose();
  }

  Future<void> _addCustom() async {
    final ex = await widget.store
        .addCustomExercise(_customName!, _equipment.text.trim(), _bodyPart);
    if (mounted) Navigator.pop(context, ex);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: _customName == null ? _search(context) : _customForm(context),
      ),
    );
  }

  Widget _search(BuildContext context) {
    final q = _query.text.trim();
    return Column(children: [
      TextField(
        controller: _query,
        autofocus: true,
        maxLength: 50, // 서버의 운동 이름 길이 제한
        decoration: const InputDecoration(
            hintText: '운동 이름 검색',
            counterText: '',
            prefixIcon: Icon(Icons.search)),
        onChanged: (v) {
          final next = widget.store.searchExercises(v.trim());
          setState(() {
            _results = next;
          });
        },
      ),
      const SizedBox(height: 8),
      Expanded(
        child: FutureBuilder<List<Exercise>>(
          future: _results,
          builder: (context, snap) {
            final list = snap.data ?? const <Exercise>[];
            return ListView(children: [
              for (final e in list)
                ListTile(
                  title: Text(e.name),
                  subtitle: Text(exerciseSubtitle(e)),
                  onTap: () => Navigator.pop(context, e),
                ),
              if (q.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text('"$q" 직접 추가'),
                  onTap: () => setState(() => _customName = q),
                ),
            ]);
          },
        ),
      ),
    ]);
  }

  Widget _customForm(BuildContext context) {
    return ListView(children: [
      Text(_customName!, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      TextField(
        key: const Key('customEquipment'),
        controller: _equipment,
        maxLength: 50,
        decoration: const InputDecoration(labelText: '기구 (선택)'),
      ),
      const SizedBox(height: 8),
      const Text('부위'),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in bodyPartLabels.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: _bodyPart == e.key,
            onSelected: (_) => setState(() => _bodyPart = e.key),
          ),
      ]),
      const SizedBox(height: 16),
      FilledButton(onPressed: _addCustom, child: const Text('추가')),
    ]);
  }
}

/// "바벨 · 가슴". 기구가 없으면 부위만 쓴다.
String exerciseSubtitle(Exercise e) {
  final part = bodyPartLabels[e.bodyPart] ?? e.bodyPart;
  return e.equipment.isEmpty ? part : '${e.equipment} · $part';
}
