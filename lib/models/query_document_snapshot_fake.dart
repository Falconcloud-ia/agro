class QueryDocumentSnapshotFake {
  final String id;
  final Map<String, dynamic> _data;

  QueryDocumentSnapshotFake(this.id, this._data);

  Map<String, dynamic> data() => _data;
  dynamic operator [](String key) => _data[key];
}
