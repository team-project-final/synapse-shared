# Synapse Docs Portal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** synapse-gitops/site Flutter Web 앱을 확장하여 gitops 런북 + shared 문서 64개를 통합 열람/검색/요약할 수 있는 문서 포탈을 구축한다.

**Architecture:** 빌드 스크립트(Node.js)가 두 레포의 마크다운을 JSON으로 변환 + 역인덱스 생성 + AI 요약 사전 생성. Flutter Web은 이 JSON을 읽어서 검색/필터/렌더링. 서버 없는 순수 클라이언트 사이드.

**Tech Stack:** Flutter Web 3.11+ (flutter_markdown, go_router, google_fonts), Node.js 빌드 스크립트, Claude API (Haiku, 빌드 시에만)

**작업 레포:** `synapse-gitops/site/` (기존 Flutter 프로젝트 확장)

---

## File Structure

### 새로 생성할 파일

| 파일 | 책임 |
|------|------|
| `scripts/build_docs.mjs` | 마크다운 → JSON 변환 + 역인덱스 + AI 요약 빌드 파이프라인 |
| `scripts/package.json` | 빌드 스크립트 의존성 (gray-matter) |
| `lib/models/doc.dart` | 통합 문서 모델 (Doc, DocIndex, DocCategory) |
| `lib/models/search_index.dart` | 검색 인덱스 모델 + 클라이언트 사이드 검색 엔진 |
| `lib/pages/doc_page.dart` | 개별 문서 뷰어 (TOC + 요약 + 본문) |
| `lib/pages/search_page.dart` | 전문 검색 페이지 |
| `lib/pages/dashboard_page.dart` | 프로젝트 현황 대시보드 |
| `lib/widgets/toc_panel.dart` | 우측 TOC 사이드패널 |
| `lib/widgets/progress_bar.dart` | 체크박스 기반 진행률 바 |
| `lib/widgets/summary_card.dart` | AI 요약 TL;DR 카드 |
| `lib/widgets/search_bar_widget.dart` | 검색 입력 + 자동완성 |
| `lib/widgets/tag_chip.dart` | 태그 필터 칩 |

### 수정할 파일

| 파일 | 변경 |
|------|------|
| `lib/app.dart` | 새 라우트 추가, 테마 변경 (DESIGN.md 준수), AppBar 확장 |
| `lib/widgets/sidebar.dart` | 카테고리 목록 + 검색바 추가 |
| `lib/pages/home_page.dart` | 카테고리 그리드 + 현황 + 최근 업데이트로 개편 |
| `pubspec.yaml` | assets/docs/ 추가 |

---

## Task 1: 빌드 스크립트 — 마크다운 → JSON 변환

**Files:**
- Create: `synapse-gitops/site/scripts/build_docs.mjs`
- Create: `synapse-gitops/site/scripts/package.json`

- [ ] **Step 1: scripts/package.json 생성**

```json
{
  "name": "docs-builder",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "node build_docs.mjs",
    "build:no-ai": "NO_AI=1 node build_docs.mjs"
  },
  "dependencies": {
    "gray-matter": "^4.0.3"
  }
}
```

- [ ] **Step 2: build_docs.mjs 기본 구조 작성**

