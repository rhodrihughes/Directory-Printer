// HTMLTemplate.swift
// Directory Printer
//
// Self-contained HTML template for the interactive file explorer snapshot.
// Placeholders /*SNAPSHOT_DATA*/ and /*SNAPSHOT_CONFIG*/ are replaced at
// generation time by HTMLGenerator.

enum HTMLTemplate {
    static let template: String = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Directory Snapshot</title>
      <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          font-size: 13px;
          background: #1e1e1e;
          color: #d4d4d4;
          display: flex;
          flex-direction: column;
          height: 100vh;
          overflow: hidden;
        }
        #header {
          background: #2d2d2d;
          border-bottom: 1px solid #3e3e3e;
          padding: 10px 16px;
          display: flex;
          align-items: center;
          gap: 16px;
          flex-shrink: 0;
        }
        #header h1 {
          font-size: 11px;
          font-weight: 400;
          color: #888;
          white-space: nowrap;
          margin-bottom: 2px;
        }
        #header-path {
          font-size: 13px;
          font-weight: 700;
          color: #e8e8e8;
          white-space: normal;
          word-break: break-all;
          overflow-wrap: anywhere;
          margin-bottom: 4px;
        }
        #header-meta {
          font-size: 11px;
          color: #888;
          white-space: nowrap;
          display: flex;
          gap: 12px;
          margin-top: 3px;
        }
        #header-title-block {
          flex: 1;
          min-width: 0;
        }
        #header .meta {
          font-size: 11px;
          color: #888;
          white-space: nowrap;
        }
        #header-logo {
          height: 32px;
          width: auto;
          flex-shrink: 0;
          display: block;
        }
        #toolbar {
          background: #252526;
          border-bottom: 1px solid #3e3e3e;
          padding: 6px 16px;
          display: flex;
          align-items: center;
          gap: 8px;
          flex-shrink: 0;
        }
        #search-input {
          flex: 1;
          max-width: 280px;
          background: #3c3c3c;
          border: 1px solid #555;
          border-radius: 4px 0 0 4px;
          color: #d4d4d4;
          padding: 4px 8px;
          font-size: 12px;
          outline: none;
        }
        #search-input:focus { border-color: #007acc; }
        #search-input::placeholder { color: #666; }
        #search-btn {
          background: #3c3c3c;
          border: 1px solid #555;
          border-left: none;
          border-radius: 0 4px 4px 0;
          color: #d4d4d4;
          padding: 4px 10px;
          font-size: 12px;
          cursor: pointer;
          white-space: nowrap;
          flex-shrink: 0;
        }
        #search-btn:hover { background: #007acc; border-color: #007acc; color: #fff; }
        #search-btn:active { background: #005f9e; }
        #stats {
          margin-left: auto;
          font-size: 11px;
          color: #888;
          white-space: nowrap;
        }
        #main {
          display: flex;
          flex: 1;
          overflow: hidden;
        }
        #sidebar {
          width: 280px;
          min-width: 160px;
          max-width: 480px;
          background: #252526;
          border-right: 1px solid #3e3e3e;
          overflow-y: auto;
          overflow-x: hidden;
          flex-shrink: 0;
          user-select: none;
        }
        #resizer {
          width: 4px;
          background: transparent;
          cursor: col-resize;
          flex-shrink: 0;
        }
        #resizer:hover, #resizer.dragging { background: #007acc; }
        #content {
          flex: 1;
          overflow: auto;
          background: #1e1e1e;
        }
        /* Tree - classic explorer style */
        .tree-node { position: relative; }
        .tree-row {
          display: flex;
          align-items: center;
          padding: 2px 4px 2px 0;
          cursor: pointer;
          white-space: nowrap;
          position: relative;
        }
        .tree-row:hover { background: rgba(255,255,255,0.05); }
        .tree-row.selected { background: #094771; }
        .tree-row.selected .tree-name { color: #fff; font-weight: 700; }
        /* Dotted vertical line running down through children */
        .tree-children {
          padding-left: 0;
          margin-left: 20px;
          border-left: 1px dotted #555;
        }
        .tree-children.collapsed { display: none; }
        /* Horizontal dotted connector */
        .tree-connector {
          display: inline-block;
          width: 10px;
          border-top: 1px dotted #555;
          flex-shrink: 0;
          margin-right: 3px;
        }
        .tree-icon { flex-shrink: 0; font-size: 14px; margin-right: 4px; }
        .tree-name {
          font-size: 12px;
          color: #d4d4d4;
          overflow: hidden;
          text-overflow: ellipsis;
        }
        /* File table */
        #file-table-wrap {
          padding: 0;
        }
        table {
          width: 100%;
          border-collapse: collapse;
          table-layout: fixed;
        }
        thead {
          position: sticky;
          top: 0;
          background: #252526;
          z-index: 1;
        }
        th {
          padding: 7px 12px;
          text-align: left;
          font-size: 11px;
          font-weight: 600;
          color: #aaa;
          border-bottom: 1px solid #3e3e3e;
          cursor: pointer;
          white-space: nowrap;
          user-select: none;
        }
        th:hover { color: #d4d4d4; }
        th.sort-asc::after { content: " ▲"; font-size: 9px; }
        th.sort-desc::after { content: " ▼"; font-size: 9px; }
        th { position: relative; }
        th:nth-child(1) { width: 45%; }
        th:nth-child(2) { width: 30%; }
        th:nth-child(3) { width: 25%; }
        th.col-size { text-align: right; }
        .col-resizer {
          position: absolute;
          right: 0;
          top: 0;
          bottom: 0;
          width: 6px;
          cursor: col-resize;
          z-index: 2;
          user-select: none;
          display: flex;
          align-items: center;
          justify-content: center;
        }
        .col-resizer::after {
          content: '';
          display: block;
          width: 1px;
          height: 60%;
          background: #4a4a4a;
          border-radius: 1px;
          transition: background 0.1s;
        }
        .col-resizer:hover::after, .col-resizer.dragging::after { background: #007acc; }
        td {
          padding: 5px 12px;
          border-bottom: 1px solid #2a2a2a;
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
          font-size: 12px;
        }
        td.col-size { text-align: right; color: #888; }
        td.col-date { color: #888; }
        tr:hover td { background: #2a2d2e; }
        td a { color: #4ec9b0; text-decoration: none; }
        td a:hover { text-decoration: underline; }
        .thumb-cell { width: 70px; padding: 2px 6px; vertical-align: middle; }
        .thumb-cell img {
          max-width: 64px; max-height: 64px;
          width: auto; height: auto;
          display: block;
          margin: auto;
          border-radius: 3px;
        }
        #no-results {
          padding: 40px;
          text-align: center;
          color: #666;
          font-size: 13px;
        }
        #search-path {
          font-size: 11px;
          color: #888;
          padding: 4px 12px 0;
        }
        .folder-path-bar {
          padding: 6px 12px;
          font-size: 11px;
          color: #888;
          border-bottom: 1px solid #2a2a2a;
          background: #1e1e1e;
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }
        #loading-overlay {
          position: fixed;
          inset: 0;
          background: #1e1e1e;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          z-index: 9999;
          gap: 16px;
        }
        .loading-text {
          font-size: 13px;
          color: #888;
        }
      </style>
    </head>
    <body>
      <div id="loading-overlay">
        <svg width="36" height="36" viewBox="0 0 36 36" fill="none" xmlns="http://www.w3.org/2000/svg">
          <circle cx="18" cy="18" r="15" stroke="#3e3e3e" stroke-width="3"/>
          <path d="M18 3 A15 15 0 0 1 33 18" stroke="#007acc" stroke-width="3" stroke-linecap="round"/>
        </svg>
        <div class="loading-text">Loading snapshot…</div>
      </div>
      <div id="header" style="display:none">
        <div id="header-title-block">
          <h1>Directory Printout of:</h1>
          <div id="header-path"></div>
          <div id="header-meta">
            <span id="scan-date-display"></span>
            <span id="totals-display"></span>
          </div>
        </div>
        /*SNAPSHOT_LOGO*/
      </div>
      <div id="toolbar" style="display:none">
        <input type="text" id="search-input" placeholder="Search files…" autocomplete="off" spellcheck="false">
        <button id="search-btn">Search</button>
        <span id="stats"></span>
      </div>
      <div id="main" style="display:none">
        <div id="sidebar"></div>
        <div id="resizer"></div>
        <div id="content">
          <div id="file-table-wrap"></div>
        </div>
      </div>

      <script>
        const SNAPSHOT_DATA_RAW = /*SNAPSHOT_DATA*/;
        const CONFIG = /*SNAPSHOT_CONFIG*/;

        // ── Decompression helper ───────────────────────────────────────────────

        async function decompressData(b64String) {
          const binary = atob(b64String);
          const bytes = new Uint8Array(binary.length);
          for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
          const ds = new DecompressionStream('gzip');
          const writer = ds.writable.getWriter();
          writer.write(bytes);
          writer.close();
          const reader = ds.readable.getReader();
          const chunks = [];
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            chunks.push(value);
          }
          const totalLen = chunks.reduce((s, c) => s + c.length, 0);
          const merged = new Uint8Array(totalLen);
          let offset = 0;
          for (const c of chunks) { merged.set(c, offset); offset += c.length; }
          return JSON.parse(new TextDecoder().decode(merged));
        }

        // ── Utilities ──────────────────────────────────────────────────────────

        function formatSize(bytes) {
          if (bytes < 1024) return bytes + ' bytes';
          if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
          if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + ' MB';
          return (bytes / 1073741824).toFixed(1) + ' GB';
        }

        function formatDate(iso) {
          if (!iso) return '';
          try {
            return new Intl.DateTimeFormat(undefined, {
              year: 'numeric', month: 'short', day: 'numeric',
              hour: '2-digit', minute: '2-digit'
            }).format(new Date(iso));
          } catch (e) { return iso; }
        }

        // ── File type icons ────────────────────────────────────────────────────

        let _snapshotData = null; // resolved at init (may need async decompression)

        const SVG_ICONS = {
          folder: '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M1 3.5A1.5 1.5 0 0 1 2.5 2h3.086a1.5 1.5 0 0 1 1.06.44L7.56 3.5H13.5A1.5 1.5 0 0 1 15 5v7a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 1 12.5v-9Z" fill="#C8A84B" fill-opacity="0.85"/></svg>',
          folder_open: '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M1 3.5A1.5 1.5 0 0 1 2.5 2h3.086a1.5 1.5 0 0 1 1.06.44L7.56 3.5H13.5A1.5 1.5 0 0 1 15 5v7a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 1 12.5v-9Z" fill="#C8A84B" fill-opacity="0.55"/><path d="M1 6.5h14l-1.5 6H2.5L1 6.5Z" fill="#C8A84B" fill-opacity="0.85"/></svg>',
          image:  '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="1.5" y="2.5" width="13" height="11" rx="1.5" stroke="#888" stroke-width="1.2"/><circle cx="5.5" cy="6" r="1.2" fill="#888"/><path d="M1.5 10.5l3.5-3 3 3 2-2 3.5 3.5" stroke="#888" stroke-width="1.1" stroke-linejoin="round"/></svg>',
          video:  '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="1" y="3" width="10" height="10" rx="1.5" stroke="#888" stroke-width="1.2"/><path d="M11 6.5l4-2v7l-4-2V6.5Z" stroke="#888" stroke-width="1.2" stroke-linejoin="round"/></svg>',
          audio:  '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M4 6 A2.5 2.5 0 0 1 4 10" stroke="#888" stroke-width="1.3" stroke-linecap="round" fill="none"/><path d="M6.5 4 A5.5 5.5 0 0 1 6.5 12" stroke="#888" stroke-width="1.3" stroke-linecap="round" fill="none"/><path d="M9 2 A8 8 0 0 1 9 14" stroke="#888" stroke-width="1.3" stroke-linecap="round" fill="none"/></svg>',
          code:   '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><polyline points="5,4 1,8 5,12" stroke="#888" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round" fill="none"/><polyline points="11,4 15,8 11,12" stroke="#888" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round" fill="none"/><line x1="9.5" y1="2.5" x2="6.5" y2="13.5" stroke="#888" stroke-width="1.2" stroke-linecap="round"/></svg>',
          text:   '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="2" y="1.5" width="12" height="13" rx="1.5" stroke="#888" stroke-width="1.2"/><line x1="4.5" y1="5" x2="11.5" y2="5" stroke="#888" stroke-width="1.1" stroke-linecap="round"/><line x1="4.5" y1="8" x2="11.5" y2="8" stroke="#888" stroke-width="1.1" stroke-linecap="round"/><line x1="4.5" y1="11" x2="8.5" y2="11" stroke="#888" stroke-width="1.1" stroke-linecap="round"/></svg>',
          pdf:    '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="2" y="1.5" width="12" height="13" rx="1.5" stroke="#888" stroke-width="1.2"/><line x1="4.5" y1="5" x2="11.5" y2="5" stroke="#888" stroke-width="1.1" stroke-linecap="round"/><line x1="4.5" y1="8" x2="11.5" y2="8" stroke="#888" stroke-width="1.1" stroke-linecap="round"/><line x1="4.5" y1="11" x2="8.5" y2="11" stroke="#888" stroke-width="1.1" stroke-linecap="round"/></svg>',
          data:   '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><ellipse cx="8" cy="4.5" rx="5.5" ry="2" stroke="#888" stroke-width="1.2"/><path d="M2.5 4.5v3c0 1.1 2.46 2 5.5 2s5.5-.9 5.5-2v-3" stroke="#888" stroke-width="1.2"/><path d="M2.5 7.5v3c0 1.1 2.46 2 5.5 2s5.5-.9 5.5-2v-3" stroke="#888" stroke-width="1.2"/></svg>',
          archive:'<svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="1.5" y="3" width="13" height="10" rx="1.5" stroke="#888" stroke-width="1.2"/><rect x="1.5" y="3" width="13" height="3" rx="1" stroke="#888" stroke-width="1.2"/><line x1="6.5" y1="8" x2="9.5" y2="8" stroke="#888" stroke-width="1.2" stroke-linecap="round"/></svg>',
          binary: '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="2" y="1.5" width="12" height="13" rx="1.5" stroke="#888" stroke-width="1.2"/><text x="4.5" y="10.5" font-size="5.5" font-family="monospace" fill="#888">01</text></svg>',
          font:   '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M3 2h7l3 3v9a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1Z" stroke="#888" stroke-width="1.2"/><path d="M10 2v3h3" stroke="#888" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
          file:   '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M3 2h7l3 3v9a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1Z" stroke="#888" stroke-width="1.2"/><path d="M10 2v3h3" stroke="#888" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
        };

        const EXT_MAP = {
          // Images
          png:'image', jpg:'image', jpeg:'image', gif:'image', webp:'image', svg:'image',
          ico:'image', bmp:'image', tiff:'image', tif:'image', heic:'image', heif:'image', raw:'image',
          // Video
          mp4:'video', mov:'video', avi:'video', mkv:'video', wmv:'video', flv:'video', webm:'video', m4v:'video',
          // Audio
          mp3:'audio', wav:'audio', aac:'audio', flac:'audio', ogg:'audio', m4a:'audio', aiff:'audio',
          // PDF
          pdf:'pdf',
          // Code
          js:'code', ts:'code', jsx:'code', tsx:'code', mjs:'code', cjs:'code',
          swift:'code', py:'code', rb:'code', java:'code', kt:'code', go:'code', rs:'code',
          cpp:'code', c:'code', h:'code', cs:'code', php:'code', sh:'code', bash:'code', zsh:'code', fish:'code',
          html:'code', htm:'code', css:'code', scss:'code', sass:'code', less:'code',
          json:'code', xml:'code', yaml:'code', yml:'code', toml:'code', ini:'code', env:'code',
          sql:'code', graphql:'code', gql:'code', vue:'code', svelte:'code',
          // Text
          txt:'text', md:'text', markdown:'text', rtf:'text', log:'text', csv:'text', tsv:'text',
          // Data / DB
          db:'data', sqlite:'data', sqlite3:'data', parquet:'data',
          // Archives
          zip:'archive', tar:'archive', gz:'archive', bz2:'archive', xz:'archive',
          rar:'archive', '7z':'archive', dmg:'archive', pkg:'archive',
          // Binaries / executables
          exe:'binary', app:'binary', bin:'binary', dylib:'binary', so:'binary', dll:'binary', o:'binary',
          // Fonts
          ttf:'font', otf:'font', woff:'font', woff2:'font',
        };

        function fileIcon(node) {
          const key = node.isDirectory ? 'folder' : (EXT_MAP[(node.name.split('.').pop() || '').toLowerCase()] || 'file');
          return SVG_ICONS[key];
        }

        // ── State ──────────────────────────────────────────────────────────────

        let selectedNodePath = null;
        let sortCol = 'name';
        let sortDir = 1; // 1 = asc, -1 = desc
        let currentFiles = [];
        let searchMode = false;
        let searchResults = [];

        // ── Tree building ──────────────────────────────────────────────────────

        function buildTree(node, depth) {
          if (!node.isDirectory) return null;

          const wrapper = document.createElement('div');
          wrapper.className = 'tree-node';

          const childDirs = (node.children || []).filter(c => c.isDirectory);
          const hasChildren = childDirs.length > 0;

          // Row
          const row = document.createElement('div');
          row.className = 'tree-row';
          row.dataset.path = node.path;

          // Dotted horizontal connector
          const connector = document.createElement('span');
          connector.className = 'tree-connector';

          // Folder icon
          const icon = document.createElement('span');
          icon.className = 'tree-icon';
          icon.style.cssText = 'display:inline-flex;align-items:center;';
          icon.innerHTML = SVG_ICONS.folder;

          // Name
          const name = document.createElement('span');
          name.className = 'tree-name';
          name.textContent = node.name;
          name.title = node.path;

          row.appendChild(connector);
          row.appendChild(icon);
          row.appendChild(name);
          wrapper.appendChild(row);

          // Children container
          const childrenDiv = document.createElement('div');
          childrenDiv.className = 'tree-children collapsed';

          childDirs.forEach(child => {
            const childEl = buildTree(child, depth + 1);
            if (childEl) childrenDiv.appendChild(childEl);
          });

          wrapper.appendChild(childrenDiv);

          row.addEventListener('click', (e) => {
            e.stopPropagation();
            if (hasChildren) {
              const isCollapsed = childrenDiv.classList.contains('collapsed');
              childrenDiv.classList.toggle('collapsed');
              icon.innerHTML = isCollapsed ? SVG_ICONS.folder_open : SVG_ICONS.folder;
            }
            selectFolder(node, row);
          });

          // Register for navigation from file listing
          registerFolderNode(node, row);

          return wrapper;
        }

        function selectFolder(node, rowEl) {
          const prev = document.querySelector('.tree-row.selected');
          if (prev) prev.classList.remove('selected');
          rowEl.classList.add('selected');
          selectedNodePath = node.path;

          const dirs = (node.children || []).filter(c => c.isDirectory);
          const files = (node.children || []).filter(c => !c.isDirectory);
          currentFiles = [...dirs, ...files];
          renderFileTable(currentFiles, node.path);
          clearSearch();
        }

        // ── File table ─────────────────────────────────────────────────────────

        function renderFileTable(files, folderPath) {
          const wrap = document.getElementById('file-table-wrap');
          wrap.innerHTML = '';

          const pathBar = document.createElement('div');
          pathBar.className = 'folder-path-bar';
          pathBar.textContent = folderPath || '';
          wrap.appendChild(pathBar);

          if (files.length === 0) {
            const empty = document.createElement('div');
            empty.id = 'no-results';
            empty.textContent = 'No files in this folder.';
            wrap.appendChild(empty);
            updateStats(0);
            return;
          }

          const sorted = sortFiles([...files]);
          const table = buildTable(sorted, false);
          wrap.appendChild(table);
          updateStats(sorted.length);
        }

        function renderSearchResults(results) {
          const wrap = document.getElementById('file-table-wrap');
          wrap.innerHTML = '';

          if (results.length === 0) {
            const empty = document.createElement('div');
            empty.id = 'no-results';
            empty.textContent = 'No results found.';
            wrap.appendChild(empty);
            updateStats(0);
            return;
          }

          const sorted = sortFiles([...results]);
          const table = buildTable(sorted, true);
          wrap.appendChild(table);
          updateStats(sorted.length);
        }

        function buildTable(files, showPath) {
          const table = document.createElement('table');
          const hasThumbs = !!CONFIG.thumbnailsFolder;

          const thead = document.createElement('thead');
          const headerRow = document.createElement('tr');

          if (hasThumbs) {
            const thThumb = document.createElement('th');
            thThumb.style.cssText = 'width:70px;padding:3px 6px;';
            headerRow.appendChild(thThumb);
          }

          const cols = [
            { key: 'name', label: 'Name', cls: '' },
            { key: 'dateModified', label: 'Date Modified', cls: 'col-date' },
            { key: 'size', label: 'Size', cls: 'col-size' }
          ];

          cols.forEach(col => {
            const th = document.createElement('th');
            th.textContent = col.label;
            if (col.cls) th.classList.add(col.cls);
            if (sortCol === col.key) {
              th.className = sortDir === 1 ? 'sort-asc' : 'sort-desc';
            }
            th.addEventListener('click', () => {
              if (sortCol === col.key) {
                sortDir = -sortDir;
              } else {
                sortCol = col.key;
                sortDir = 1;
              }
              if (searchMode) {
                renderSearchResults(searchResults);
              } else {
                renderFileTable(currentFiles, selectedNodePath);
              }
            });
            headerRow.appendChild(th);
          });

          thead.appendChild(headerRow);
          table.appendChild(thead);

          const tbody = document.createElement('tbody');
          files.forEach(f => {
            const tr = document.createElement('tr');

            // Thumbnail cell (images only)
            if (hasThumbs) {
              const tdThumb = document.createElement('td');
              tdThumb.className = 'thumb-cell';
              const ext = (f.name.split('.').pop() || '').toLowerCase();
              const isImg = ['png','jpg','jpeg','gif','webp','bmp','tiff','tif','heic','heif',
                             'mp4','mov','m4v','avi','mkv','wmv','flv','webm',
                             'pdf','docx','xlsx','pptx','doc','xls','ppt',
                             'pages','numbers','keynote',
                             'usdz','obj','scn','abc','ply','stl'].includes(ext);
              if (!f.isDirectory && isImg && f.thumbFile) {
                const img = document.createElement('img');
                img.src = CONFIG.thumbnailsFolder + '/' + f.thumbFile;
                img.alt = '';
                img.loading = 'lazy';
                img.style.cssText = 'max-width:64px;max-height:64px;width:auto;height:auto;display:block;margin:auto;border-radius:3px;';
                tdThumb.appendChild(img);
              }
              tr.appendChild(tdThumb);
            }

            // Name cell
            const tdName = document.createElement('td');
            const icon = document.createElement('span');
            icon.style.cssText = 'margin-right:5px;flex-shrink:0;display:inline-flex;align-items:center;';
            icon.innerHTML = fileIcon(f);
            if (f.isDirectory) {
              const btn = document.createElement('span');
              btn.style.cssText = 'cursor:pointer;display:inline-flex;align-items:center;';
              btn.title = f.path;
              btn.appendChild(icon);
              const label = document.createElement('span');
              label.textContent = f.name;
              btn.appendChild(label);
              btn.addEventListener('click', () => navigateToFolder(f.path));
              tdName.appendChild(btn);
            } else if (CONFIG.linkToFiles && f.path) {
              const wrap = document.createElement('span');
              wrap.style.cssText = 'display:inline-flex;align-items:center;';
              wrap.appendChild(icon);
              const a = document.createElement('a');
              a.href = 'file://' + f.path;
              a.textContent = f.name;
              a.title = f.path;
              wrap.appendChild(a);
              tdName.appendChild(wrap);
            } else {
              const wrap = document.createElement('span');
              wrap.style.cssText = 'display:inline-flex;align-items:center;';
              wrap.appendChild(icon);
              const label = document.createElement('span');
              label.textContent = f.name;
              label.title = f.path || f.name;
              wrap.appendChild(label);
              tdName.appendChild(wrap);
            }
            if (showPath) {
              const pathSpan = document.createElement('div');
              pathSpan.style.cssText = 'font-size:10px;color:#666;margin-top:1px;overflow:hidden;text-overflow:ellipsis;';
              pathSpan.textContent = f.path || '';
              tdName.appendChild(pathSpan);
            }
            tr.appendChild(tdName);

            // Date cell
            const tdDate = document.createElement('td');
            tdDate.className = 'col-date';
            tdDate.textContent = formatDate(f.dateModified);
            tr.appendChild(tdDate);

            // Size cell
            const tdSize = document.createElement('td');
            tdSize.className = 'col-size';
            tdSize.textContent = formatSize(f.size || 0);
            tr.appendChild(tdSize);

            tbody.appendChild(tr);
          });

          table.appendChild(tbody);
          addColResizers(table);
          return table;
        }

        function sortFiles(files) {
          return files.sort((a, b) => {
            // Folders always above files
            if (a.isDirectory && !b.isDirectory) return -1;
            if (!a.isDirectory && b.isDirectory) return 1;
            // Within the same group, apply the selected sort
            let av, bv;
            if (sortCol === 'size') {
              av = a.size || 0;
              bv = b.size || 0;
            } else if (sortCol === 'dateModified') {
              av = a.dateModified || '';
              bv = b.dateModified || '';
            } else {
              av = (a.name || '').toLowerCase();
              bv = (b.name || '').toLowerCase();
            }
            if (av < bv) return -1 * sortDir;
            if (av > bv) return 1 * sortDir;
            return 0;
          });
        }

        function updateStats(count) {
          document.getElementById('stats').textContent = count + ' item' + (count !== 1 ? 's' : '');
        }

        // ── Navigate to folder from file listing ───────────────────────────────

        // Map of path → {node, labelEl} built during tree construction
        const folderMap = {};

        function registerFolderNode(node, labelEl) {
          folderMap[node.path] = { node, labelEl };
        }

        function navigateToFolder(path) {
          const entry = folderMap[path];
          if (!entry) return;

          // Expand all ancestor tree nodes so the target row is visible
          expandAncestors(entry.labelEl);

          selectFolder(entry.node, entry.labelEl);
          entry.labelEl.scrollIntoView({ block: 'nearest' });
        }

        // Walk up the DOM from a .tree-row and expand any collapsed .tree-children
        function expandAncestors(rowEl) {
          let el = rowEl.parentElement; // .tree-node
          while (el) {
            if (el.classList.contains('tree-node')) {
              const childrenDiv = el.querySelector(':scope > .tree-children');
              if (childrenDiv && childrenDiv.classList.contains('collapsed')) {
                childrenDiv.classList.remove('collapsed');
                const icon = el.querySelector(':scope > .tree-row .tree-icon');
                if (icon) icon.innerHTML = SVG_ICONS.folder_open;
              }
            }
            el = el.parentElement;
          }
        }

        // ── Search ─────────────────────────────────────────────────────────────

        function collectAllFiles(node, results) {
          if (!node.isDirectory) {
            results.push(node);
            return;
          }
          (node.children || []).forEach(child => collectAllFiles(child, results));
        }

        function doSearch(query) {
          if (!query) {
            clearSearch();
            return;
          }
          searchMode = true;
          const lower = query.toLowerCase();
          const all = [];
          collectAllFiles(_snapshotData.root, all);
          searchResults = all.filter(f => f.name.toLowerCase().includes(lower));
          renderSearchResults(searchResults);
        }

        function clearSearch() {
          searchMode = false;
          searchResults = [];
          const input = document.getElementById('search-input');
          if (input.value !== '') return; // don't clear if user is still typing
        }

        // ── Resizer ────────────────────────────────────────────────────────────

        (function initResizer() {
          const resizer = document.getElementById('resizer');
          const sidebar = document.getElementById('sidebar');
          let startX, startW;

          resizer.addEventListener('mousedown', e => {
            startX = e.clientX;
            startW = sidebar.offsetWidth;
            resizer.classList.add('dragging');
            document.addEventListener('mousemove', onMove);
            document.addEventListener('mouseup', onUp);
          });

          function onMove(e) {
            const w = Math.max(160, Math.min(480, startW + e.clientX - startX));
            sidebar.style.width = w + 'px';
          }

          function onUp() {
            resizer.classList.remove('dragging');
            document.removeEventListener('mousemove', onMove);
            document.removeEventListener('mouseup', onUp);
          }
        })();

        // ── Column resizing ────────────────────────────────────────────────────

        // Stored column widths (percentages), applied to each new table built
        let colWidths = [45, 30, 25];

        function applyColWidths(table) {
          const hasThumbs = !!CONFIG.thumbnailsFolder;
          const ths = table.querySelectorAll('thead th');
          // If thumbnails are present, th[0] is the fixed thumb column — skip it
          const offset = hasThumbs ? 1 : 0;
          colWidths.forEach((w, i) => {
            if (ths[i + offset]) ths[i + offset].style.width = w + '%';
          });
        }

        function addColResizers(table) {
          applyColWidths(table);
          const hasThumbs = !!CONFIG.thumbnailsFolder;
          const offset = hasThumbs ? 1 : 0;
          const ths = table.querySelectorAll('thead th');
          // Only add resizers to first two data columns (last fills remaining space)
          for (let i = offset; i < ths.length - 1; i++) {
            const handle = document.createElement('div');
            handle.className = 'col-resizer';
            handle.addEventListener('mousedown', makeColResizeHandler(table, i - offset));
            ths[i].appendChild(handle);
          }
        }

        function makeColResizeHandler(table, colIndex) {
          return function(e) {
            e.stopPropagation();
            e.preventDefault();
            const handle = e.target;
            handle.classList.add('dragging');
            const tableRect = table.getBoundingClientRect();
            const tableWidth = tableRect.width;
            const startX = e.clientX;
            const startWidths = [...colWidths];
            let didDrag = false;

            function onMove(ev) {
              didDrag = true;
              const delta = ev.clientX - startX;
              const deltaPct = (delta / tableWidth) * 100;
              let newCurrent = startWidths[colIndex] + deltaPct;
              let newNext = startWidths[colIndex + 1] - deltaPct;
              // Enforce minimum column width of 8%
              if (newCurrent < 8) { newNext += newCurrent - 8; newCurrent = 8; }
              if (newNext < 8) { newCurrent += newNext - 8; newNext = 8; }
              colWidths[colIndex] = newCurrent;
              colWidths[colIndex + 1] = newNext;
              applyColWidths(table);
            }

            function onUp() {
              handle.classList.remove('dragging');
              document.removeEventListener('mousemove', onMove);
              document.removeEventListener('mouseup', onUp);
              // Suppress the click event on the th if the user actually dragged
              if (didDrag) {
                const suppress = (ev) => { ev.stopPropagation(); };
                handle.closest('th').addEventListener('click', suppress, { capture: true, once: true });
              }
            }

            document.addEventListener('mousemove', onMove);
            document.addEventListener('mouseup', onUp);
          };
        }

        // ── Init ───────────────────────────────────────────────────────────────

        (async function init() {
          const data = CONFIG.compressed
            ? await decompressData(SNAPSHOT_DATA_RAW)
            : SNAPSHOT_DATA_RAW;

          _snapshotData = data;

          // Header
          document.getElementById('header-path').textContent = data.rootPath || '';
          document.getElementById('scan-date-display').textContent = data.scanDate ? formatDate(data.scanDate) : '';
          document.getElementById('totals-display').textContent =
            data.totalFiles + ' files, ' + data.totalFolders + ' folders';

          // Build tree
          const sidebar = document.getElementById('sidebar');
          const rootEl = buildTree(data.root, 0);
          if (rootEl) {
            sidebar.appendChild(rootEl);
            // Expand root and select it
            const rootRow = rootEl.querySelector('.tree-row');
            const rootChildren = rootEl.querySelector('.tree-children');
            const rootIcon = rootEl.querySelector('.tree-icon');
            if (rootChildren) {
              rootChildren.classList.remove('collapsed');
              if (rootIcon) rootIcon.innerHTML = SVG_ICONS.folder_open;
            }
            if (rootRow) {
              rootRow.classList.add('selected');
              selectedNodePath = data.root.path;
              const rootDirs = (data.root.children || []).filter(c => c.isDirectory);
              const rootFiles = (data.root.children || []).filter(c => !c.isDirectory);
              currentFiles = [...rootDirs, ...rootFiles];
              renderFileTable(currentFiles, data.root.path);
            }
          }

          // Search button and Enter key
          const searchInput = document.getElementById('search-input');
          const searchBtn = document.getElementById('search-btn');

          function runSearch() {
            const q = searchInput.value.trim();
            if (q) {
              doSearch(q);
            } else {
              searchMode = false;
              searchResults = [];
              renderFileTable(currentFiles, selectedNodePath);
            }
          }

          searchBtn.addEventListener('click', runSearch);
          searchInput.addEventListener('keydown', e => {
            if (e.key === 'Enter') runSearch();
          });

          // Hide loading overlay, show app
          document.getElementById('loading-overlay').style.display = 'none';
          document.getElementById('header').style.display = '';
          document.getElementById('toolbar').style.display = '';
          document.getElementById('main').style.display = '';
        })();
      </script>
    </body>
    </html>
    """
}
