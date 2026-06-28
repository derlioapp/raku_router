/// A compiled URL path template such as `/notes/:id`.
///
/// One template, used both ways: [match] turns a concrete path into its captured
/// parameters, and [fill] rebuilds a concrete path from parameters. This is the
/// single source of truth that lets a route map to and from a URL with no
/// hand-written parsing or string building.
///
/// Segments are matched exactly (same count, literals equal); a `:name` segment
/// captures one path segment. Percent-encoding is handled on both sides. The
/// query string is ignored for matching.
class PathPattern {
  /// Compiles [template] (e.g. `/notes/:id`) into a reusable pattern.
  PathPattern(this.template) : _segments = _parse(template);

  /// The original template this was compiled from.
  final String template;

  final List<_Segment> _segments;

  /// The `:param` names in this template, in order of appearance.
  List<String> get parameters =>
      _segments.where((s) => s.isParam).map((s) => s.text).toList();

  /// Whether the template contains any `:param` segments.
  bool get hasParameters => _segments.any((s) => s.isParam);

  /// Captures the parameters from [path], or returns `null` if it does not
  /// match. A non-null (possibly empty) map means a match.
  Map<String, String>? match(String path) {
    final parts = _split(path);
    if (parts.length != _segments.length) return null;
    final params = <String, String>{};
    for (var i = 0; i < _segments.length; i++) {
      final segment = _segments[i];
      if (segment.isParam) {
        params[segment.text] = Uri.decodeComponent(parts[i]);
      } else if (segment.text != parts[i]) {
        return null;
      }
    }
    return params;
  }

  /// Builds a concrete path, substituting [params] for each `:param`.
  ///
  /// Asserts (debug) if a required parameter is missing; in release the missing
  /// value is treated as empty rather than throwing.
  String fill(Map<String, String> params) {
    if (_segments.isEmpty) return '/';
    final out = StringBuffer();
    for (final segment in _segments) {
      out.write('/');
      if (segment.isParam) {
        final value = params[segment.text];
        assert(
          value != null,
          'Raku: missing path parameter ":${segment.text}" for "$template".',
        );
        out.write(Uri.encodeComponent(value ?? ''));
      } else {
        out.write(segment.text);
      }
    }
    return out.toString();
  }

  static List<_Segment> _parse(String template) => <_Segment>[
        for (final part in _split(template))
          part.startsWith(':')
              ? _Segment.param(part.substring(1))
              : _Segment.literal(part),
      ];

  /// Splits a path into non-empty segments, ignoring any query string and
  /// leading/trailing slashes (so `/notes/` and `/notes` are equivalent).
  static List<String> _split(String path) => path
      .split('?')
      .first
      .split('/')
      .where((p) => p.isNotEmpty)
      .toList(growable: false);

  @override
  String toString() => 'PathPattern($template)';
}

/// One segment of a [PathPattern]: a literal or a `:param` capture.
class _Segment {
  const _Segment.literal(this.text) : isParam = false;
  const _Segment.param(this.text) : isParam = true;

  final String text;
  final bool isParam;
}