```javascript
import fs from 'fs';
import path from 'path';
import matter from 'gray-matter';

const WORKSPACE = path.resolve('../../');
const GITOPS_DOCS = path.join(WORKSPACE, 'synapse-gitops/docs/runbooks');
const SHARED_DOCS = path.join(WORKSPACE, 'synapse-shared/docs');
const OUTPUT_DIR = path.resolve('assets/docs');

const CATEGORY_MAP = [
  { pattern: /^gitops\/docs\/runbooks/, category: 'infra' },
  { pattern: /^shared\/docs\/guides/, category: 'guides' },
  { pattern: /^shared\/docs\/project-management/, category: 'management' },
  { pattern: /^shared\/docs\/(prd|superpowers)/, category: 'prd' },
  { pattern: /^shared\/docs\/rules/, category: 'rules' },
  { pattern: /^shared\/docs\/fix-requests/, category: 'fix-requests' },
];

const TAG_KEYWORDS = [
  'kafka', 'argocd', 'terraform', 'eks', 'rds', 'msk', 'redis', 'opensearch',
  'docker', 'helm', 'staging', 'dev', 'prod', 'security', 'tls', 'acl',
  'flyway', 'gradle', 'ci', 'cd', 'deploy', 'rollback', 'e2e', 'avro', 'schema',
];

const STOP_PARTICLES = ['은', '는', '이', '가', '을', '를', '의', '에', '로', '와', '과', '도', '만', '까지'];

function collectMarkdownFiles() {
  const files = [];

  if (fs.existsSync(GITOPS_DOCS)) {
    for (const f of fs.readdirSync(GITOPS_DOCS)) {
      if (f.endsWith('.md')) {
        files.push({ absPath: path.join(GITOPS_DOCS, f), relKey: `gitops/docs/runbooks/${f}` });
      }
    }
  }

  function walk(dir, relBase) {
    if (!fs.existsSync(dir)) return;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      const rel = `${relBase}/${entry.name}`;
      if (entry.isDirectory()) walk(full, rel);
      else if (entry.name.endsWith('.md')) files.push({ absPath: full, relKey: rel });
    }
  }
  walk(SHARED_DOCS, 'shared/docs');

  return files;
}

function categorize(relKey) {
  for (const { pattern, category } of CATEGORY_MAP) {
    if (pattern.test(relKey)) return category;
  }
  return 'etc';
}

function slugify(relKey) {
  return path.basename(relKey, '.md').toLowerCase().replace(/[^a-z0-9가-힣_-]/g, '-').replace(/-+/g, '-');
}

function extractToc(body) {
  const toc = [];
  for (const line of body.split('\n')) {
    const m = line.match(/^(#{2,3})\s+(.+)/);
    if (m) {
      const level = m[1].length;
      const text = m[2].trim();
      const anchor = text.toLowerCase().replace(/[^a-z0-9가-힣\s-]/g, '').replace(/\s+/g, '-');
      toc.push({ level, text, anchor });
    }
  }
  return toc;
}

function extractTags(body) {
  const lower = body.toLowerCase();
  const matched = TAG_KEYWORDS.filter(kw => {
    const regex = new RegExp(kw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi');
    return (lower.match(regex) || []).length >= 3;
  });
  return matched.slice(0, 5);
}

function extractCompletionRate(body) {
  const checked = (body.match(/- \[x\]/gi) || []).length;
  const unchecked = (body.match(/- \[ \]/g) || []).length;
  const total = checked + unchecked;
  if (total === 0) return null;
  return Math.round((checked / total) * 100);
}

function getLastModified(absPath) {
  try {
    return fs.statSync(absPath).mtime.toISOString().slice(0, 10);
  } catch { return null; }
}

function buildSearchIndex(docs) {
  const index = {};
  for (const doc of docs) {
    const text = `${doc.title} ${doc.title} ${doc.title} ${doc.body}`;
    const tokens = text.split(/[\s,.;:!?()\[\]{}|/\\<>"'`~#*_=+\-\n\r\t]+/).filter(Boolean);
    for (const raw of tokens) {
      let token = raw.toLowerCase();
      for (const p of STOP_PARTICLES) {
        if (token.endsWith(p) && token.length > p.length + 1) {
          token = token.slice(0, -p.length);
          break;
        }
      }
      if (token.length < 2) continue;
      if (!index[token]) index[token] = [];
      if (!index[token].find(e => e.slug === doc.slug)) {
        index[token].push({ slug: doc.slug, title: doc.title, category: doc.category });
      }
    }
  }
  return index;
}

