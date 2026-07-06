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
///
/// A trailing `*` is a **catch-all**: it must be the last segment and captures
/// the remaining path (zero or more segments, joined by `/`) under the reserved
/// name [catchAllKey]. `/feed/*` matches `/feed`, `/feed/x`, and `/feed/x/y`.
/// This is how a wildcard `route('*', …)` — a subtree or global 404 — is
/// expressed; it round-trips, so the caught URL is preserved.
class PathPattern {
  /// Compiles [template] (e.g. `/notes/:id`) into a reusable pattern.
  PathPattern(this.template) : _segments = _parse(template) {
    assert(
      !_segments.any((s) => s.isCatchAll) || _segments.last.isCatchAll,
      'Raku: a catch-all "*" must be the last segment of "$template".',
    );
  }

  /// The reserved parameter name a catch-all (`*`) segment captures into.
  static const String catchAllKey = '*';

  /// The original template this was compiled from.
  final String template;

  final List<_Segment> _segments;

  /// Whether the last segment is a catch-all (`*`).
  bool get isCatchAll => _segments.isNotEmpty && _segments.last.isCatchAll;

  /// The `:param` (and catch-all `*`) names in this template, in order.
  List<String> get parameters =>
      _segments.where((s) => s.isParam).map((s) => s.text).toList();

  /// Whether the template contains any `:param` or catch-all segments.
  bool get hasParameters => _segments.any((s) => s.isParam);

  /// Captures the parameters from [path], or returns `null` if it does not
  /// match. A non-null (possibly empty) map means a match. A catch-all pattern
  /// matches when the fixed leading segments do, capturing the rest under
  /// [catchAllKey] (possibly empty).
  Map<String, String>? match(String path) {
    final parts = _split(path);
    if (isCatchAll) {
      final fixed = _segments.length - 1;
      if (parts.length < fixed) return null;
      final params = <String, String>{};
      for (var i = 0; i < fixed; i++) {
        final segment = _segments[i];
        if (segment.isParam) {
          params[segment.text] = Uri.decodeComponent(parts[i]);
        } else if (segment.text != parts[i]) {
          return null;
        }
      }
      params[catchAllKey] =
          parts.sublist(fixed).map(Uri.decodeComponent).join('/');
      return params;
    }
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

  /// Builds a concrete path, substituting [params] for each `:param` and the
  /// catch-all remainder for a trailing `*`.
  ///
  /// Asserts (debug) if a required parameter is missing; in release the missing
  /// value is treated as empty rather than throwing.
  String fill(Map<String, String> params) {
    if (_segments.isEmpty) return '/';
    final out = StringBuffer();
    for (final segment in _segments) {
      if (segment.isCatchAll) {
        // The remainder is a path fragment (possibly several segments); encode
        // each piece and keep the separators. Empty → no trailing part.
        final rest = params[catchAllKey] ?? '';
        for (final piece in rest.split('/').where((p) => p.isNotEmpty)) {
          out
            ..write('/')
            ..write(Uri.encodeComponent(piece));
        }
        continue;
      }
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
    final path = out.toString();
    return path.isEmpty ? '/' : path;
  }

  static List<_Segment> _parse(String template) => <_Segment>[
        for (final part in _split(template))
          if (part == catchAllKey)
            const _Segment.catchAll()
          else if (part.startsWith(':'))
            _Segment.param(part.substring(1))
          else
            _Segment.literal(part),
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

/// One segment of a [PathPattern]: a literal, a `:param` capture, or a trailing
/// `*` catch-all (a param named [PathPattern.catchAllKey] that captures the
/// remaining path).
class _Segment {
  const _Segment.literal(this.text)
      : isParam = false,
        isCatchAll = false;
  const _Segment.param(this.text)
      : isParam = true,
        isCatchAll = false;
  const _Segment.catchAll()
      : text = PathPattern.catchAllKey,
        isParam = true,
        isCatchAll = true;

  final String text;
  final bool isParam;
  final bool isCatchAll;
}
