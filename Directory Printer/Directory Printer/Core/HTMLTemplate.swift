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
          max-width: 320px;
          background: #3c3c3c;
          border: 1px solid #555;
          border-radius: 4px;
          color: #d4d4d4;
          padding: 4px 8px;
          font-size: 12px;
          outline: none;
        }
        #search-input:focus { border-color: #007acc; }
        #search-input::placeholder { color: #666; }
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
        th:nth-child(1) { width: 45%; }
        th:nth-child(2) { width: 30%; }
        th:nth-child(3) { width: 25%; text-align: right; }
        td {
          padding: 5px 12px;
          border-bottom: 1px solid #2a2a2a;
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
          font-size: 12px;
        }
        td:nth-child(3) { text-align: right; color: #888; }
        td:nth-child(2) { color: #888; }
        tr:hover td { background: #2a2d2e; }
        td a { color: #4ec9b0; text-decoration: none; }
        td a:hover { text-decoration: underline; }
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
        const SNAPSHOT_DATA = /*SNAPSHOT_DATA*/;
        const CONFIG = /*SNAPSHOT_CONFIG*/;

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
          icon.textContent = '📁';

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
              icon.textContent = isCollapsed ? '📂' : '📁';
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

          const thead = document.createElement('thead');
          const headerRow = document.createElement('tr');

          const cols = [
            { key: 'name', label: 'Name' },
            { key: 'dateModified', label: 'Date Modified' },
            { key: 'size', label: 'Size' }
          ];

          cols.forEach(col => {
            const th = document.createElement('th');
            th.textContent = col.label;
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

            // Name cell
            const tdName = document.createElement('td');
            if (f.isDirectory) {
              const btn = document.createElement('span');
              btn.style.cssText = 'cursor:pointer;';
              btn.textContent = '📁 ' + f.name;
              btn.title = f.path;
              btn.addEventListener('click', () => navigateToFolder(f.path));
              tdName.appendChild(btn);
            } else if (CONFIG.linkToFiles && f.path) {
              const a = document.createElement('a');
              a.href = 'file://' + f.path;
              a.textContent = f.name;
              a.title = f.path;
              tdName.appendChild(a);
            } else {
              tdName.textContent = f.name;
              tdName.title = f.path || f.name;
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
            tdDate.textContent = formatDate(f.dateModified);
            tr.appendChild(tdDate);

            // Size cell
            const tdSize = document.createElement('td');
            tdSize.textContent = formatSize(f.size || 0);
            tr.appendChild(tdSize);

            tbody.appendChild(tr);
          });

          table.appendChild(tbody);
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
                if (icon) icon.textContent = '📂';
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
          collectAllFiles(SNAPSHOT_DATA.root, all);
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

        // ── Init ───────────────────────────────────────────────────────────────

        (function init() {
          const data = SNAPSHOT_DATA;

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
              if (rootIcon) rootIcon.textContent = '📂';
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

          // Search input
          const searchInput = document.getElementById('search-input');
          let searchTimer;
          searchInput.addEventListener('input', () => {
            clearTimeout(searchTimer);
            searchTimer = setTimeout(() => {
              const q = searchInput.value.trim();
              if (q) {
                doSearch(q);
              } else {
                searchMode = false;
                searchResults = [];
                renderFileTable(currentFiles, selectedNodePath);
              }
            }, 300);
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