async function main() {
  const files = collectMarkdownFiles();
  console.log(`Found ${files.length} markdown files`);

  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  for (const cat of ['infra', 'guides', 'management', 'prd', 'rules', 'fix-requests']) {
    fs.mkdirSync(path.join(OUTPUT_DIR, cat), { recursive: true });
  }

  const indexEntries = [];
  const allDocs = [];

  for (const { absPath, relKey } of files) {
    const raw = fs.readFileSync(absPath, 'utf-8');
    const { data: frontmatter, content: body } = matter(raw);

    const slug = slugify(relKey);
    const category = categorize(relKey);
    const title = frontmatter.title || body.split('\n').find(l => l.startsWith('# '))?.replace(/^#\s+/, '') || slug;
    const source = relKey.startsWith('gitops') ? 'synapse-gitops' : 'synapse-shared';

    const doc = {
      slug,
      title,
      category,
      source,
      tags: extractTags(body),
      summary: '',
      metadata: {
        lastUpdated: getLastModified(absPath),
        status: 'active',
        completionRate: extractCompletionRate(body),
      },
      toc: extractToc(body),
      body,
    };

    allDocs.push(doc);

    const docPath = path.join(OUTPUT_DIR, category, `${slug}.json`);
    fs.writeFileSync(docPath, JSON.stringify(doc, null, 2));

    indexEntries.push({
      slug: doc.slug,
      title: doc.title,
      category: doc.category,
      source: doc.source,
      tags: doc.tags,
      summary: doc.summary,
      metadata: doc.metadata,
    });
  }

  fs.writeFileSync(path.join(OUTPUT_DIR, 'index.json'), JSON.stringify(indexEntries, null, 2));

  const searchIndex = buildSearchIndex(allDocs);
  fs.writeFileSync(path.join(OUTPUT_DIR, 'search-index.json'), JSON.stringify(searchIndex));

  const sizeKB = (Buffer.byteLength(JSON.stringify(searchIndex)) / 1024).toFixed(1);
  console.log(`Built ${indexEntries.length} docs, search index ${sizeKB}KB`);
}

main().catch(console.error);
```

- [ ] **Step 3: npm install 실행**

Run: `cd synapse-gitops/site/scripts && npm install`
Expected: `added 1 package` (gray-matter)

- [ ] **Step 4: 빌드 스크립트 실행 테스트**

Run: `cd synapse-gitops/site/scripts && npm run build:no-ai`
Expected:
```
Found 64 markdown files
Built 64 docs, search index XXX.XKB
```

- [ ] **Step 5: 출력 확인**

Run: `ls synapse-gitops/site/assets/docs/ && cat synapse-gitops/site/assets/docs/index.json | head -20`
Expected: index.json, search-index.json, 카테고리별 서브디렉토리에 JSON 파일 존재

- [ ] **Step 6: 커밋**

```bash
cd synapse-gitops/site
git add scripts/build_docs.mjs scripts/package.json scripts/package-lock.json assets/docs/
git commit -m "feat: add docs build pipeline — markdown to JSON converter + search index"
```

---

## Task 2: AI 요약 생성 (빌드 스크립트 확장)

**Files:**
- Modify: `synapse-gitops/site/scripts/build_docs.mjs`

- [ ] **Step 1: AI 요약 함수 추가**

`build_docs.mjs`의 `main()` 함수 위에 다음 함수를 추가:

```javascript
const CACHE_FILE = path.resolve('.summary-cache.json');
import { createHash } from 'crypto';

function hashContent(text) {
  return createHash('md5').update(text).digest('hex');
}

function loadCache() {
  try { return JSON.parse(fs.readFileSync(CACHE_FILE, 'utf-8')); }
  catch { return {}; }
}

function saveCache(cache) {
  fs.writeFileSync(CACHE_FILE, JSON.stringify(cache, null, 2));
}

async function generateSummary(body, title) {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey || process.env.NO_AI === '1') return '';

  const prompt = `다음 기술 문서를 2~3줄로 요약해줘. 핵심 목적, 대상, 결과물을 포함해.\n\n제목: ${title}\n\n${body.slice(0, 4000)}`;

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 200,
      messages: [{ role: 'user', content: prompt }],
    }),
  });

  if (!res.ok) {
    console.warn(`AI summary failed for ${title}: ${res.status}`);
    return '';
  }

  const data = await res.json();
  return data.content?.[0]?.text || '';
}
```

- [ ] **Step 2: main() 함수에 요약 로직 통합**

`main()` 함수의 문서 순회 루프 안에서, `const doc = { ... }` 직후 부분을 수정:

```javascript
    // 기존 doc 생성 코드 바로 아래에 추가
    const contentHash = hashContent(body);
    const cache = loadCache();
    if (cache[slug] && cache[slug].hash === contentHash) {
      doc.summary = cache[slug].summary;
    } else {
      doc.summary = await generateSummary(body, title);
      cache[slug] = { hash: contentHash, summary: doc.summary };
      saveCache(cache);
    }
```

- [ ] **Step 3: .gitignore에 캐시 파일 추가**

```bash
echo ".summary-cache.json" >> synapse-gitops/site/scripts/.gitignore
```

- [ ] **Step 4: NO_AI 모드로 테스트**

Run: `cd synapse-gitops/site/scripts && NO_AI=1 node build_docs.mjs`
Expected: 요약 필드가 빈 문자열로 생성, 에러 없음

- [ ] **Step 5: 커밋**

```bash
cd synapse-gitops/site
git add scripts/build_docs.mjs scripts/.gitignore
git commit -m "feat: add AI summary generation with hash-based caching"
```

---

## Task 3: Flutter 문서 모델 (Doc, DocCategory)

**Files:**
- Create: `synapse-gitops/site/lib/models/doc.dart`

- [ ] **Step 1: doc.dart 작성**

```dart
enum DocCategory {
  infra,
  guides,
  management,
  prd,
  rules,
  fixRequests;

  static DocCategory fromString(String value) {
    switch (value) {
      case 'infra': return DocCategory.infra;
      case 'guides': return DocCategory.guides;
      case 'management': return DocCategory.management;
      case 'prd': return DocCategory.prd;
      case 'rules': return DocCategory.rules;
      case 'fix-requests': return DocCategory.fixRequests;
      default: return DocCategory.infra;
    }
  }

  String get id {
    switch (this) {
      case DocCategory.fixRequests: return 'fix-requests';
      default: return name;
    }
  }

  String get displayName {
    switch (this) {
      case DocCategory.infra: return '인프라';
      case DocCategory.guides: return '가이드';
      case DocCategory.management: return '프로젝트 관리';
      case DocCategory.prd: return 'PRD/설계';
      case DocCategory.rules: return '규칙';
      case DocCategory.fixRequests: return '수정 요청';
    }
  }

  String get icon {
    switch (this) {
      case DocCategory.infra: return '🏗️';
      case DocCategory.guides: return '📋';
      case DocCategory.management: return '📊';
      case DocCategory.prd: return '📝';
      case DocCategory.rules: return '📏';
      case DocCategory.fixRequests: return '🔧';
    }
  }
}

class TocEntry {
  final int level;
  final String text;
  final String anchor;

  const TocEntry({required this.level, required this.text, required this.anchor});

  factory TocEntry.fromJson(Map<String, dynamic> json) {
    return TocEntry(
      level: json['level'] as int,
      text: json['text'] as String,
      anchor: json['anchor'] as String,
    );
  }
}

class DocMetadata {
  final String? lastUpdated;
  final String status;
  final int? completionRate;

