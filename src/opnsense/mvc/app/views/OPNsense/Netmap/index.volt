<script src="/ui/js/d3.min.js"></script>

<style>
  :root {
    --nm-panel-bg:       #1e2229;
    --nm-panel-border:   #2d333d;
    --nm-panel-text:     #e8eaed;
    --nm-panel-muted:    #9aa0ac;
    --nm-panel-heading:  #ffffff;
    --nm-panel-code-bg:  #13161b;
    --nm-panel-code-fg:  #7dd3a8;
    --nm-panel-sep:      #2d333d;
    --nm-panel-row-alt:  rgba(255,255,255,.03);
    --nm-panel-accent:   #f6a623;
    --nm-panel-warn:     #d94f00;
    --nm-canvas-bg:      #f4f6f9;
    --nm-canvas-border:  #d0d7e0;
  }

  #nm-wrap    { display:flex; height:calc(100vh - 220px); min-height:420px; }
  #nm-canvas  { flex:1; position:relative; overflow:hidden; background:var(--nm-canvas-bg); border:1px solid var(--nm-canvas-border); border-radius:6px; }
  #nm-svg     { width:100%; height:100%; cursor:grab; display:block; }
  #nm-svg:active { cursor:grabbing; }

  .nm-link        { stroke:#b8c8d8; stroke-width:1.5px; fill:none; transition:opacity .2s,stroke-width .2s; cursor:pointer; }
  .nm-link.subnet { stroke:#6b9ac4; stroke-dasharray:8 4; }
  .nm-link.heavy  { stroke:#e67e22 !important; }

  .nm-link-flow     { fill:none; stroke-dasharray:8 16; stroke-linecap:round; opacity:.9; pointer-events:none; display:none; }
  .nm-link-flow.dl  { display:block; stroke:#d94f00; filter:drop-shadow(0 0 3px rgba(217,79,0,.6)); animation:nm-flow-dash .8s linear infinite; }
  .nm-link-flow.ul  { display:block; stroke:#2980b9; filter:drop-shadow(0 0 3px rgba(41,128,185,.6)); animation:nm-flow-dash-rev .8s linear infinite; }
  @keyframes nm-flow-dash     { to { stroke-dashoffset:-24; } }
  @keyframes nm-flow-dash-rev { to { stroke-dashoffset: 24; } }

  .nm-node { transition:opacity .2s; }
  .nm-node circle.nm-bg { stroke:#fff; stroke-width:2.5px; filter:drop-shadow(0 2px 4px rgba(0,0,0,.18)); transition:filter .15s,stroke .15s,stroke-width .15s; }
  .nm-node:hover   circle.nm-bg { filter:drop-shadow(0 3px 8px rgba(0,0,0,.32)) brightness(1.12); cursor:pointer; }
  .nm-node.selected circle.nm-bg { stroke:#f6a623; stroke-width:3.5px; filter:drop-shadow(0 0 8px rgba(243,156,18,.5)); }
  .nm-node.scanning circle.nm-bg { stroke:#e67e22; stroke-width:3px; animation:nm-pulse 1.2s ease-in-out infinite; }
  .nm-node.alert    circle.nm-bg { stroke:#e74c3c !important; stroke-dasharray:4 2; animation:nm-alert-pulse 1.5s infinite; }
  .nm-node.highlight circle.nm-bg { stroke:#e74c3c !important; stroke-width:4px !important; filter:drop-shadow(0 0 10px rgba(231,76,60,.8)) !important; }
  @keyframes nm-pulse      { 0%,100% { stroke-opacity:1; } 50% { stroke-opacity:.3; } }
  @keyframes nm-alert-pulse { 0%,100% { filter:drop-shadow(0 0 4px rgba(231,76,60,.8)); } 50% { filter:drop-shadow(0 0 14px rgba(231,76,60,.8)); } }

  .nm-label { font:600 10.5px/1.3 "Helvetica Neue",Arial,sans-serif; fill:#2c3e50; pointer-events:none; user-select:none; text-shadow:0 1px 3px rgba(255,255,255,.9); transition:opacity .2s; }

  #nm-panel      { width:0; overflow:hidden; transition:width .25s cubic-bezier(.4,0,.2,1); background:var(--nm-panel-bg); border-left:1px solid var(--nm-panel-border); flex-shrink:0; display:flex; flex-direction:column; }
  #nm-panel.open { width:350px; }
  #nm-panel-header  { display:flex; align-items:center; justify-content:space-between; padding:13px 16px; border-bottom:1px solid var(--nm-panel-border); background:rgba(255,255,255,.02); flex-shrink:0; }
  #nm-panel-title   { font:600 10.5px/1 "Helvetica Neue",Arial,sans-serif; letter-spacing:.09em; text-transform:uppercase; color:var(--nm-panel-muted); }
  #nm-panel-close   { background:none; border:none; cursor:pointer; padding:3px 7px; color:var(--nm-panel-muted); font-size:15px; line-height:1; border-radius:4px; transition:background .15s,color .15s; }
  #nm-panel-close:hover { background:rgba(255,255,255,.1); color:#fff; }
  #nm-panel-body    { padding:0; flex:1; overflow-y:auto; }
  #nm-panel-content { padding:16px; }
  #nm-panel-body::-webkit-scrollbar       { width:3px; }
  #nm-panel-body::-webkit-scrollbar-track { background:transparent; }
  #nm-panel-body::-webkit-scrollbar-thumb { background:var(--nm-panel-border); border-radius:2px; }

  .nm-ph       { display:flex; align-items:center; gap:12px; margin-bottom:14px; padding-bottom:14px; border-bottom:1px solid var(--nm-panel-sep); }
  .nm-ph-icon  { width:42px; height:42px; border-radius:10px; flex-shrink:0; display:flex; align-items:center; justify-content:center; font-size:21px; }
  .nm-ph-title { font:600 14.5px/1.2 "Helvetica Neue",Arial,sans-serif; color:var(--nm-panel-heading); margin-bottom:3px; }
  .nm-ph-sub   { font-size:11.5px; color:var(--nm-panel-muted); }

  .nm-info-table { width:100%; border-collapse:collapse; margin-bottom:4px; color:var(--nm-panel-text); }
  .nm-info-table tr { border-bottom:1px solid var(--nm-panel-sep); }
  .nm-info-table tr:last-child  { border-bottom:none; }
  .nm-info-table tr:nth-child(even) { background:var(--nm-panel-row-alt); }
  .nm-info-table th { width:35%; text-align:left; padding:7px 4px; font:500 10.5px/1 "Helvetica Neue",Arial,sans-serif; letter-spacing:.05em; text-transform:uppercase; white-space:nowrap; color:var(--nm-panel-muted); }
  .nm-info-table td { padding:7px 4px 7px 10px; word-break:break-all; color:var(--nm-panel-text); font-size:12.5px; }
  .nm-info-table code { background:var(--nm-panel-code-bg); color:var(--nm-panel-code-fg); padding:2px 6px; border-radius:4px; font-size:11.5px; font-family:"Fira Mono","Courier New",monospace; }

  .nm-section { font:600 10px/1 "Helvetica Neue",Arial,sans-serif; letter-spacing:.1em; text-transform:uppercase; color:var(--nm-panel-muted); margin:16px 0 8px; display:flex; align-items:center; gap:6px; }
  .nm-section::after { content:''; flex:1; height:1px; background:var(--nm-panel-sep); }

  .nm-traf-row  { display:flex; justify-content:space-between; align-items:baseline; margin-bottom:5px; }
  .nm-traf-lbl  { font-size:10.5px; color:var(--nm-panel-muted); }
  .nm-traf-val  { font:700 12.5px "Helvetica Neue",Arial,sans-serif; }
  .nm-traf-in   { color:#d94f00; }
  .nm-traf-out  { color:#2980b9; }
  .nm-bar-bg    { height:6px; background:rgba(255,255,255,.1); border-radius:3px; overflow:hidden; margin:8px 0 5px; }
  .nm-bar-fill  { height:100%; border-radius:3px; transition:width .5s ease; }
  .nm-traf-meta { display:flex; justify-content:space-between; font-size:10.5px; color:var(--nm-panel-muted); }

  .nm-ports { width:100%; border-collapse:collapse; font-size:11.5px; margin-top:6px; }
  .nm-ports thead th { background:#252b35; padding:5px 7px; text-align:left; font:600 10px "Helvetica Neue",Arial,sans-serif; letter-spacing:.06em; text-transform:uppercase; color:var(--nm-panel-muted); border-bottom:1px solid var(--nm-panel-sep); }
  .nm-ports tbody td { padding:5px 7px; border-bottom:1px solid var(--nm-panel-sep); vertical-align:middle; color:var(--nm-panel-text); }
  .nm-ports tbody tr:last-child td { border-bottom:none; }
  .nm-ports tbody tr:hover td { background:rgba(255,255,255,.04); }
  .nm-port-num  { font:700 12px "Fira Mono","Courier New",monospace; color:var(--nm-panel-accent); }
  .nm-port-svc  { color:#a8d8a8; }
  .nm-port-ver  { color:var(--nm-panel-muted); font-size:11px; }

  .nm-scan-btn          { width:100%; padding:9px 12px; border-radius:6px; border:none; cursor:pointer; font:600 12.5px "Helvetica Neue",Arial,sans-serif; letter-spacing:.02em; background:linear-gradient(135deg,#d94f00,#f6a623); color:#fff; transition:opacity .15s,transform .1s; display:flex; align-items:center; justify-content:center; gap:7px; }
  .nm-scan-btn:hover    { opacity:.88; }
  .nm-scan-btn:active   { transform:scale(.98); }
  .nm-scan-btn:disabled { opacity:.45; cursor:not-allowed; transform:none; }

  .nm-os-badge   { display:inline-flex; align-items:center; gap:6px; background:rgba(74,158,255,.12); border:1px solid rgba(74,158,255,.28); color:var(--nm-panel-accent); border-radius:20px; padding:4px 10px; font-size:11.5px; font-weight:600; margin-bottom:8px; }
  .nm-alert-card { background:rgba(231,76,60,.1); border-left:3px solid #e74c3c; padding:6px 10px; margin-bottom:6px; font-size:11.5px; color:var(--nm-panel-text); border-radius:0 4px 4px 0; }
  .nm-error-box  { background:rgba(231,76,60,.12); border:1px solid rgba(231,76,60,.3); color:#e74c3c; border-radius:6px; padding:8px 12px; font-size:12px; }

  #nm-toolbar { display:flex; gap:8px; align-items:center; margin-bottom:10px; flex-wrap:wrap; }
  #nm-toolbar select       { height:28px; padding:3px 8px; outline:none; border:1px solid var(--nm-canvas-border); border-radius:4px; background:var(--nm-canvas-bg); color:#2c3e50; font-size:12px; cursor:pointer; }
  #nm-toolbar input[type=text] { height:28px; padding:3px 8px; width:170px; font-size:12px; border:1px solid var(--nm-canvas-border); border-radius:4px; background:var(--nm-canvas-bg); }
  #nm-status     { margin-left:auto; font-size:11.5px; color:#6c757d; }

  .nm-flow-badge { display:inline-flex; align-items:center; gap:5px; font-size:11px; padding:3px 10px; border-radius:12px; font-weight:600; background:rgba(39,174,96,.12); color:#4caf50; border:1px solid rgba(39,174,96,.3); }

  #nm-legend { position:absolute; bottom:16px; left:16px; background:rgba(255,255,255,.93); backdrop-filter:blur(6px); padding:10px 14px; border-radius:8px; font-size:12px; color:#2c3e50; border:1px solid rgba(0,0,0,.1); pointer-events:none; line-height:2; box-shadow:0 2px 10px rgba(0,0,0,.1); }
  .nm-dot { display:inline-block; border-radius:50%;  vertical-align:middle; margin-right:7px; }
  .nm-sq  { display:inline-block; border-radius:3px;  vertical-align:middle; margin-right:7px; }

  .nm-tooltip { position:fixed; padding:8px 12px; background:rgba(0,0,0,.85); color:#fff; border-radius:6px; font-size:11.5px; pointer-events:none; opacity:0; transition:opacity .15s; z-index:9999; box-shadow:0 4px 12px rgba(0,0,0,.3); line-height:1.4; border:1px solid var(--nm-panel-sep); max-width:260px; }
</style>

<!-- Toolbar -->
<div id="nm-toolbar">
  <button id="nm-btn-refresh" class="btn btn-primary btn-sm"><i class="fa fa-refresh"></i> Refresh</button>
  <select id="nm-layout-select">
    <option value="tree" selected>Tree View</option>
    <option value="force">Force View</option>
  </select>
  <button id="nm-btn-rotate" class="btn btn-default btn-sm" title="Rotate Tree View"><i class="fa fa-repeat"></i> Rotate</button>
  <select id="nm-time-window">
    <option value="300">Last 5 Min</option>
    <option value="3600">Last 1 Hour</option>
    <option value="86400" selected>Last 24 Hours</option>
    <option value="604800">Last 7 Days</option>
  </select>
  <button id="nm-btn-fit"    class="btn btn-default btn-sm"><i class="fa fa-expand"></i> Fit View</button>
  <button id="nm-btn-export" class="btn btn-default btn-sm"><i class="fa fa-download"></i> Export SVG</button>
  <input type="text" id="nm-search" class="form-control" placeholder="Search IP, name, MAC…">
  <label style="font-size:11.5px;margin:0 0 0 4px;cursor:pointer;color:var(--nm-panel-muted);display:flex;align-items:center;gap:4px;" title="Hide hosts not seen in current window">
    <input type="checkbox" id="nm-hide-stale"> Hide Stale
  </label>
  <span id="nm-flow-indicator" class="nm-flow-badge" style="display:none;"><i class="fa fa-signal"></i> NetFlow enriched</span>
  <span id="nm-status">Loading…</span>
</div>

<!-- Graph + panel -->
<div id="nm-wrap">
  <div id="nm-canvas">
    <svg id="nm-svg"></svg>
    <div id="nm-tooltip" class="nm-tooltip"></div>
    <div id="nm-legend">
      <div><span class="nm-dot" style="width:18px;height:18px;background:#d94f00;"></span>Router</div>
      <div><span class="nm-sq"  style="width:16px;height:14px;background:#f6a623;"></span>Subnet</div>
      <div><span class="nm-dot" style="width:14px;height:14px;background:#8e44ad;"></span>VPN Tunnel</div>
      <div><span class="nm-dot" style="width:11px;height:11px;background:#a569bd;"></span>VPN Client</div>
      <div><span class="nm-dot" style="width:13px;height:13px;background:#27ae60;"></span>Host (active)</div>
      <div><span class="nm-dot" style="width:13px;height:13px;background:#adb5bd;"></span>Host (stale)</div>
      <div style="color:var(--nm-panel-muted);font-size:10.5px;margin-top:8px;">Tip: Alt/Ctrl-click nodes to find paths</div>
    </div>
  </div>
  <div id="nm-panel">
    <div id="nm-panel-header">
      <span id="nm-panel-title">Node Details</span>
      <button id="nm-panel-close" title="Close">✕</button>
    </div>
    <div id="nm-panel-body"><div id="nm-panel-content"></div></div>
  </div>
</div>

<script>
  $(function () {
    'use strict';

    const RADIUS  = { router: 26, subnet: 18, vpn: 16, host: 11, vpn_client: 9 };
    const COLOR   = { router: '#d94f00', subnet: '#f6a623', vpn: '#8e44ad', host: '#27ae60', vpn_client: '#a569bd', stale: '#adb5bd' };
    const CHARGE  = { router: -1200, subnet: -600, vpn: -500, host: -250, vpn_client: -160 };
    const LINK_D  = { 'router-subnet': 220, 'router-vpn': 200, 'subnet-host': 120, 'vpn-vpn_client': 100, default: 150 };
    const STALE_H = 24;
    const POLL_MS = 3000;
    const TOP_PORTS = 1000;
    const CANVAS_BG = '#f4f6f9';
    const SEARCH_DEBOUNCE_MS = 200;

    let sim, currentLayout = 'tree', treeDirection = 'horizontal', currentTimeWindow = '86400';
    let svgRoot, zoomG, zoomBehavior, linkSel, nodeSel, labelSel;
    let flowData = {}, flowAvail = false, maxTraffic = 0;
    let selectedId = null, scanTimer = null, currentJob = null, searchTimer = null;
    let baseNodes = [], baseLinks = [], currentNodes = [], currentLinks = [];
    let nodeById = Object.create(null);
    let loadSeq = 0;
    let pathAnchorId = null, pathNodes = new Set(), pathLinks = new Set();

    init();

    $('#nm-btn-refresh').on('click', loadAll);
    $('#nm-btn-fit').on('click', fitView);
    $('#nm-btn-export').on('click', exportSVG);
    $('#nm-btn-rotate').on('click', function () {
      treeDirection = treeDirection === 'horizontal' ? 'vertical' : 'horizontal';
      refreshLayout();
    });
    $('#nm-layout-select').on('change', function (e) {
      currentLayout = e.target.value;
      $('#nm-btn-rotate').toggle(currentLayout === 'tree');
      refreshLayout();
    });
    $('#nm-time-window').on('change', function (e) { currentTimeWindow = e.target.value; loadAll(); });
    $('#nm-search').on('input', function () { clearTimeout(searchTimer); searchTimer = setTimeout(updateHighlighting, SEARCH_DEBOUNCE_MS); });
    $('#nm-hide-stale').on('change', refreshLayout);
    $('#nm-panel-close').on('click', closePanel);
    $('#nm-svg').on('click', function (e) { if (e.target === this) { closePanel(); clearPath(); } });
    $(window).on('beforeunload', stopScan);

    function init() {
      $('#nm-btn-rotate').toggle(currentLayout === 'tree');
      const c = document.getElementById('nm-canvas');
      svgRoot = d3.select('#nm-svg').attr('viewBox', `0 0 ${c.clientWidth} ${c.clientHeight}`);
      zoomBehavior = d3.behavior.zoom().scaleExtent([0.06, 6])
        .on('zoom', function () { zoomG.attr('transform', 'translate(' + d3.event.translate + ')scale(' + d3.event.scale + ')'); });
      svgRoot.call(zoomBehavior);
      svgRoot.on('dblclick.zoom', null);
      zoomG = svgRoot.append('g');
      zoomG.append('g').attr('class', 'nm-links-layer');
      zoomG.append('g').attr('class', 'nm-nodes-layer');
      zoomG.append('g').attr('class', 'nm-labels-layer');
      loadAll();
    }

    function loadAll() {
      const seq = ++loadSeq;
      setStatus('Loading…');
      stopScan(); closePanel(); clearPath();
      let topoData = null, topoDone = false, flowDone = false;

      ajaxGet('/api/netmap/map/topology', { window: currentTimeWindow }, function (data) {
        if (seq !== loadSeq) return;
        topoData = data; topoDone = true;
        if (flowDone) renderAll(topoData);
      });

      ajaxGet('/api/netmap/flow/summary', { window: currentTimeWindow }, function (data) {
        if (seq !== loadSeq) return;
        if (data && data.available && data.hosts) {
          flowData = data.hosts;
          flowAvail = true;
          maxTraffic = Object.keys(flowData).reduce(function (m, k) {
            const h = flowData[k]; return Math.max(m, (h.in || 0) + (h.out || 0));
          }, 0);
          $('#nm-flow-indicator').show();
        } else {
          flowData = {}; flowAvail = false; maxTraffic = 0;
          $('#nm-flow-indicator').hide();
        }
        flowDone = true;
        if (topoDone && topoData) renderAll(topoData);
      });
    }

    function renderAll(data) {
      if (!data || !Array.isArray(data.nodes)) { setStatus('No data returned from API.'); return; }
      baseNodes = data.nodes;
      baseLinks = data.links || [];
      baseNodes.forEach(function (n) {
        if (n.type === 'host' && n.ip && flowData[n.ip]) n.flow = flowData[n.ip];
      });
      refreshLayout();
    }

    function applyFilters() {
      const hideStale = $('#nm-hide-stale').is(':checked');
      const baseById = Object.create(null);
      baseNodes.forEach(function (n) { baseById[n.id] = n; });

      const interfaceIps = new Map();
      baseNodes.forEach(function (n) { if (n.type === 'subnet' && n.ip) interfaceIps.set(n.ip, n); });

      // Stage interface-IP flow totals before clearing subnet accumulators.
      const interfaceFlows = Object.create(null);
      baseNodes.forEach(function (n) {
        if (n.type !== 'host' || !n.ip || !n.flow) return;
        const subnet = interfaceIps.get(n.ip);
        if (!subnet) return;
        const acc = interfaceFlows[subnet.id] || { in: 0, out: 0, flows: 0 };
        acc.in += (n.flow.in || 0); acc.out += (n.flow.out || 0); acc.flows += (n.flow.flows || 0);
        interfaceFlows[subnet.id] = acc;
      });

      currentNodes = baseNodes.filter(function (n) {
        if (n.type === 'host' && n.ip && interfaceIps.has(n.ip)) return false;
        if (hideStale && (n.type === 'host' || n.type === 'vpn_client') && isStale(n)) return false;
        return true;
      });

      nodeById = Object.create(null);
      currentNodes.forEach(function (n) { nodeById[n.id] = n; });

      currentNodes.forEach(function (n) {
        if (n.type !== 'subnet') return;
        const seed = interfaceFlows[n.id];
        n.flow = seed ? { in: seed.in, out: seed.out, flows: seed.flows } : { in: 0, out: 0, flows: 0 };
      });

      currentNodes.forEach(function (n) {
        if (n.type !== 'host' || !n.flow) return;
        const parentLink = baseLinks.find(function (l) {
          return (typeof l.target === 'object' ? l.target.id : l.target) === n.id;
        });
        if (!parentLink) return;
        const sId = typeof parentLink.source === 'object' ? parentLink.source.id : parentLink.source;
        const pNode = nodeById[sId];
        if (pNode && pNode.type === 'subnet') {
          pNode.flow.in += (n.flow.in || 0); pNode.flow.out += (n.flow.out || 0); pNode.flow.flows += (n.flow.flows || 0);
        }
      });

      currentNodes.forEach(function (n) {
        n.trafficTotal = (n.flow && n.flow.in || 0) + (n.flow && n.flow.out || 0);
        n.trafficNorm  = maxTraffic > 0 ? n.trafficTotal / maxTraffic : 0;
      });

      currentLinks = baseLinks.filter(function (l) {
        const s = typeof l.source === 'object' ? l.source.id : l.source;
        const t = typeof l.target === 'object' ? l.target.id : l.target;
        return (s in nodeById) && (t in nodeById);
      });

      currentLinks.forEach(function (l) {
        const sId = typeof l.source === 'object' ? l.source.id : l.source;
        const tId = typeof l.target === 'object' ? l.target.id : l.target;
        l.traffic = Math.max((nodeById[tId] || {}).trafficTotal || 0, (nodeById[sId] || {}).trafficTotal || 0);
      });

      let maxLinkTraffic = 0;
      currentLinks.forEach(function (l) { if (l.traffic > maxLinkTraffic) maxLinkTraffic = l.traffic; });
      currentLinks.forEach(function (l) { l.trafficNorm = maxLinkTraffic > 0 ? l.traffic / maxLinkTraffic : 0; l.isTopTalkerLink = false; });

      currentLinks.slice().sort(function (a, b) { return b.traffic - a.traffic; }).slice(0, 10)
        .filter(function (l) {
          if (l.traffic <= 0) return false;
          const sId = typeof l.source === 'object' ? l.source.id : l.source;
          const tId = typeof l.target === 'object' ? l.target.id : l.target;
          return [((nodeById[sId] || {}).type || ''), ((nodeById[tId] || {}).type || '')].sort().join('-') !== 'host-subnet';
        })
        .forEach(function (l) { l.isTopTalkerLink = true; });

      const hc = currentNodes.filter(function (n) { return n.type === 'host'; }).length;
      const vc = currentNodes.filter(function (n) { return n.type === 'vpn_client'; }).length;
      setStatus(currentNodes.length + ' nodes · ' + hc + ' host' + (hc !== 1 ? 's' : '') +
        (vc > 0 ? ' · ' + vc + ' VPN client' + (vc !== 1 ? 's' : '') : '') +
        (flowAvail ? ' · NetFlow enriched' : ''));
    }

    function refreshLayout() {
      if (!baseNodes || !baseNodes.length) return;
      applyFilters();
      if (sim) { sim.stop(); sim = null; }
      zoomG.select('.nm-links-layer').selectAll('*').remove();
      zoomG.select('.nm-nodes-layer').selectAll('*').remove();
      zoomG.select('.nm-labels-layer').selectAll('*').remove();
      currentNodes.forEach(function (n) {
        delete n.children; delete n.parent; delete n.depth; delete n.parentLinkAdded;
        if (currentLayout !== 'force') { n.fixed = false; delete n.px; delete n.py; }
      });
      if (currentLayout === 'tree') renderTree(currentNodes, currentLinks);
      else renderForce(currentNodes, currentLinks);
    }

    // --- Shared helpers ---

    function resolveLinkEnd(end) {
      if (end && typeof end === 'object') return end;
      if (typeof end === 'number' && currentNodes[end]) return currentNodes[end];
      return null;
    }

    function linkId(l) {
      const s = typeof l.source === 'object' ? l.source.id : (l._sId != null ? l._sId : l.source);
      const t = typeof l.target === 'object' ? l.target.id : (l._tId != null ? l._tId : l.target);
      return s + '-' + t;
    }

    function endpointType(l, which) {
      const direct = which === 'source'
        ? (typeof l.source === 'object' ? l.source.type : null)
        : (typeof l.target === 'object' ? l.target.type : null);
      if (direct) return direct;
      return which === 'source' ? (l._sType || null) : (l._tType || null);
    }

    function getLinkColor(d) {
      if (d.interface) {
        const iface = String(d.interface).toLowerCase();
        if (iface.includes('wan'))  return 'rgba(231,76,60,0.22)';
        if (iface.includes('vlan')) return 'rgba(155,89,182,0.22)';
      }
      if (d.isTopTalkerLink) return 'rgba(230,126,34,0.22)';
      const tgtId = typeof d.target === 'object' ? d.target.id : (d._tId != null ? d._tId : null);
      if (tgtId) {
        const tNode = nodeById[tgtId];
        if (tNode && tNode.type === 'host' && tNode.flow) {
          const f = tNode.flow;
          if ((f.in || 0) + (f.out || 0) > 1024) {
            if ((f.in  || 0) > (f.out || 0) * 1.1) return 'rgba(217,79,0,0.18)';
            if ((f.out || 0) > (f.in  || 0) * 1.1) return 'rgba(41,128,185,0.18)';
          }
        }
      }
      return endpointType(d, 'source') === 'router' ? '#6b9ac4' : '#b8c8d8';
    }

    function linkClass(d) {
      return (endpointType(d, 'source') + '-' + endpointType(d, 'target')) === 'router-subnet' ? ' subnet' : '';
    }

    function flowClassFor(targetNode) {
      if (!targetNode || targetNode.type !== 'host' || !targetNode.flow) return 'nm-link-flow';
      const f = targetNode.flow, total = (f.in || 0) + (f.out || 0);
      if (total <= 1024) return 'nm-link-flow';
      if ((f.in  || 0) > (f.out || 0) * 1.1) return 'nm-link-flow dl';
      if ((f.out || 0) > (f.in  || 0) * 1.1) return 'nm-link-flow ul';
      return 'nm-link-flow';
    }

    function subLabelText(d) {
      if (d.type === 'subnet') return d.ip || d.cidr || '';
      if (d.type === 'host')   return d.hostname ? trunc(d.ip, 14) : (d.osName ? trunc(d.osName, 12) : '');
      return '';
    }

    // Appends mask, bg circle, icon text, flow ring to a node selection.
    function buildNodeBase(sel) {
      sel.append('circle').attr('class', 'nm-mask')
        .attr('r', function (d) { return nodeRadius(d) + 6; })
        .attr('fill', CANVAS_BG).attr('stroke', 'none');
      sel.append('circle').attr('class', 'nm-bg').attr('r', nodeRadius).attr('fill', nodeColor);
      sel.append('text')
        .attr('text-anchor', 'middle').attr('dominant-baseline', 'central')
        .attr('font-size', function (d) { return Math.floor(nodeRadius(d) * 0.68) + 'px'; })
        .attr('fill', '#fff').attr('pointer-events', 'none').text(nodeIcon);
      sel.filter(function (d) { return d.type === 'host' && d.flow; })
        .append('circle').attr('class', 'nm-ring')
        .attr('r', function (d) { return nodeRadius(d) + 3.5; })
        .attr('fill', 'none').attr('stroke', '#f6a623').attr('stroke-width', 2)
        .attr('stroke-dasharray', trafficArc).attr('opacity', 0.8);
    }

    // --- Path finding ---

    function calculatePath(startId, endId) {
      if (startId === endId || !(startId in nodeById) || !(endId in nodeById)) return null;
      const adj = Object.create(null);
      currentLinks.forEach(function (l) {
        const s = typeof l.source === 'object' ? l.source.id : l.source;
        const t = typeof l.target === 'object' ? l.target.id : l.target;
        (adj[s] = adj[s] || []).push(t);
        (adj[t] = adj[t] || []).push(s);
      });
      const queue = [[startId]], visited = new Set([startId]);
      while (queue.length) {
        const path = queue.shift(), curr = path[path.length - 1];
        if (curr === endId) return path;
        (adj[curr] || []).forEach(function (n) {
          if (!visited.has(n)) { visited.add(n); queue.push(path.concat(n)); }
        });
      }
      return null;
    }

    function clearPath() {
      pathAnchorId = null; pathNodes.clear(); pathLinks.clear(); updateHighlighting();
    }

    function updateHighlighting() {
      if (!nodeSel || !linkSel || !labelSel) return;
      const term = ($('#nm-search').val() || '').toLowerCase().trim();

      nodeSel.classed('highlight', function (d) {
        if (pathAnchorId && pathNodes.has(d.id)) return true;
        if (!term) return false;
        return [d.ip, d.label, d.hostname, d.vendor, d.mac].filter(Boolean).join(' ').toLowerCase().indexOf(term) !== -1;
      });
      nodeSel.style('opacity',  function (d) { return (pathAnchorId && !pathNodes.has(d.id)) ? 0.2 : (isStale(d) ? 0.35 : 1); });
      labelSel.style('opacity', function (d) { return (pathAnchorId && !pathNodes.has(d.id)) ? 0.2 : (isStale(d) ? 0.35 : 1); });
      linkSel.style('opacity', function (d) { return (pathAnchorId && !pathLinks.has(linkId(d))) ? 0.2 : 1; });
      linkSel.select('.nm-link')
        .classed('heavy', function (d) { return (pathAnchorId && pathLinks.has(linkId(d))) || !!d.isTopTalkerLink; })
        .style('stroke', getLinkColor)
        .style('stroke-width', function (d) { return (1.5 + (d.trafficNorm || 0) * 4) + 'px'; });
      linkSel.select('.nm-link-flow')
        .attr('class', function (d) { return flowClassFor(typeof d.target === 'object' ? d.target : (nodeById[d._tId] || null)); })
        .style('stroke-width', function (d) { return (3 + (d.trafficNorm || 0) * 4) + 'px'; });
    }

    // --- Tooltips ---

    const tooltip = d3.select('#nm-tooltip');

    function positionTooltip() {
      const node = tooltip.node(); if (!node) return;
      const pad = 14;
      let x = d3.event.clientX + 15, y = d3.event.clientY - 20;
      const rect = node.getBoundingClientRect();
      if (x + rect.width  + pad > window.innerWidth)  x = window.innerWidth  - rect.width  - pad;
      if (y + rect.height + pad > window.innerHeight)  y = window.innerHeight - rect.height - pad;
      if (x < pad) x = pad; if (y < pad) y = pad;
      tooltip.style('left', x + 'px').style('top', y + 'px');
    }

    function showTooltip(d) {
      let html = `<strong>${escH(d.label || d.hostname || d.ip || d.id)}</strong>`;
      if (d.ip)     html += `<br><span style="color:#d94f00;">${escH(d.ip)}</span>`;
      if (d.vendor) html += `<br><span style="color:#9aa0ac;font-size:10.5px;">${escH(d.vendor)}</span>`;
      if (d.osName) html += `<br><i class="fa fa-desktop" style="color:#a8d8a8"></i> OS: ${escH(d.osName)} (~${d.osAccuracy}%)`;
      if (d.flow)   html += `<br><i class="fa fa-signal" style="color:#f6a623"></i> ${fmtBytes((d.flow.in || 0) + (d.flow.out || 0))} traffic`;
      tooltip.html(html).style('opacity', 1);
      positionTooltip();
    }

    function showLinkTooltip(d) {
      const src = resolveLinkEnd(d.source) || {}, tgt = resolveLinkEnd(d.target) || {};
      let html = `<strong>Link: ${escH(src.label || src.ip || src.id || '?')} ↔ ${escH(tgt.label || tgt.ip || tgt.id || '?')}</strong>`;
      const f = (tgt.type === 'subnet' || tgt.type === 'host') ? tgt.flow : (src.flow || null);
      if (f && ((f.in || 0) > 0 || (f.out || 0) > 0))
        html += `<br><i class="fa fa-signal" style="color:#f6a623"></i> ${fmtBytes((f.in || 0) + (f.out || 0))} traffic`;
      tooltip.html(html).style('opacity', 1);
      positionTooltip();
    }

    function hideTooltip() { tooltip.style('opacity', 0); }
    function moveTooltip() { positionTooltip(); }

    // --- Node interaction ---

    function handleNodeInteraction(d) {
      if (d3.event.defaultPrevented) return;
      d3.event.stopPropagation();
      if (d3.event.altKey || d3.event.ctrlKey || d3.event.metaKey) {
        if (!pathAnchorId) {
          pathAnchorId = d.id; pathNodes.add(d.id); updateHighlighting();
        } else if (pathAnchorId !== d.id) {
          const path = calculatePath(pathAnchorId, d.id);
          if (path) {
            pathNodes = new Set(path); pathLinks.clear();
            for (let i = 0; i < path.length - 1; i++) {
              pathLinks.add(path[i] + '-' + path[i + 1]);
              pathLinks.add(path[i + 1] + '-' + path[i]);
            }
          } else { pathNodes.clear(); pathLinks.clear(); pathNodes.add(d.id); pathAnchorId = d.id; }
          updateHighlighting();
        } else { clearPath(); }
        return;
      }
      clearPath(); selectNode(d); hideTooltip();
    }

    // --- Tree: hierarchy builder ---

    function buildHierarchy(nodes, links) {
      if (!nodes || !nodes.length) return null;
      const root    = nodes.find(function (n) { return n.type === 'router'; }) || nodes[0];
      const nodeMap = Object.create(null);
      const rank    = { router: 0, subnet: 1, vpn: 1, host: 2, vpn_client: 2 };
      nodes.forEach(function (n) { n.children = []; n.parentLinkAdded = false; delete n.parent; delete n.depth; delete n.fixed; nodeMap[n.id] = n; });
      links.forEach(function (l) {
        const src = nodeMap[typeof l.source === 'object' ? l.source.id : l.source];
        const tgt = nodeMap[typeof l.target === 'object' ? l.target.id : l.target];
        if (!src || !tgt) return;
        const sr = rank[src.type] != null ? rank[src.type] : 99;
        const tr = rank[tgt.type] != null ? rank[tgt.type] : 99;
        if (sr <= tr) { if (!tgt.parentLinkAdded) { src.children.push(tgt); tgt.parentLinkAdded = true; } }
        else          { if (!src.parentLinkAdded) { tgt.children.push(src); src.parentLinkAdded = true; } }
      });
      nodes.forEach(function (n) {
        if (n !== root && !n.parentLinkAdded) { root.children.push(n); n.parentLinkAdded = true; }
        if (n.children.length === 0) delete n.children;
      });
      return root;
    }

    // --- D3 v3 tidy tree ---

    function renderTree(nodes, links) {
      const root = buildHierarchy(nodes, links);
      if (!root) return;
      const isHoriz = (treeDirection === 'horizontal');

      const tree = d3.layout.tree()
        .nodeSize(isHoriz ? [100, 260] : [100, 240])
        .separation(function (a, b) { return a.parent == b.parent ? 1 : 1.3; });

      const treeNodes = tree.nodes(root);
      const treeLinks = tree.links(treeNodes);

      // Copy traffic metadata from currentLinks onto treeLinks.
      const linkByPair = Object.create(null);
      currentLinks.forEach(function (l) {
        const s = typeof l.source === 'object' ? l.source.id : l.source;
        const t = typeof l.target === 'object' ? l.target.id : l.target;
        linkByPair[s + '|' + t] = linkByPair[t + '|' + s] = l;
      });
      treeLinks.forEach(function (tl) {
        const cl = linkByPair[tl.source.id + '|' + tl.target.id];
        if (cl) {
          tl.trafficNorm = cl.trafficNorm; tl.isTopTalkerLink = cl.isTopTalkerLink; tl.interface = cl.interface;
          tl._sId = typeof cl.source === 'object' ? cl.source.id : cl.source;
          tl._tId = typeof cl.target === 'object' ? cl.target.id : cl.target;
        }
      });

      const diagonal = d3.svg.diagonal().projection(function (d) { return isHoriz ? [d.y, d.x] : [d.x, d.y]; });
      const pos      = function (d) { return isHoriz ? 'translate(' + d.y + ',' + d.x + ')' : 'translate(' + d.x + ',' + d.y + ')'; };

      linkSel = zoomG.select('.nm-links-layer').selectAll('.nm-link-group')
        .data(treeLinks, function (d) { return d.source.id + '-' + d.target.id; });
      const linkEnter = linkSel.enter().append('g').attr('class', 'nm-link-group');

      linkEnter.append('path')
        .attr('class', function (d) { return 'nm-link' + linkClass(d); })
        .on('click', function (d) {
          if (d3.event.defaultPrevented) return; d3.event.stopPropagation();
          const t = d.target; if (t && (t.type === 'subnet' || t.type === 'host')) selectNode(t);
        })
        .on('mouseover', function (d) { d3.select(this).style('stroke-width', (3 + (d.trafficNorm || 0) * 4) + 'px'); showLinkTooltip(d); })
        .on('mouseout',  function (d) { d3.select(this).style('stroke-width', (1.5 + (d.trafficNorm || 0) * 4) + 'px'); hideTooltip(); })
        .on('mousemove', moveTooltip);
      linkEnter.append('path').attr('class', 'nm-link-flow');

      linkSel.select('.nm-link').attr('d', diagonal).style('stroke', getLinkColor);
      linkSel.select('.nm-link-flow').attr('d', diagonal).attr('class', function (d) { return flowClassFor(d.target); });

      nodeSel = zoomG.select('.nm-nodes-layer').selectAll('.nm-node')
        .data(treeNodes, function (d) { return d.id; }).enter()
        .append('g').attr('class', 'nm-node')
        .attr('transform', pos)
        .on('click', handleNodeInteraction)
        .on('mouseover', showTooltip).on('mousemove', moveTooltip).on('mouseout', hideTooltip);

      buildNodeBase(nodeSel);

      // Sub-label: IP under hostname, or CIDR under subnet name.
      nodeSel.append('text').attr('class', 'nm-node-sub-label')
        .attr('text-anchor', function (d) { return (!isHoriz || d.type === 'router' || d.type === 'subnet') ? 'middle' : 'start'; })
        .attr('dominant-baseline', 'central')
        .attr('dy', function (d) {
          if (!isHoriz) return nodeRadius(d) + 26;
          return (d.type === 'router' || d.type === 'subnet') ? 24 : 16;
        })
        .attr('dx', function (d) { return (isHoriz && d.type !== 'router' && d.type !== 'subnet') ? nodeRadius(d) + 12 : 0; })
        .attr('font-size', '9px').attr('fill', '#9aa0ac').attr('pointer-events', 'none')
        .text(subLabelText);

      labelSel = zoomG.select('.nm-labels-layer').selectAll('.nm-label')
        .data(treeNodes, function (d) { return d.id; }).enter()
        .append('text').attr('class', 'nm-label').attr('pointer-events', 'none')
        .attr('transform', pos)
        .attr('dy', function (d) {
          if (!isHoriz) return (d.type === 'router' || d.type === 'subnet') ? -nodeRadius(d) - 12 : nodeRadius(d) + 14;
          return (d.type === 'router' || d.type === 'subnet') ? -16 : -2;
        })
        .attr('dx', function (d) { return (isHoriz && d.type !== 'router' && d.type !== 'subnet') ? nodeRadius(d) + 12 : 0; })
        .attr('text-anchor', function (d) { return (!isHoriz || d.type === 'router' || d.type === 'subnet') ? 'middle' : 'start'; })
        .text(function (d) { return trunc(d.label || d.ip || d.id, 14); });

      requestAnimationFrame(function () { requestAnimationFrame(function () { updateHighlighting(); fitView(); }); });
    }

    // --- D3 v3 force graph ---

    function renderForce(nodes, links) {
      const c = document.getElementById('nm-canvas');
      const W = Math.max(c.clientWidth, 800), H = Math.max(c.clientHeight, 600);

      nodes.forEach(function (n) {
        n.x = W / 2 + (Math.random() - 0.5) * 50; n.y = H / 2 + (Math.random() - 0.5) * 50;
        n.px = n.x; n.py = n.y; n.fixed = false;
      });

      const nodeIndex = Object.create(null);
      nodes.forEach(function (n, i) { nodeIndex[n.id] = i; });

      const mappedLinks = [];
      links.forEach(function (l) {
        const srcId = typeof l.source === 'object' ? l.source.id : l.source;
        const tgtId = typeof l.target === 'object' ? l.target.id : l.target;
        const si = nodeIndex[srcId], ti = nodeIndex[tgtId];
        if (si == null || ti == null) return;
        mappedLinks.push(Object.assign({}, l, { source: si, target: ti, _sId: srcId, _tId: tgtId, _sType: nodes[si].type, _tType: nodes[ti].type }));
      });

      sim = d3.layout.force().nodes(nodes).links(mappedLinks).size([W, H])
        .linkDistance(function (d) { return LINK_D[(d._sType || '?') + '-' + (d._tType || '?')] || LINK_D.default; })
        .charge(function (d) { return CHARGE[d.type] || -250; })
        .gravity(0.04).on('tick', tickForce);

      const drag = sim.drag()
        .on('dragstart.custom', function () { if (d3.event && d3.event.sourceEvent) d3.event.sourceEvent.stopPropagation(); hideTooltip(); })
        .on('dragend.custom', function (d) { d.fixed = false; });

      linkSel = zoomG.select('.nm-links-layer').selectAll('.nm-link-group')
        .data(mappedLinks).enter().append('g').attr('class', 'nm-link-group');

      linkSel.append('line')
        .attr('class', function (d) { return 'nm-link' + linkClass(d); })
        .style('stroke', getLinkColor)
        .on('click', function (d) {
          if (d3.event.defaultPrevented) return; d3.event.stopPropagation();
          const t = resolveLinkEnd(d.target); if (t && (t.type === 'subnet' || t.type === 'host')) selectNode(t);
        })
        .on('mouseover', function (d) { d3.select(this).style('stroke-width', (3 + (d.trafficNorm || 0) * 4) + 'px'); showLinkTooltip(d); })
        .on('mouseout',  function (d) { d3.select(this).style('stroke-width', (1.5 + (d.trafficNorm || 0) * 4) + 'px'); hideTooltip(); })
        .on('mousemove', moveTooltip);
      linkSel.append('line').attr('class', function (d) { return flowClassFor(resolveLinkEnd(d.target)); });

      nodeSel = zoomG.select('.nm-nodes-layer').selectAll('.nm-node')
        .data(nodes, function (d) { return d.id; }).enter()
        .append('g').attr('class', 'nm-node')
        .call(drag)
        .on('click', handleNodeInteraction)
        .on('mouseover', showTooltip).on('mousemove', moveTooltip).on('mouseout', hideTooltip);

      buildNodeBase(nodeSel);

      nodeSel.append('text').attr('class', 'nm-node-sub-label')
        .attr('text-anchor', 'middle').attr('dominant-baseline', 'central')
        .attr('dy', function (d) { return nodeRadius(d) + 26; })
        .attr('font-size', '9px').attr('fill', '#9aa0ac').attr('pointer-events', 'none')
        .text(subLabelText);

      labelSel = zoomG.select('.nm-labels-layer').selectAll('.nm-label')
        .data(nodes, function (d) { return d.id; }).enter()
        .append('text').attr('class', 'nm-label').attr('pointer-events', 'none')
        .attr('dy', function (d) { return nodeRadius(d) + 14; })
        .attr('text-anchor', 'middle')
        .text(function (d) { return trunc(d.label || d.ip || d.id, 22); });

      let initialFit = false;
      sim.on('end', function () { if (!initialFit) { fitView(); initialFit = true; } });
      sim.start();

      // After start() d3 resolves numeric indices to node refs — re-apply colour/class.
      linkSel.select('.nm-link').attr('class', function (d) { return 'nm-link' + linkClass(d); }).style('stroke', getLinkColor);
      linkSel.select('.nm-link-flow').attr('class', function (d) { return flowClassFor(resolveLinkEnd(d.target)); });
      requestAnimationFrame(updateHighlighting);
    }

    function tickForce() {
      linkSel.selectAll('line')
        .attr('x1', function (d) { return d.source.x; }).attr('y1', function (d) { return d.source.y; })
        .attr('x2', function (d) { return d.target.x; }).attr('y2', function (d) { return d.target.y; });
      nodeSel.attr('transform',  function (d) { return 'translate(' + (d.x || 0) + ',' + (d.y || 0) + ')'; });
      labelSel.attr('transform', function (d) { return 'translate(' + (d.x || 0) + ',' + (d.y || 0) + ')'; });
    }

    // --- SVG export ---

    function exportSVG() {
      const svg = document.getElementById('nm-svg');
      const clone = svg.cloneNode(true);
      clone.querySelectorAll('.nm-link-flow').forEach(function (el) { el.remove(); });
      const style = document.createElement('style');
      style.textContent = [
        '.nm-link { stroke:#b8c8d8; stroke-width:1.5px; fill:none; }',
        '.nm-link.subnet { stroke:#6b9ac4; stroke-dasharray:8 4; }',
        '.nm-node circle.nm-bg { stroke:#fff; stroke-width:2.5px; }',
        '.nm-node.selected circle.nm-bg { stroke:#f6a623; stroke-width:3.5px; }',
        '.nm-label { font:600 10.5px/1.3 "Helvetica Neue",Arial,sans-serif; fill:#2c3e50; }',
        '.nm-link.heavy { stroke:#d94f00 !important; }'
      ].join('\n');
      clone.insertBefore(style, clone.firstChild);
      clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
      const blob = new Blob([new XMLSerializer().serializeToString(clone)], { type: 'image/svg+xml;charset=utf-8' });
      const url  = URL.createObjectURL(blob);
      const a    = document.createElement('a');
      a.href = url;
      a.download = 'network_map_' + new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19) + '.svg';
      document.body.appendChild(a); a.click(); document.body.removeChild(a);
      setTimeout(function () { URL.revokeObjectURL(url); }, 100);
    }

    // --- Fit view ---

    function fitView() {
      if (!zoomG || !zoomBehavior) return;
      const bb = zoomG.node().getBBox();
      if (!bb || !isFinite(bb.width) || !isFinite(bb.height) || !bb.width || !bb.height) return;
      const c   = document.getElementById('nm-canvas');
      const W   = Math.max(c.clientWidth, 800), H = Math.max(c.clientHeight, 600), PAD = 52;
      const sc  = Math.min((W - PAD * 2) / bb.width, (H - PAD * 2) / bb.height, 2);
      const tx  = W / 2 - sc * (bb.x + bb.width  / 2);
      const ty  = H / 2 - sc * (bb.y + bb.height / 2);
      zoomBehavior.translate([tx, ty]).scale(sc);
      zoomBehavior.event(svgRoot.transition().duration(650));
    }

    // --- Visual helpers ---

    function nodeRadius(d) { return (RADIUS[d.type || 'host'] || RADIUS.host) + (d.trafficNorm || 0) * 4; }
    function nodeColor(d)  {
      if (d.type === 'vpn_client') return isStale(d) ? COLOR.stale : COLOR.vpn_client;
      if (d.type !== 'host')       return COLOR[d.type] || '#999';
      return isStale(d) ? COLOR.stale : COLOR.host;
    }
    function nodeIcon(d) {
      if (d.type === 'router')     return '⬡';
      if (d.type === 'subnet')     return '⊞';
      if (d.type === 'vpn')        return '⊕';
      if (d.type === 'vpn_client') return '▸';
      return '';
    }
    function trafficArc(d) {
      if (!d.flow) return '0 9999';
      const total = (d.flow.in || 0) + (d.flow.out || 0);
      if (!total)  return '0 9999';
      const r = nodeRadius(d) + 3.5, circ = 2 * Math.PI * r;
      const frac = Math.min((d.flow.out || 0) / total, 1);
      return (frac * circ).toFixed(1) + ' ' + ((1 - frac) * circ).toFixed(1);
    }
    function isStale(d) {
      if (d.type === 'router' || d.type === 'subnet' || d.type === 'vpn') return false;
      if (!d.last_seen) return true;
      const t = new Date((d.last_seen + '').replace(' ', 'T') + 'Z').getTime();
      return !isFinite(t) || (Date.now() - t) > parseInt(currentTimeWindow, 10) * 1000;
    }

    // --- Detail panel ---

    function selectNode(d) {
      nodeSel.classed('selected', function (n) { return n.id === d.id; });
      selectedId = d.id;
      renderPanel(d);
      $('#nm-panel').addClass('open');
    }

    function closePanel() {
      $('#nm-panel').removeClass('open');
      selectedId = null;
      if (nodeSel) nodeSel.classed('selected', false);
      stopScan();
    }

    function flowSection(f, title, meta) {
      if (!f || (f.in || 0) + (f.out || 0) === 0) return '';
      const inP = Math.round(((f.in || 0) / ((f.in || 0) + (f.out || 0))) * 100);
      return `
        <div class="nm-section"><i class="fa fa-signal"></i> ${title}</div>
        <div class="nm-traf-row">
          <div><div class="nm-traf-lbl">Download</div><div class="nm-traf-val nm-traf-in">↓ ${fmtBytes(f.in || 0)}</div></div>
          <div style="text-align:right"><div class="nm-traf-lbl">Upload</div><div class="nm-traf-val nm-traf-out">↑ ${fmtBytes(f.out || 0)}</div></div>
        </div>
        <div class="nm-bar-bg"><div class="nm-bar-fill" style="width:100%;background:linear-gradient(90deg,#d94f00 ${inP}%,#2980b9 ${inP}%);"></div></div>
        <div class="nm-traf-meta"><span>${f.flows || 0} flow${(f.flows || 0) !== 1 ? 's' : ''}</span><span>${meta}</span></div>`;
    }

    function renderPanel(d) {
      const el = document.getElementById('nm-panel-content');
      if (!el) return;

      if (d.type === 'router') {
        el.innerHTML = ph('⬡', 'OPNsense', 'Firewall / Router', '#3a86ff') +
          itab([['Role', 'Firewall &amp; Router'], ['Vendor', 'Deciso B.V.']]);
        return;
      }

      if (d.type === 'subnet') {
        const wl = $('#nm-time-window option:selected').text();
        el.innerHTML = ph('⊞', escH(d.label), 'Subnet', '#f6a623') +
          itab([['Interface', cd(d.ifname)], ['Network', cd(d.cidr)], ['Interface IP', cd(d.ip)]]) +
          flowSection(d.flow, `NetFlow (Aggregated) · ${escH(wl)}`, 'Total Subnet Traffic');
        return;
      }

      if (d.type === 'vpn') {
        el.innerHTML = ph('⊕', escH(d.label || 'VPN Tunnel'), 'VPN Tunnel · ' + escH(d.proto || 'VPN'), '#8e44ad') +
          itab([['Protocol', escH(d.proto || '—')], ['Tunnel Network', cd(d.cidr || '—')]]);
        return;
      }

      if (d.type === 'vpn_client') {
        el.innerHTML = ph('▸', escH(d.label || d.ip || d.id), 'VPN Client · ' + escH(d.proto || 'VPN'), '#a569bd') +
          itab([['Protocol', escH(d.proto || '—')], ['IP', cd(d.ip || '—')], ['Hostname', escH(d.hostname || '—')]]);
        return;
      }

      /* Host */
      const active = !isStale(d);
      const dot = `<span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:${active ? '#27ae60' : '#adb5bd'};margin-right:5px;vertical-align:middle;"></span>`;
      const wl  = $('#nm-time-window option:selected').text();
      const pct = maxTraffic > 0 ? Math.round(((d.flow ? (d.flow.in || 0) + (d.flow.out || 0) : 0) / maxTraffic) * 100) : 0;

      let html = ph('💻', escH(d.hostname || d.ip || d.id), escH(d.vendor || 'Unknown vendor'), '#27ae60') +
        itab([
          ['Status', dot + (active ? 'Active' : 'Stale')],
          ['IP',     cd(d.ip)],
          ...(d.hostname ? [['Hostname', escH(d.hostname)]] : []),
          ['MAC',        cd(d.mac     || '—')],
          ['Vendor',     escH(d.vendor   || '—')],
          ['Interface',  cd(d.ifname  || '—')],
          ['First seen', escH(d.first_seen || '—')],
          ['Last seen',  escH(d.last_seen  || '—')],
        ]) +
        flowSection(d.flow, `NetFlow · ${escH(wl)}`, pct + '% of top talker');

      if (d.flow && d.flow.alerts && d.flow.alerts.length > 0) {
        html += `<div class="nm-section" style="color:#e74c3c;border-color:rgba(231,76,60,.3);"><i class="fa fa-warning"></i> Security Alerts</div>`;
        d.flow.alerts.forEach(function (a) { html += `<div class="nm-alert-card">${escH(a)}</div>`; });
      }

      if (d.flow && d.flow.peers && d.flow.peers.length > 0) {
        html += `<div class="nm-section"><i class="fa fa-exchange"></i> Top Peers</div>
          <table class="nm-ports" style="margin-top:0;">
            <thead><tr><th>Peer</th><th>Port</th><th>Traffic</th></tr></thead><tbody>`;
        d.flow.peers.forEach(function (p) {
          html += `<tr>
            <td><span style="color:var(--nm-panel-accent);font-family:monospace;font-size:11px;">${escH(p.ip)}</span></td>
            <td style="color:var(--nm-panel-muted);font-size:11px;">${escH(p.port)}</td>
            <td style="text-align:right;font-size:11px;">${fmtBytes(p.bytes)}</td></tr>`;
        });
        html += `</tbody></table>`;
      }

      html += `
        <div class="nm-section" style="margin-top:16px;"><i class="fa fa-search"></i> nmap scan</div>
        <button id="nm-scan-btn" class="nm-scan-btn" ${d.ip ? '' : 'disabled title="No IP to scan"'}><i class="fa fa-search"></i> Scan this host</button>
        <div id="nm-scan-result" style="margin-top:12px;"></div>`;

      el.innerHTML = html;
      const btn = document.getElementById('nm-scan-btn');
      if (btn && d.ip) btn.addEventListener('click', function () { startScan(d.ip); });
    }

    function ph(icon, title, sub, accent) {
      return `<div class="nm-ph">
        <div class="nm-ph-icon" style="background:${accent}20;color:${accent};">${icon}</div>
        <div><div class="nm-ph-title">${title}</div>${sub ? `<div class="nm-ph-sub">${sub}</div>` : ''}</div>
      </div>`;
    }
    function itab(rows) {
      return `<table class="nm-info-table">` +
        rows.map(function (r) { return `<tr><th>${escH(r[0])}</th><td>${r[1]}</td></tr>`; }).join('') +
        `</table>`;
    }
    function cd(v) { return `<code>${escH(v || '—')}</code>`; }

    // --- nmap scan ---

    function startScan(ip) {
      if (!ip) return;
      stopScan();
      const btn = document.getElementById('nm-scan-btn');
      const res = document.getElementById('nm-scan-result');
      if (btn) { btn.disabled = true; btn.innerHTML = '<i class="fa fa-spinner fa-spin"></i> Scanning…'; }
      if (res) res.innerHTML = '';
      if (nodeSel) nodeSel.classed('scanning', function (d) { return d.ip === ip; });
      ajaxCall('/api/netmap/scan/start', { target: ip }, function (resp) {
        if (!resp || resp.error) { showScanError((resp && resp.error) || 'Request failed'); return; }
        if (!resp.job_id)        { showScanError('No job id returned.'); return; }
        currentJob = resp.job_id;
        scanTimer = setInterval(function () { pollScan(currentJob, ip); }, POLL_MS);
      });
    }

    function pollScan(jobId, ip) {
      if (!jobId) { stopScan(); return; }
      ajaxGet('/api/netmap/scan/poll', { job_id: jobId }, function (resp) {
        if (!resp || resp.status === 'running') return;
        stopScan();
        if (nodeSel) nodeSel.classed('scanning', false);
        if      (resp.status === 'done')    showScanResult(resp.data || {}, ip);
        else if (resp.status === 'error')   showScanError(resp.message || 'Scan failed');
        else if (resp.status === 'unknown') showScanError('Job expired or not found.');
        else                                showScanError('Unexpected status: ' + resp.status);
      });
    }

    function stopScan() { if (scanTimer) { clearInterval(scanTimer); scanTimer = null; } currentJob = null; }

    function showScanResult(data, ip) {
      resetScanBtn();
      const osName = data.os && data.os.name || null;
      const osAcc  = data.os && data.os.accuracy || null;
      currentNodes.forEach(function (n) { if (n.ip === ip) { n.osName = osName; n.osAccuracy = osAcc; } });
      if (zoomG) {
        zoomG.selectAll('.nm-node-sub-label').text(subLabelText);
      }
      let html = '';
      if (data.os) {
        html += `<div class="nm-os-badge"><i class="fa fa-desktop"></i> ${escH(data.os.name)} <span style="opacity:.6;font-weight:400;">${escH(String(data.os.accuracy))}%</span></div><br>`;
      }
      if (data.uptime_s) {
        html += `<div style="font-size:11px;color:var(--nm-panel-muted);margin-bottom:8px;"><i class="fa fa-clock-o"></i> Uptime: ~${Math.floor(data.uptime_s / 3600)}h ${Math.floor((data.uptime_s % 3600) / 60)}m</div>`;
      }
      const ports = data.ports || [];
      if (!ports.length) {
        html += `<div style="color:var(--nm-panel-muted);font-size:12px;text-align:center;padding:14px 0;">No open ports in top ${TOP_PORTS}</div>`;
      } else {
        html += `<table class="nm-ports"><thead><tr><th>Port</th><th>Proto</th><th>Service</th><th>Version</th></tr></thead><tbody>`;
        ports.forEach(function (p) {
          html += `<tr>
            <td><span class="nm-port-num">${escH(String(p.port))}</span></td>
            <td style="color:var(--nm-panel-muted);font-size:11px;">${escH(p.protocol)}</td>
            <td><span class="nm-port-svc">${escH(p.service)}</span></td>
            <td><span class="nm-port-ver">${escH([p.product, p.version].filter(Boolean).join(' '))}</span></td></tr>`;
        });
        html += `</tbody></table>`;
      }
      if (data.scanned_at) {
        html += `<div style="font-size:10.5px;color:var(--nm-panel-muted);margin-top:8px;text-align:right;">Scanned ${new Date(data.scanned_at * 1000).toLocaleString()}</div>`;
      }
      const res = document.getElementById('nm-scan-result');
      if (res) res.innerHTML = html;
    }

    function showScanError(msg) {
      resetScanBtn();
      const res = document.getElementById('nm-scan-result');
      if (res) res.innerHTML = `<div class="nm-error-box"><i class="fa fa-exclamation-triangle"></i> ${escH(msg)}</div>`;
      if (nodeSel) nodeSel.classed('scanning', false);
    }

    function resetScanBtn() {
      const btn = document.getElementById('nm-scan-btn');
      if (btn) { btn.disabled = false; btn.innerHTML = '<i class="fa fa-search"></i> Scan this host'; }
    }

    // --- Utilities ---

    function fmtBytes(b) {
      if (!b || b < 0) return '0 B';
      const u = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
      const i = Math.min(Math.floor(Math.log(b) / Math.log(1000)), u.length - 1);
      return (b / Math.pow(1000, i)).toFixed(i > 0 ? 1 : 0) + ' ' + u[i];
    }
    function trunc(s, n) { return s && s.length > n ? s.slice(0, n - 1) + '…' : (s || ''); }
    function escH(s) {
      return String(s == null ? '' : s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }
    function setStatus(msg) { const el = document.getElementById('nm-status'); if (el) el.textContent = msg; }

    // --- Resize ---

    let _rt;
    window.addEventListener('resize', function () {
      clearTimeout(_rt);
      _rt = setTimeout(function () {
        const c = document.getElementById('nm-canvas');
        if (!c || !svgRoot) return;
        const W = Math.max(c.clientWidth, 800), H = Math.max(c.clientHeight, 600);
        svgRoot.attr('viewBox', `0 0 ${W} ${H}`);
        if (currentLayout === 'force' && sim) sim.size([W, H]).resume();
        else if (currentLayout === 'tree') refreshLayout();
      }, 200);
    });

  });
</script>