  const DocMetadata({this.lastUpdated, this.status = 'active', this.completionRate});

  factory DocMetadata.fromJson(Map<String, dynamic> json) {
    return DocMetadata(
      lastUpdated: json['lastUpdated'] as String?,
      status: json['status'] as String? ?? 'active',
      completionRate: json['completionRate'] as int?,
    );
  }
}

/// index.json 항목 (body 없음)
class DocIndex {
  final String slug;
  final String title;
  final DocCategory category;
  final String source;
  final List<String> tags;
  final String summary;
  final DocMetadata metadata;

  const DocIndex({
    required this.slug,
    required this.title,
    required this.category,
    required this.source,
    required this.tags,
    required this.summary,
    required this.metadata,
  });

  factory DocIndex.fromJson(Map<String, dynamic> json) {
    return DocIndex(
      slug: json['slug'] as String,
      title: json['title'] as String,
      category: DocCategory.fromString(json['category'] as String),
      source: json['source'] as String,
      tags: List<String>.from(json['tags'] as List),
      summary: json['summary'] as String? ?? '',
      metadata: DocMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
    );
  }
}

/// 개별 문서 (body 포함)
class Doc extends DocIndex {
  final List<TocEntry> toc;
  final String body;

  const Doc({
    required super.slug,
    required super.title,
    required super.category,
    required super.source,
    required super.tags,
    required super.summary,
    required super.metadata,
    required this.toc,
    required this.body,
  });

  factory Doc.fromJson(Map<String, dynamic> json) {
    return Doc(
      slug: json['slug'] as String,
      title: json['title'] as String,
      category: DocCategory.fromString(json['category'] as String),
      source: json['source'] as String,
      tags: List<String>.from(json['tags'] as List),
      summary: json['summary'] as String? ?? '',
      metadata: DocMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      toc: (json['toc'] as List).map((e) => TocEntry.fromJson(e as Map<String, dynamic>)).toList(),
      body: json['body'] as String,
    );
  }
}
```

- [ ] **Step 2: 컴파일 확인**

Run: `cd synapse-gitops/site && flutter analyze lib/models/doc.dart`
Expected: No issues found

- [ ] **Step 3: 커밋**

```bash
git add lib/models/doc.dart
git commit -m "feat: add Doc/DocIndex/DocCategory models for unified docs"
```

---

## Task 4: 검색 인덱스 모델 + 클라이언트 검색 엔진

**Files:**
- Create: `synapse-gitops/site/lib/models/search_index.dart`

- [ ] **Step 1: search_index.dart 작성**

```dart
import 'dart:convert';
import 'package:flutter/services.dart';

class SearchResult {
  final String slug;
  final String title;
  final String category;
  final double score;

  const SearchResult({
    required this.slug,
    required this.title,
    required this.category,
    required this.score,
  });
}

class SearchEngine {
  Map<String, List<Map<String, String>>> _index = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/docs/search-index.json');
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      _index = decoded.map((key, value) => MapEntry(
        key,
        (value as List).map((e) => Map<String, String>.from(e as Map)).toList(),
      ));
      _loaded = true;
    } catch (e) {
      _index = {};
      _loaded = true;
    }
  }

  List<SearchResult> search(String query, {String? categoryFilter}) {
    if (!_loaded || query.trim().isEmpty) return [];

    final tokens = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    if (tokens.isEmpty) return [];

    final scores = <String, _ScoreEntry>{};

    for (final token in tokens) {
      for (final key in _index.keys) {
        if (!key.contains(token)) continue;
        final isExact = key == token;
        for (final entry in _index[key]!) {
          final slug = entry['slug']!;
          final category = entry['category']!;
          if (categoryFilter != null && category != categoryFilter) continue;

          scores.putIfAbsent(slug, () => _ScoreEntry(
            slug: slug,
            title: entry['title']!,
            category: category,
            score: 0,
          ));
          scores[slug]!.score += isExact ? 10 : 3;
        }
      }
    }

    final results = scores.values
        .map((e) => SearchResult(slug: e.slug, title: e.title, category: e.category, score: e.score))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return results.take(20).toList();
  }
}

class _ScoreEntry {
  final String slug;
  final String title;
  final String category;
  double score;

  _ScoreEntry({required this.slug, required this.title, required this.category, required this.score});
}
```

- [ ] **Step 2: 컴파일 확인**

Run: `cd synapse-gitops/site && flutter analyze lib/models/search_index.dart`
Expected: No issues found

- [ ] **Step 3: 커밋**

```bash
git add lib/models/search_index.dart
git commit -m "feat: add client-side search engine with inverted index"
```

---

## Task 5: 위젯 — SummaryCard, ProgressBar, TocPanel, TagChip

**Files:**
- Create: `synapse-gitops/site/lib/widgets/summary_card.dart`
- Create: `synapse-gitops/site/lib/widgets/progress_bar.dart`
- Create: `synapse-gitops/site/lib/widgets/toc_panel.dart`
- Create: `synapse-gitops/site/lib/widgets/tag_chip.dart`
- Create: `synapse-gitops/site/lib/widgets/search_bar_widget.dart`

- [ ] **Step 1: summary_card.dart**

```dart
import 'package:flutter/material.dart';

class SummaryCard extends StatefulWidget {
  final String summary;

  const SummaryCard({super.key, required this.summary});

  @override
  State<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<SummaryCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.summary.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Text('TL;DR',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFFD97706),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20, color: const Color(0xFFD97706),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(widget.summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF78716C),
                  height: 1.6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: progress_bar.dart**

```dart
import 'package:flutter/material.dart';

class ProgressBar extends StatelessWidget {
  final int percentage;
  final String? label;

  const ProgressBar({super.key, required this.percentage, this.label});

  Color get _color {
    if (percentage >= 70) return const Color(0xFF0D9488);
    if (percentage >= 30) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label!, style: Theme.of(context).textTheme.bodySmall),
                Text('$percentage%', style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _color,
                )),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: const Color(0xFFE7E5E4),
            color: _color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: toc_panel.dart**

```dart
import 'package:flutter/material.dart';
import 'package:synapse_runbooks/models/doc.dart';

class TocPanel extends StatelessWidget {
  final List<TocEntry> toc;
  final ValueChanged<String> onTap;

  const TocPanel({super.key, required this.toc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (toc.isEmpty) return const SizedBox.shrink();

    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('목차', style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: toc.length,
              itemBuilder: (context, index) {
                final entry = toc[index];
                return InkWell(
                  onTap: () => onTap(entry.anchor),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: (entry.level - 2) * 12.0,
                      top: 4,
                      bottom: 4,
                    ),
                    child: Text(
                      entry.text,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: tag_chip.dart**

```dart
import 'package:flutter/material.dart';

class TagChip extends StatelessWidget {
  final String tag;
  final bool selected;
  final VoidCallback? onTap;

  const TagChip({super.key, required this.tag, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(tag),
        backgroundColor: selected ? const Color(0xFFFEF3C7) : null,
        side: selected
            ? const BorderSide(color: Color(0xFFD97706))
            : BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: selected ? const Color(0xFFD97706) : null,
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: search_bar_widget.dart**

```dart
import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmitted;
  final String hintText;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onSubmitted,
    this.hintText = '문서 검색...',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted?.call(),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }
}
```

- [ ] **Step 6: 컴파일 확인**

Run: `cd synapse-gitops/site && flutter analyze lib/widgets/`
Expected: No issues found

- [ ] **Step 7: 커밋**

```bash
git add lib/widgets/summary_card.dart lib/widgets/progress_bar.dart lib/widgets/toc_panel.dart lib/widgets/tag_chip.dart lib/widgets/search_bar_widget.dart
git commit -m "feat: add widgets — SummaryCard, ProgressBar, TocPanel, TagChip, SearchBar"
```

---

## Task 6: DocPage — 개별 문서 뷰어

**Files:**
- Create: `synapse-gitops/site/lib/pages/doc_page.dart`

- [ ] **Step 1: doc_page.dart 작성**

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:synapse_runbooks/models/doc.dart';
import 'package:synapse_runbooks/widgets/markdown_viewer.dart';
import 'package:synapse_runbooks/widgets/summary_card.dart';
import 'package:synapse_runbooks/widgets/toc_panel.dart';
import 'package:synapse_runbooks/widgets/tag_chip.dart';
import 'package:synapse_runbooks/widgets/progress_bar.dart';

class DocPage extends StatefulWidget {
  final String category;
  final String slug;

  const DocPage({super.key, required this.category, required this.slug});

  @override
  State<DocPage> createState() => _DocPageState();
}

class _DocPageState extends State<DocPage> {
  Doc? _doc;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DocPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug || oldWidget.category != widget.category) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/docs/${widget.category}/${widget.slug}.json',
      );
      setState(() {
        _doc = Doc.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '문서를 찾을 수 없습니다: ${widget.category}/${widget.slug}';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    final doc = _doc!;
    final isWide = MediaQuery.of(context).size.width >= 1100;

    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: const Color(0xFFF5F5F4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(doc.title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: Text(doc.category.icon, style: const TextStyle(fontSize: 14)),
                    label: Text(doc.category.displayName),
                  ),
                  if (doc.metadata.lastUpdated != null)
                    Chip(
                      avatar: const Icon(Icons.calendar_today, size: 14),
                      label: Text(doc.metadata.lastUpdated!),
                    ),
                  for (final tag in doc.tags)
                    TagChip(tag: tag),
                ],
              ),
              if (doc.metadata.completionRate != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: 300,
                  child: ProgressBar(
                    percentage: doc.metadata.completionRate!,
                    label: '진행률',
                  ),
                ),
              ],
            ],
          ),
        ),
        // Body + TOC
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SummaryCard(summary: doc.summary),
                      MarkdownViewer(data: doc.body),
                    ],
                  ),
                ),
              ),
              if (isWide && doc.toc.isNotEmpty)
                TocPanel(
                  toc: doc.toc,
                  onTap: (anchor) {
                    // scroll spy는 향후 확장
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 컴파일 확인**

Run: `cd synapse-gitops/site && flutter analyze lib/pages/doc_page.dart`
Expected: No issues found

- [ ] **Step 3: 커밋**

```bash
git add lib/pages/doc_page.dart
git commit -m "feat: add DocPage — document viewer with TOC, summary, progress"
```

---

## Task 7: SearchPage — 전문 검색

**Files:**
- Create: `synapse-gitops/site/lib/pages/search_page.dart`

- [ ] **Step 1: search_page.dart 작성**

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_runbooks/models/doc.dart';
import 'package:synapse_runbooks/models/search_index.dart';
import 'package:synapse_runbooks/widgets/search_bar_widget.dart';
import 'package:synapse_runbooks/widgets/tag_chip.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _engine = SearchEngine();
  List<DocIndex> _allDocs = [];
  List<SearchResult> _results = [];
  String? _selectedCategory;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _engine.load();
    final jsonStr = await rootBundle.loadString('assets/docs/index.json');
    final list = json.decode(jsonStr) as List;
    setState(() {
      _allDocs = list.map((e) => DocIndex.fromJson(e as Map<String, dynamic>)).toList();
      _loading = false;
    });
  }

  void _onSearch(String query) {
    setState(() {
      _results = _engine.search(query, categoryFilter: _selectedCategory);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final categories = DocCategory.values;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SearchBarWidget(
            controller: _controller,
            onChanged: _onSearch,
            hintText: '키워드로 문서 검색...',
          ),
          const SizedBox(height: 16),
          // Category filter
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('전체'),
                selected: _selectedCategory == null,
                onSelected: (_) {
                  setState(() => _selectedCategory = null);
                  _onSearch(_controller.text);
                },
              ),
              for (final cat in categories)
                ChoiceChip(
                  label: Text(cat.displayName),
                  selected: _selectedCategory == cat.id,
                  onSelected: (_) {
                    setState(() => _selectedCategory = _selectedCategory == cat.id ? null : cat.id);
                    _onSearch(_controller.text);
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          // Results
          Expanded(
            child: _controller.text.isEmpty
                ? Center(
                    child: Text(
                      '검색어를 입력하세요 (${_allDocs.length}개 문서)',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : _results.isEmpty
                    ? const Center(child: Text('검색 결과가 없습니다'))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final r = _results[index];
                          final doc = _allDocs.where((d) => d.slug == r.slug).firstOrNull;
                          return ListTile(
                            leading: Text(
                              DocCategory.fromString(r.category).icon,
                              style: const TextStyle(fontSize: 20),
                            ),
                            title: Text(r.title),
                            subtitle: doc != null && doc.summary.isNotEmpty
                                ? Text(doc.summary, maxLines: 2, overflow: TextOverflow.ellipsis)
                                : Text(r.category),
                            trailing: doc != null
                                ? Wrap(
                                    spacing: 4,
                                    children: [for (final t in doc.tags) TagChip(tag: t)],
                                  )
                                : null,
                            onTap: () => context.go('/docs/${r.category}/${r.slug}'),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 컴파일 확인**

Run: `cd synapse-gitops/site && flutter analyze lib/pages/search_page.dart`
Expected: No issues found

- [ ] **Step 3: 커밋**

```bash
git add lib/pages/search_page.dart
git commit -m "feat: add SearchPage — full-text search with category filtering"
```

---

## Task 8: DashboardPage — 프로젝트 현황

**Files:**
- Create: `synapse-gitops/site/lib/pages/dashboard_page.dart`

- [ ] **Step 1: dashboard_page.dart 작성**

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_runbooks/models/doc.dart';
import 'package:synapse_runbooks/widgets/progress_bar.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<DocIndex> _docs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final jsonStr = await rootBundle.loadString('assets/docs/index.json');
    final list = json.decode(jsonStr) as List;
    setState(() {
      _docs = list.map((e) => DocIndex.fromJson(e as Map<String, dynamic>)).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final withProgress = _docs.where((d) => d.metadata.completionRate != null).toList();
    final categoryCounts = <DocCategory, int>{};
    for (final d in _docs) {
      categoryCounts[d.category] = (categoryCounts[d.category] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('프로젝트 현황', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),

          // Category summary
          Text('문서 현황', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final cat in DocCategory.values)
                if (categoryCounts.containsKey(cat))
                  _StatCard(
                    icon: cat.icon,
                    label: cat.displayName,
                    value: '${categoryCounts[cat]}개',
                    onTap: () => context.go('/search'),
                  ),
              _StatCard(
                icon: '📚',
                label: '전체',
                value: '${_docs.length}개',
                onTap: () => context.go('/search'),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Progress tracking
          if (withProgress.isNotEmpty) ...[
            Text('진행 상태', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final doc in withProgress) ...[
              InkWell(
                onTap: () => context.go('/docs/${doc.category.id}/${doc.slug}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ProgressBar(
                    percentage: doc.metadata.completionRate!,
                    label: doc.title,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatCard({required this.icon, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 컴파일 확인**

Run: `cd synapse-gitops/site && flutter analyze lib/pages/dashboard_page.dart`
Expected: No issues found

- [ ] **Step 3: 커밋**

```bash
git add lib/pages/dashboard_page.dart
git commit -m "feat: add DashboardPage — project status overview with progress bars"
```

---

## Task 9: HomePage 개편 + Sidebar 확장

**Files:**
- Modify: `synapse-gitops/site/lib/pages/home_page.dart`
- Modify: `synapse-gitops/site/lib/widgets/sidebar.dart`

- [ ] **Step 1: home_page.dart 전면 재작성**

기존 런북 전용 홈을 통합 홈으로 교체. 기존 `home_page.dart` 전체를 다음으로 교체:

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_runbooks/models/doc.dart';
import 'package:synapse_runbooks/widgets/progress_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<DocIndex> _docs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final jsonStr = await rootBundle.loadString('assets/docs/index.json');
    final list = json.decode(jsonStr) as List;
    setState(() {
      _docs = list.map((e) => DocIndex.fromJson(e as Map<String, dynamic>)).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final categoryCounts = <DocCategory, int>{};
    for (final d in _docs) {
      categoryCounts[d.category] = (categoryCounts[d.category] ?? 0) + 1;
    }

    final withProgress = _docs.where((d) => d.metadata.completionRate != null).toList();
    final recent = List<DocIndex>.from(_docs)
      ..sort((a, b) => (b.metadata.lastUpdated ?? '').compareTo(a.metadata.lastUpdated ?? ''));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Synapse Docs',
            style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text('인프라 구축부터 운영까지, 프로젝트 전체 문서를 한 곳에서',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
          const SizedBox(height: 24),

          // Progress summary
          if (withProgress.isNotEmpty) ...[
            Card(
              color: const Color(0xFFF5F5F4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('프로젝트 현황', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    for (final doc in withProgress.take(5))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ProgressBar(percentage: doc.metadata.completionRate!, label: doc.title),
                      ),
                    if (withProgress.length > 5)
                      TextButton(
                        onPressed: () => context.go('/dashboard'),
                        child: const Text('전체 보기'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Category grid
          Text('카테고리', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final cat in DocCategory.values)
                if (categoryCounts.containsKey(cat))
                  _CategoryCard(
                    category: cat,
                    count: categoryCounts[cat]!,
                    onTap: () => context.go('/search'),
                  ),
            ],
          ),
          const SizedBox(height: 32),

          // Recent updates
          Text('최근 업데이트', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final doc in recent.take(10))
            ListTile(
              leading: Text(doc.category.icon, style: const TextStyle(fontSize: 18)),
              title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: doc.summary.isNotEmpty
                  ? Text(doc.summary, maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              trailing: doc.metadata.lastUpdated != null
                  ? Text(doc.metadata.lastUpdated!, style: Theme.of(context).textTheme.bodySmall)
                  : null,
              onTap: () => context.go('/docs/${doc.category.id}/${doc.slug}'),
            ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final DocCategory category;
  final int count;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(category.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(category.displayName, style: Theme.of(context).textTheme.titleSmall),
            Text('$count개 문서', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: sidebar.dart 확장**

기존 `sidebar.dart` 전체를 다음으로 교체:

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_runbooks/models/doc.dart';
import 'package:synapse_runbooks/models/runbook.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  List<DocIndex> _docs = [];
  List<RunbookIndex> _runbooks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final docsJson = await rootBundle.loadString('assets/docs/index.json');
      final docsList = json.decode(docsJson) as List;
      _docs = docsList.map((e) => DocIndex.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {}

    try {
      final runbooksJson = await rootBundle.loadString('assets/runbooks/index.json');
      final runbooksList = json.decode(runbooksJson) as List;
      _runbooks = runbooksList.map((e) => RunbookIndex.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {}

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final grouped = <DocCategory, List<DocIndex>>{};
    for (final d in _docs) {
      grouped.putIfAbsent(d.category, () => []).add(d);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Navigation
        ListTile(
          leading: const Icon(Icons.home),
          title: const Text('홈'),
          onTap: () => context.go('/'),
        ),
        ListTile(
          leading: const Icon(Icons.search),
          title: const Text('검색'),
          onTap: () => context.go('/search'),
        ),
        ListTile(
          leading: const Icon(Icons.dashboard),
          title: const Text('현황'),
          onTap: () => context.go('/dashboard'),
        ),
        const Divider(),

        // Doc categories
        for (final cat in DocCategory.values)
          if (grouped.containsKey(cat))
            ExpansionTile(
              leading: Text(cat.icon, style: const TextStyle(fontSize: 16)),
              title: Text('${cat.displayName} (${grouped[cat]!.length})'),
              children: [
                for (final doc in grouped[cat]!)
                  ListTile(
                    title: Text(doc.title, style: Theme.of(context).textTheme.bodySmall),
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 56),
                    onTap: () => context.go('/docs/${doc.category.id}/${doc.slug}'),
                  ),
              ],
            ),

        // Legacy runbooks
        if (_runbooks.isNotEmpty) ...[
          const Divider(),
          ExpansionTile(
            leading: const Icon(Icons.menu_book, size: 16),
            title: Text('런북 (${_runbooks.length})'),
            children: [
              for (final r in _runbooks)
                ListTile(
                  title: Text(r.title, style: Theme.of(context).textTheme.bodySmall),
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 56),
                  onTap: () => context.go('/runbook/${r.slug}'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 3: 컴파일 확인**

Run: `cd synapse-gitops/site && flutter analyze lib/pages/home_page.dart lib/widgets/sidebar.dart`
Expected: No issues found

- [ ] **Step 4: 커밋**

```bash
git add lib/pages/home_page.dart lib/widgets/sidebar.dart
git commit -m "feat: overhaul HomePage + Sidebar for unified docs portal"
```

---

## Task 10: 라우터 + 테마 + pubspec 업데이트

**Files:**
- Modify: `synapse-gitops/site/lib/app.dart`
- Modify: `synapse-gitops/site/pubspec.yaml`

- [ ] **Step 1: app.dart에 새 라우트 + 테마 적용**

기존 `app.dart` 전체를 다음으로 교체:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:synapse_runbooks/pages/home_page.dart';
import 'package:synapse_runbooks/pages/runbook_page.dart';
import 'package:synapse_runbooks/pages/onboarding_page.dart';
import 'package:synapse_runbooks/pages/doc_page.dart';
import 'package:synapse_runbooks/pages/search_page.dart';
import 'package:synapse_runbooks/pages/dashboard_page.dart';
import 'package:synapse_runbooks/widgets/sidebar.dart';

final _router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return AppShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchPage(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/docs/:category/:slug',
          builder: (context, state) {
            final category = state.pathParameters['category']!;
            final slug = state.pathParameters['slug']!;
            return DocPage(category: category, slug: slug);
          },
        ),
        // Legacy routes
        GoRoute(
          path: '/runbook/:slug',
          builder: (context, state) {
            final slug = state.pathParameters['slug']!;
            return RunbookPage(slug: slug);
          },
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingPage(),
        ),
      ],
    ),
  ],
);

class SynapseRunbooksApp extends StatelessWidget {
  const SynapseRunbooksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Synapse Docs',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFD97706),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansKrTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFFAFAF9),
      ),
      routerConfig: _router,
    );
  }
}

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => context.go('/'),
          child: const Text('Synapse Docs'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.dashboard),
            onPressed: () => context.go('/dashboard'),
          ),
        ],
      ),
      drawer: isWide ? null : const Drawer(child: Sidebar()),
      body: Row(
        children: [
          if (isWide)
            const SizedBox(
              width: 280,
              child: Sidebar(),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: pubspec.yaml에 docs 에셋 추가**

`pubspec.yaml`의 `flutter:` > `assets:` 섹션에 추가:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/runbooks/
    - assets/docs/
    - assets/docs/infra/
    - assets/docs/guides/
    - assets/docs/management/
    - assets/docs/prd/
    - assets/docs/rules/
    - assets/docs/fix-requests/
```

- [ ] **Step 3: 빌드 테스트**

Run: `cd synapse-gitops/site && flutter build web --release`
Expected: 빌드 성공, `build/web/` 생성

- [ ] **Step 4: 로컬 실행 테스트**

Run: `cd synapse-gitops/site && flutter run -d chrome`
Expected: 브라우저에서 새 홈페이지 표시, 사이드바에 카테고리 목록, `/search` 접근 가능

- [ ] **Step 5: 커밋**

```bash
git add lib/app.dart pubspec.yaml
git commit -m "feat: update router + theme + pubspec for docs portal"
```

---

## Task 11: 통합 테스트 + 최종 검증

**Files:** (없음 — 기존 파일 검증만)

- [ ] **Step 1: 빌드 파이프라인 재실행**

```bash
cd synapse-gitops/site/scripts && npm run build:no-ai
```

Expected: 64개 문서 JSON 생성 완료

- [ ] **Step 2: Flutter 빌드**

```bash
cd synapse-gitops/site && flutter build web --release
```

Expected: 빌드 성공

- [ ] **Step 3: 수동 테스트 체크리스트**

로컬에서 `flutter run -d chrome` 실행 후:

| 항목 | 확인 |
|------|------|
| 홈페이지: 카테고리 그리드 6개 표시 | |
| 홈페이지: 진행 상태 바 표시 | |
| 홈페이지: 최근 업데이트 목록 | |
| 사이드바: 카테고리별 문서 목록 (ExpansionTile) | |
| 사이드바: 홈/검색/현황 네비게이션 | |
| 검색: 키워드 입력 → 결과 표시 | |
| 검색: 카테고리 필터 동작 | |
| 문서 뷰어: 마크다운 렌더링 | |
| 문서 뷰어: TL;DR 요약 카드 | |
| 문서 뷰어: TOC 사이드패널 (1100px+) | |
| 문서 뷰어: 진행률 바 (WORKFLOW 문서) | |
| 대시보드: 문서 현황 카드 | |
| 대시보드: 진행 상태 목록 | |
| 레거시: `/runbook/:slug` 동작 | |

- [ ] **Step 4: 최종 커밋**

```bash
git add -A
git commit -m "chore: final integration — docs portal ready"
```
