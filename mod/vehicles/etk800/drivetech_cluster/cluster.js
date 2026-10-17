// DriveTech F31-style instrument cluster for the ETK 800 (Milendur interior).
//
// Needles and scales share one angle function, so a needle can never disagree
// with its scale. Speed comes straight from electrics.wheelspeed, revs from
// electrics.rpmTacho.
//
// Layers (URL parameter "render"):
//   live     (default) streamed by BeamNG: pre-rendered lit layer + needles/lamps
//   lit      backlit print with glow, pre-rendered to textures/*_lit_<theme>.png
//   base     daylight base colour      metal / rough   PBR maps
//   preview  everything combined for screenshots      demo  preview with a test drive
(function () {
  'use strict'

  var params = new URLSearchParams(window.location.search)
  var MODE = params.get('render') || 'live'
  var DYNAMIC = MODE === 'live' || MODE === 'preview' || MODE === 'demo'
  var STATIC_LOOK = MODE === 'preview' || MODE === 'demo' ? 'base' : MODE // live draws no static parts
  var PRINT_LIT = MODE === 'lit' || MODE === 'preview' || MODE === 'demo'

  // Dial geometry measured from the Milendur gauge face UV layout (1024 x 512 space)
  var SPEEDO = { cx: 331.22, cy: 252.07, rIn: 136.0, rOut: 145.8, min: 0, max: 260, a0: -117, a1: 117 }
  var TACHO = { cx: 689.99, cy: 251.78, rIn: 137.17, rOut: 146.04, min: 0, max: 6, a0: -117, a1: 117, red: 5 }
  var FUEL = { cx: 117.91, cy: 365.75, rIn: 75.9, rOut: 82.09, min: 0, max: 1, a0: -52, a1: 52 }
  var OIL = { cx: 902.46, cy: 365.70, rIn: 75.91, rOut: 82.08, min: 70, max: 150, a0: -52, a1: 52 }
  var SCREEN_TOP = 38 // the Milendur info screen trapezoid starts this far below a big dial's centre

  var THEMES = {
    orange: { print: '#ff5420', halo: '#ff6a2a', label: '#ff6a36' },
    white: { print: '#f3f6fa', halo: '#ffffff', label: '#ffffff' }
  }
  var themeName = THEMES[params.get('theme')] ? params.get('theme') : 'orange'
  var theme = THEMES[themeName]
  var RED = '#ff2414'
  var AMBER = '#ffad0f'
  var GREEN = '#2fdc52'
  var BLUE = '#2f7dff'
  var FONT = "'Bahnschrift SemiCondensed', 'Bahnschrift', 'Arial Narrow', Arial, sans-serif"

  var svgNS = 'http://www.w3.org/2000/svg'
  var root = document.getElementById('cluster')
  root.setAttribute('width', '100%')
  root.setAttribute('height', '100%')
  root.setAttribute('preserveAspectRatio', 'none')

  function el(name, attrs, parent) {
    var e = document.createElementNS(svgNS, name)
    for (var k in attrs) e.setAttribute(k, attrs[k])
    ;(parent || root).appendChild(e)
    return e
  }

  function angleOf(d, value) {
    var v = Math.min(Math.max(value, d.min), d.max)
    return d.a0 + (d.a1 - d.a0) * (v - d.min) / (d.max - d.min)
  }

  function point(d, r, deg) {
    var a = deg * Math.PI / 180
    return [d.cx + r * Math.sin(a), d.cy - r * Math.cos(a)]
  }

  function arcPath(d, r, v0, v1) {
    var a0 = angleOf(d, v0), a1 = angleOf(d, v1)
    var p0 = point(d, r, a0), p1 = point(d, r, a1)
    return 'M' + p0[0] + ' ' + p0[1] + ' A' + r + ' ' + r + ' 0 ' + (Math.abs(a1 - a0) > 180 ? 1 : 0) + ' 1 ' + p1[0] + ' ' + p1[1]
  }

  // ---------------------------------------------------------------------------
  // shared definitions: gradients and glow filters
  var defs = el('defs', {})

  function gradient(id, type, stops, attrs) {
    var g = el(type, Object.assign({ id: id }, attrs || {}), defs)
    stops.forEach(function (s) { el('stop', { offset: s[0], 'stop-color': s[1] }, g) })
  }

  gradient('chrome', 'linearGradient', [[0, '#f7f8fa'], [0.22, '#a7abb1'], [0.45, '#eef0f3'], [0.62, '#7d8187'], [0.82, '#d4d7db'], [1, '#8d9197']], { x1: 0, y1: 0, x2: 1, y2: 1 })
  gradient('face', 'radialGradient', [[0, '#121212'], [0.7, '#080808'], [1, '#020202']], { cx: 0.5, cy: 0.42, r: 0.6 })
  gradient('plate', 'linearGradient', [[0, '#1d1d1d'], [1, '#121212']], { x1: 0, y1: 0, x2: 0, y2: 1 })
  gradient('needleBody', 'linearGradient', [[0, '#a3140a'], [0.38, '#ff3c16'], [0.5, '#ffb08f'], [0.62, '#ff3c16'], [1, '#a3140a']], { x1: 0, y1: 0, x2: 1, y2: 0 })
  gradient('hubCap', 'radialGradient', [[0, '#2a2a2a'], [0.6, '#0b0b0b'], [1, '#000']], { cx: 0.4, cy: 0.35, r: 0.7 })

  function glowFilter(id, blur, strength) {
    var f = el('filter', { id: id, x: '-30%', y: '-30%', width: '160%', height: '160%' }, defs)
    el('feGaussianBlur', { in: 'SourceGraphic', stdDeviation: blur, result: 'b1' }, f)
    el('feGaussianBlur', { in: 'SourceGraphic', stdDeviation: blur * 3, result: 'b2' }, f)
    var t = el('feComponentTransfer', { in: 'b2', result: 'b2s' }, f)
    el('feFuncA', { type: 'linear', slope: strength }, t)
    var m = el('feMerge', {}, f)
    el('feMergeNode', { in: 'b2s' }, m)
    el('feMergeNode', { in: 'b1' }, m)
    el('feMergeNode', { in: 'SourceGraphic' }, m)
  }
  glowFilter('glowPrint', 1.1, 0.9)
  glowFilter('glowNeedle', 1.4, 1.0)
  glowFilter('glowLamp', 1.0, 0.8)

  // ---------------------------------------------------------------------------
  // static parts: plate, faces, chrome rings, other UV islands

  var BIG = [SPEEDO, TACHO]
  var ALL = [SPEEDO, TACHO, FUEL, OIL]

  function screenTrapezoid(d, fill) {
    var id = 'clip' + Math.round(d.cx)
    if (!document.getElementById(id)) {
      var cp = el('clipPath', { id: id }, defs)
      el('circle', { cx: d.cx, cy: d.cy, r: d.rIn }, cp)
    }
    var top = d.cy + SCREEN_TOP, w = 53, slope = 1.5, depth = 200
    el('path', {
      d: 'M' + (d.cx - w) + ' ' + top + ' L' + (d.cx + w) + ' ' + top + ' L' + (d.cx + w + slope * depth) + ' ' + (top + depth) +
        ' L' + (d.cx - w - slope * depth) + ' ' + (top + depth) + ' Z',
      fill: fill, 'clip-path': 'url(#' + id + ')'
    })
  }

  function buildStatic(look) {
    var c = {
      base: { plate: 'url(#plate)', face: 'url(#face)', band: '#0b0b0b', screen: '#0c0c0c', ring: 'url(#chrome)', edge: '#3a3a3a' },
      metal: { plate: '#000', face: '#000', band: '#000', screen: '#000', ring: '#fff', edge: '#000' },
      rough: { plate: '#a0a0a0', face: '#8a8a8a', band: '#7a7a7a', screen: '#6a6a6a', ring: '#383838', edge: '#7a7a7a' }
    }[look]
    if (!c) return

    el('rect', { x: 0, y: 0, width: 1024, height: 512, fill: c.plate })

    // other UV islands sharing this texture (approximated from the Milendur layout)
    if (params.get('clean') !== '1') drawIslands(look, c)
    buildDials(c)
  }

  function drawIslands(look, c) {
    var island = look === 'base' ? '#d3d3d3' : look === 'metal' ? '#6a6a6a' : '#4a4a4a'
    el('path', { d: 'M34 0 L190 0 C182 34 150 64 110 80 C 88 66 60 52 34 46 Z', fill: island })
    el('circle', { cx: 16, cy: 43, r: 6, fill: look === 'base' ? '#8a8a8a' : island })
    el('circle', { cx: 37, cy: 43, r: 6, fill: look === 'base' ? '#8a8a8a' : island })
    el('path', { d: 'M758 0 L1024 0 L1024 110 L930 106 L876 92 L820 52 Z', fill: look === 'base' ? '#000' : c.plate })
    el('path', { d: 'M965 0 L1024 0 L1024 112 C1000 116 975 112 965 92 Z', fill: look === 'base' ? '#545454' : island })
    el('rect', { x: 958, y: 28, width: 6, height: 30, fill: look === 'base' ? '#2f6bff' : c.plate })
  }

  function buildDials(c) {
    ALL.forEach(function (d) {
      el('circle', { cx: d.cx, cy: d.cy, r: d.rIn, fill: c.face })
      // chrome bezel with a fine dark edge on both sides
      el('circle', { cx: d.cx, cy: d.cy, r: (d.rIn + d.rOut) / 2, fill: 'none', stroke: c.ring, 'stroke-width': d.rOut - d.rIn })
      el('circle', { cx: d.cx, cy: d.cy, r: d.rIn + 0.4, fill: 'none', stroke: c.edge, 'stroke-width': 0.8 })
      el('circle', { cx: d.cx, cy: d.cy, r: d.rOut - 0.4, fill: 'none', stroke: c.edge, 'stroke-width': 0.8 })
    })
    BIG.forEach(function (d) {
      // the sloped scale ring (matches the bevel in the Milendur normal map)
      el('path', { d: arcPath(d, 120, d.min, d.max), fill: 'none', stroke: c.band, 'stroke-width': 26 })
      screenTrapezoid(d, c.screen)
    })
  }

  // ---------------------------------------------------------------------------
  // warning lamp symbols (24 x 24 design box, ISO 2575 style)

  function icon(kind, x, y, size, color, extra, parent) {
    var g = el('g', { transform: 'translate(' + (x - size / 2) + ' ' + (y - size / 2) + ') scale(' + (size / 24) + ')' }, parent)
    var fill = { fill: color }
    var line = { fill: 'none', stroke: color, 'stroke-width': 1.8, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }
    function p(d, a) { var o = Object.assign({}, a); o.d = d; return el('path', o, g) }
    function txt(tx, ty, s, sz) {
      var t = el('text', { x: tx, y: ty, fill: color, 'font-family': 'Arial, sans-serif', 'font-size': sz, 'font-weight': 700, 'text-anchor': 'middle', 'dominant-baseline': 'central' }, g)
      t.textContent = s
    }
    switch (kind) {
      case 'blinkL': p('M1.5 12 L10 3.5 V8.6 H22.5 V15.4 H10 V20.5 Z', fill); break
      case 'blinkR': p('M22.5 12 L14 3.5 V8.6 H1.5 V15.4 H14 V20.5 Z', fill); break
      case 'highbeam':
        p('M13 4.5 C19.5 4.5 21.5 8 21.5 12 C21.5 16 19.5 19.5 13 19.5 C11.6 17 11 14.5 11 12 C11 9.5 11.6 7 13 4.5 Z', fill)
        ;[6, 9.75, 13.5, 17.25].forEach(function (yy) { p('M1.5 ' + yy + ' H8.5', line) })
        break
      case 'fog':
        p('M13.5 5 C19.5 5 21.5 8.3 21.5 12 C21.5 15.7 19.5 19 13.5 19 C12.2 16.7 11.6 14.4 11.6 12 C11.6 9.6 12.2 7.3 13.5 5 Z', fill)
        ;[6.5, 10.3, 14.1, 17.9].forEach(function (yy) { p('M2 ' + (yy + 2) + ' L9 ' + yy, line) })
        p('M5.8 2.5 C3.8 5.5 7.6 8.5 5.6 11.5 C3.6 14.5 7.4 17.5 5.4 21.5', { fill: 'none', stroke: color, 'stroke-width': 1.5, 'stroke-linecap': 'round' })
        break
      case 'parkbrake':
        el('circle', { cx: 12, cy: 12, r: 7.6, fill: 'none', stroke: color, 'stroke-width': 1.9 }, g)
        p('M4.2 4.6 A10.6 10.6 0 0 0 4.2 19.4', line); p('M19.8 4.6 A10.6 10.6 0 0 1 19.8 19.4', line)
        txt(12, 12.4, 'P', 10.5)
        break
      case 'abs':
        el('circle', { cx: 12, cy: 12, r: 7.6, fill: 'none', stroke: color, 'stroke-width': 1.9 }, g)
        p('M4.2 4.6 A10.6 10.6 0 0 0 4.2 19.4', line); p('M19.8 4.6 A10.6 10.6 0 0 1 19.8 19.4', line)
        txt(12, 12.3, 'ABS', 6.2)
        break
      case 'dsc':
      case 'dscoff':
      case 'dtc':
        p('M5.5 10.5 L7.6 5.6 C7.9 4.9 8.4 4.5 9.2 4.5 H14.8 C15.6 4.5 16.1 4.9 16.4 5.6 L18.5 10.5 H19.5 C20.3 10.5 20.8 11 20.8 11.8 V14.8 H3.2 V11.8 C3.2 11 3.7 10.5 4.5 10.5 Z', fill)
        p('M4.4 14.8 H7.4 V16.6 H4.4 Z', fill); p('M16.6 14.8 H19.6 V16.6 H16.6 Z', fill)
        if (kind === 'dsc') {
          p('M7.2 18 C5.2 19.2 9.2 20.6 7 22.6', { fill: 'none', stroke: color, 'stroke-width': 1.5, 'stroke-linecap': 'round' })
          p('M16.8 18 C14.8 19.2 18.8 20.6 16.6 22.6', { fill: 'none', stroke: color, 'stroke-width': 1.5, 'stroke-linecap': 'round' })
        } else {
          txt(12, 20.6, kind === 'dtc' ? 'DTC' : 'OFF', 6.4)
        }
        break
      case 'engine':
        p('M3 10 H5 V8 H8 V6.2 H14.5 V8 H17 L19 10 H21.2 V16.4 H19 L17 18.5 H8.4 L6.5 16.4 H3 Z', { fill: 'none', stroke: color, 'stroke-width': 1.9, 'stroke-linejoin': 'round' })
        p('M1.2 11 V15.4', line)
        break
      case 'coolant':
        p('M12 2.8 V13.6', { fill: 'none', stroke: color, 'stroke-width': 2.6, 'stroke-linecap': 'round' })
        el('circle', { cx: 12, cy: 15.2, r: 2.6, fill: color }, g)
        ;[5.2, 7.8, 10.4].forEach(function (yy) { p('M12 ' + yy + ' H15.6', { fill: 'none', stroke: color, 'stroke-width': 1.4 }) })
        p('M3 19.2 C5 17.8 7 20.6 9 19.2 S13 20.6 15 19.2 S19 20.6 21 19.2', line)
        p('M3 22.2 C5 20.8 7 23.6 9 22.2 S13 23.6 15 22.2 S19 23.6 21 22.2', line)
        break
      case 'battery':
        p('M3 7 H21 V19 H3 Z', { fill: 'none', stroke: color, 'stroke-width': 1.9, 'stroke-linejoin': 'round' })
        p('M5.5 4.6 H9 V7 H5.5 Z M15 4.6 H18.5 V7 H15 Z', fill)
        p('M6 13 H10 M8 11 V15 M14 13 H18', line)
        break
      case 'glow':
        p('M3 12 C3 7 6.6 7 6.6 12 S10.2 17 10.2 12 S13.8 7 13.8 12 S17.4 17 17.4 12 S21 7 21 12', line)
        p('M3 16.5 H21', { fill: 'none', stroke: color, 'stroke-width': 1.4, 'stroke-dasharray': '1.6 1.6' })
        break
      case 'autostop':
        p('M19.2 8.4 A8.2 8.2 0 1 0 20.2 13.6', line)
        p('M17.2 4.8 L20.4 8.6 L15.6 9.6 Z', fill)
        txt(12, 12.3, 'A', 9.5)
        break
      case 'flag':
        p('M5 3 V22', { fill: 'none', stroke: color, 'stroke-width': 1.8, 'stroke-linecap': 'round' })
        for (var r = 0; r < 4; r++) for (var c = 0; c < 4; c++) {
          if ((r + c) % 2 === 0) el('rect', { x: 6 + c * 3.6, y: 4 + r * 3, width: 3.6, height: 3, fill: color }, g)
        }
        p('M6 4 H20.4 V16 H6 Z', { fill: 'none', stroke: color, 'stroke-width': 0.8 })
        break
      case 'fuel':
        p('M4 4.5 C4 3.7 4.7 3 5.5 3 H12.5 C13.3 3 14 3.7 14 4.5 V20 H4 Z', { fill: 'none', stroke: color, 'stroke-width': 1.7, 'stroke-linejoin': 'round' })
        p('M6 5.5 H12 V10 H6 Z', fill)
        p('M2.8 20.6 H15.2', line)
        p('M14 8 H16.3 C17.3 8 18 8.7 18 9.7 V16.4 C18 17.3 18.7 18 19.5 18 C20.3 18 21 17.3 21 16.4 V7.6 L18.4 5', line)
        break
      case 'oil':
        p('M3.5 11.5 L7 9.5 H10 V7.6 H8.2 V6.2 H13.8 V7.6 H12 V9.5 H15.2 L20.2 6.8 L21.5 8.2 L16 14.8 H6 C4.6 14.8 3.5 13.7 3.5 12.3 Z', { fill: 'none', stroke: color, 'stroke-width': 1.6, 'stroke-linejoin': 'round' })
        p('M21.5 11.8 C21.5 13.2 22.6 14.4 21.5 15.2 C20.4 14.4 21.5 13.2 21.5 11.8 Z', fill)
        p('M5 18.4 C7 17 9 19.8 11 18.4 S15 19.8 17 18.4', line)
        break
    }
    if (extra) for (var key in extra) g.setAttribute(key, extra[key])
    return g
  }

  // ---------------------------------------------------------------------------
  // print: scales, numerals, labels (lit or unlit)

  function buildPrint(lit) {
    var col = lit ? theme.print : '#2a2a2a'
    var red = lit ? RED : '#2e1512'
    var g = el('g', lit ? { filter: 'url(#glowPrint)' } : {})

    function tick(d, value, r0, r1, width, color) {
      var a = angleOf(d, value), p0 = point(d, r0, a), p1 = point(d, r1, a)
      el('line', { x1: p0[0], y1: p0[1], x2: p1[0], y2: p1[1], stroke: color, 'stroke-width': width }, g)
    }
    function text(x, y, s, size, color, weight) {
      var t = el('text', { x: x, y: y, fill: color, 'font-family': FONT, 'font-size': size, 'font-weight': weight || 500, 'text-anchor': 'middle', 'dominant-baseline': 'central' }, g)
      t.textContent = s
    }
    function numeral(d, value, r, s, size, color) {
      var p = point(d, r, angleOf(d, value))
      text(p[0], p[1], s, size, color)
    }

    // inner light ring along the bezel, like the F3x halo
    if (lit) {
      ALL.forEach(function (d) {
        el('circle', { cx: d.cx, cy: d.cy, r: d.rIn - 1.6, fill: 'none', stroke: theme.halo, 'stroke-width': 1.1, opacity: 0.55 }, g)
      })
    }

    // speedometer: fine ticks every 5, medium every 10, long every 20
    for (var s = 0; s <= 260; s += 5) {
      if (s % 20 === 0) tick(SPEEDO, s, 116, 132, 2.4, col)
      else if (s % 10 === 0) tick(SPEEDO, s, 123, 132, 1.6, col)
      else tick(SPEEDO, s, 127.5, 132, 1.0, col)
    }
    for (var n = 0; n <= 260; n += 20) numeral(SPEEDO, n, n >= 100 && n <= 160 ? 98 : 99, String(n), n >= 100 ? 16.5 : 18, col)
    text(SPEEDO.cx, SPEEDO.cy - 58, 'km/h', 11.5, col, 400)

    // tachometer: 0..6 x1000, red from 5
    el('path', { d: arcPath(TACHO, 133.2, TACHO.red, TACHO.max), fill: 'none', stroke: red, 'stroke-width': 3.6 }, g)
    for (var t = 0; t <= 6.0001; t += 0.25) {
      var c = t >= TACHO.red - 1e-6 ? red : col
      var whole = Math.abs(t - Math.round(t)) < 1e-6
      var half = Math.abs(t * 2 - Math.round(t * 2)) < 1e-6
      if (whole) tick(TACHO, t, 114, 131, 2.6, c)
      else if (half) tick(TACHO, t, 121.5, 131, 1.7, c)
      else tick(TACHO, t, 126.5, 131, 1.0, c)
    }
    for (var k = 0; k <= 6; k++) numeral(TACHO, k, 96, String(k), 24, k >= TACHO.red ? red : col)
    text(TACHO.cx, TACHO.cy - 60, '1/min ×1000', 11, col, 400)

    // fuel
    ;[0, 0.25, 0.5, 0.75, 1].forEach(function (v) {
      var major = v === 0 || v === 0.5 || v === 1
      tick(FUEL, v, major ? 59 : 64, 71, major ? 2.6 : 1.6, v === 0 ? red : col)
    })
    numeral(FUEL, 0, 48, '0', 14, col)
    numeral(FUEL, 0.5, 48, '½', 14, col)
    numeral(FUEL, 1, 48, '1', 14, col)

    // oil temperature
    ;[70, 90, 110, 130, 150].forEach(function (v) {
      var major = v === 70 || v === 110 || v === 150
      tick(OIL, v, major ? 59 : 64, 71, major ? 2.6 : 1.6, v >= 130 ? red : col)
    })
    el('path', { d: arcPath(OIL, 68.5, 130, 150), fill: 'none', stroke: red, 'stroke-width': 2.6 }, g)
    numeral(OIL, 70, 48, '70', 13, col)
    numeral(OIL, 150, 48, '150', 13, col)
    text(OIL.cx + 30, OIL.cy - 6, '°C', 11, col, 400)

    // printed symbols in the small dials
    icon('fuel', FUEL.cx, FUEL.cy + 34, 24, col, null, g)
    icon('oil', OIL.cx, OIL.cy + 34, 26, col, null, g)
  }

  // ---------------------------------------------------------------------------
  // build the requested layer

  if (STATIC_LOOK) buildStatic(STATIC_LOOK)
  if (MODE === 'base') buildPrint(false)
  if (PRINT_LIT) buildPrint(true)

  var litImage = null
  if (MODE === 'live') {
    // the static lit print is pre-rendered (glow included) and only swapped per theme
    litImage = el('image', { x: 0, y: 0, width: 1024, height: 512, preserveAspectRatio: 'none' })
    litImage.setAttribute('href', 'textures/drivetech_f31_lit_' + themeName + '.png')
  }

  // ---------------------------------------------------------------------------
  // dynamic layer: warm-up segments, lamps, needles, mode text

  var lamps = {}
  var needles = {}
  var warmSegments = []
  var modeText = null
  var dyn = null

  function lamp(name, kind, x, y, color, size) {
    lamps[name] = icon(kind, x, y, size, color, { opacity: 0, filter: 'url(#glowLamp)' }, dyn)
  }

  function needle(name, d, length, tail, w) {
    var g = el('g', {}, dyn)
    var body = el('g', { filter: 'url(#glowNeedle)' }, g)
    el('path', {
      d: 'M' + (d.cx - w * 0.32) + ' ' + (d.cy + tail) + ' L' + (d.cx - w / 2) + ' ' + d.cy + ' L' + (d.cx - w * 0.14) + ' ' + (d.cy - length) +
        ' L' + (d.cx + w * 0.14) + ' ' + (d.cy - length) + ' L' + (d.cx + w / 2) + ' ' + d.cy + ' L' + (d.cx + w * 0.32) + ' ' + (d.cy + tail) + ' Z',
      fill: 'url(#needleBody)'
    }, body)
    // hub cap: black plastic, does not glow
    el('circle', { cx: d.cx, cy: d.cy, r: w * 2.1, fill: 'url(#hubCap)' }, g)
    el('circle', { cx: d.cx, cy: d.cy, r: w * 2.1 - 0.4, fill: 'none', stroke: '#1e1e1e', 'stroke-width': 0.8 }, g)
    needles[name] = { g: g, d: d, last: null }
  }

  if (DYNAMIC) {
    dyn = el('g', {})

    // BMW warm-up segments before the red zone: lit while the oil is cold
    for (var i = 0; i < 6; i++) {
      var v0 = 3.5 + i * 0.25 + 0.02, v1 = 3.5 + (i + 1) * 0.25 - 0.02
      warmSegments.push(el('path', { d: arcPath(TACHO, 133.2, v0, v1), fill: 'none', stroke: AMBER, 'stroke-width': 3.6, opacity: 0, filter: 'url(#glowLamp)' }, dyn))
    }

    // lamp rows sit right of the needle's rest position (0 lies at -117 deg, bottom left)
    var ROW = [-18, 3, 24, 45, 65]
    var sy = SPEEDO.cy + 27
    lamp('blinkL', 'blinkL', SPEEDO.cx + ROW[0], sy, GREEN, 18)
    lamp('highbeam', 'highbeam', SPEEDO.cx + ROW[1], sy, BLUE, 18)
    lamp('fog', 'fog', SPEEDO.cx + ROW[2], sy, GREEN, 18)
    lamp('parkbrake', 'parkbrake', SPEEDO.cx + ROW[3], sy, RED, 18)
    lamp('battery', 'battery', SPEEDO.cx + ROW[4], sy, RED, 18)
    lamp('glow', 'glow', SPEEDO.cx - 30, SPEEDO.cy - 32, AMBER, 20)
    lamp('autostop', 'autostop', SPEEDO.cx, SPEEDO.cy - 32, GREEN, 20)
    lamp('launch', 'flag', SPEEDO.cx + 30, SPEEDO.cy - 32, '#ffffff', 20)
    var ty = TACHO.cy + 27
    lamp('abs', 'abs', TACHO.cx + ROW[0], ty, AMBER, 18)
    lamp('dsc', 'dsc', TACHO.cx + ROW[1], ty, AMBER, 18)
    lamp('dscoff', 'dscoff', TACHO.cx + ROW[2], ty, AMBER, 18)
    lamp('dtc', 'dtc', TACHO.cx + ROW[2], ty, AMBER, 18)
    lamp('engine', 'engine', TACHO.cx + ROW[3], ty, AMBER, 18)
    lamp('blinkR', 'blinkR', TACHO.cx + ROW[4], ty, GREEN, 18)
    lamp('lowfuel', 'fuel', FUEL.cx, FUEL.cy + 34, AMBER, 24)
    lamp('coolant', 'coolant', OIL.cx - 30, OIL.cy + 33, RED, 20)
    lamp('oilhot', 'oil', OIL.cx, OIL.cy + 34, RED, 26)

    modeText = el('text', { x: TACHO.cx, y: TACHO.cy - 36, fill: theme.label, 'font-family': FONT, 'font-size': 13, 'font-weight': 600, 'text-anchor': 'middle', 'dominant-baseline': 'central', filter: 'url(#glowLamp)' }, dyn)

    needle('speed', SPEEDO, 128, 18, 6.5)
    needle('rpm', TACHO, 128, 18, 6.5)
    needle('fuel', FUEL, 66, 10, 4.6)
    needle('oil', OIL, 66, 10, 4.6)
  }

  // ---------------------------------------------------------------------------
  // update loop

  var state = { lampTestUntil: 0, glowUntil: 0, lastIgnition: -1, brightness: -1 }

  function num(v) { return v === true ? 1 : v === false || v === undefined || v === null ? 0 : Number(v) }

  function setOpacity(node, on) {
    var v = on ? 1 : 0
    if (node._v !== v) { node._v = v; node.setAttribute('opacity', v) }
  }

  function setNeedle(name, value) {
    var n = needles[name]
    var a = angleOf(n.d, value)
    if (n.last === null || Math.abs(n.last - a) > 0.02) {
      n.last = a
      n.g.setAttribute('transform', 'rotate(' + a.toFixed(3) + ' ' + n.d.cx + ' ' + n.d.cy + ')')
    }
  }

  function setBrightness(b) {
    if (Math.abs(b - state.brightness) < 0.01) return
    state.brightness = b
    if (litImage) litImage.setAttribute('opacity', b)
    for (var k in needles) needles[k].g.setAttribute('opacity', Math.max(b, 0.25))
  }

  var MODE_NAMES = ['ECO PRO', 'COMFORT', 'SPORT', 'SPORT+']
  var MODE_COLORS = [BLUE, null, null, RED]

  function update(e, now) {
    var ignition = num(e.ignitionLevel)
    if (ignition >= 2 && state.lastIgnition >= 0 && state.lastIgnition < 2) {
      state.lampTestUntil = now + 2200
      state.glowUntil = now + 1800
    }
    state.lastIgnition = ignition

    var on = ignition >= 1
    setBrightness(on ? 1 : 0)

    setNeedle('speed', num(e.wheelspeed) * 3.6)
    setNeedle('rpm', num(e.rpmTacho) / 1000)
    setNeedle('fuel', num(e.fuel))
    setNeedle('oil', num(e.oiltemp))

    var test = on && now < state.lampTestUntil
    var running = num(e.rpmTacho) > 300
    var stability = num(e.driveTechStability)
    var autoStopped = num(e.driveTechAutoStop) > 0

    setOpacity(lamps.blinkL, on && num(e.signal_L) > 0.5)
    setOpacity(lamps.blinkR, on && num(e.signal_R) > 0.5)
    setOpacity(lamps.highbeam, test || (on && num(e.highbeam) > 0))
    setOpacity(lamps.fog, test || (on && num(e.fog) > 0))
    setOpacity(lamps.parkbrake, test || (on && num(e.parkingbrake) > 0.1))
    setOpacity(lamps.battery, test || (ignition >= 2 && !running && !autoStopped))
    setOpacity(lamps.glow, test || (ignition >= 2 && !running && !autoStopped && now < state.glowUntil))
    setOpacity(lamps.autostop, on && autoStopped)
    setOpacity(lamps.launch, on && num(e.driveTechLaunchArmed) > 0)
    // the ABS lamp only lights for the bulb check (or a fault), not while ABS regulates
    setOpacity(lamps.abs, test)
    // DSC flashes while traction or stability control intervene
    setOpacity(lamps.dsc, test || (on && (num(e.esc) > 0.5 || num(e.tcs) > 0.5)))
    setOpacity(lamps.dscoff, test || (on && stability === 2))
    setOpacity(lamps.dtc, !test && on && stability === 1)
    setOpacity(lamps.engine, test || (on && num(e.checkengine) > 0))
    setOpacity(lamps.lowfuel, test || (on && num(e.lowfuel) > 0))
    setOpacity(lamps.coolant, test || (on && num(e.watertemp) >= 118))
    setOpacity(lamps.oilhot, test || (on && num(e.oiltemp) >= 130))

    // warm-up segments: all six below 40 degC oil, none from 85 degC
    var oil = num(e.oiltemp)
    var cold = on && running ? Math.round(Math.min(Math.max((85 - oil) / 45, 0), 1) * 6) : 0
    for (var i = 0; i < warmSegments.length; i++) setOpacity(warmSegments[i], test || i >= 6 - cold)

    var profile = num(e.driveTechProfile)
    var text = on && e.driveTechProfile !== undefined ? MODE_NAMES[profile] || '' : ''
    if (modeText._t !== text) {
      modeText._t = text
      modeText.textContent = text
      modeText.setAttribute('fill', MODE_COLORS[profile] || theme.label)
    }
  }

  // BeamNG genericGauges entry points -------------------------------------------
  window.setup = function (config) {
    if (config && THEMES[config.theme]) {
      themeName = config.theme
      theme = THEMES[themeName]
      if (litImage) litImage.setAttribute('href', 'textures/drivetech_f31_lit_' + themeName + '.png')
      if (modeText) modeText.setAttribute('fill', theme.label)
    }
  }

  window.updateData = function (data) {
    if (!DYNAMIC || !data || !data.electrics) return
    update(data.electrics, performance.now())
  }

  // previews ---------------------------------------------------------------------
  var q = function (k, d) { var v = params.get(k); return v === null ? d : Number(v) }
  if (MODE === 'demo') {
    var t0 = performance.now()
    ;(function frame() {
      var t = (performance.now() - t0) / 1000
      var cyc = t % 24
      var speed = cyc < 9 ? Math.min(250, cyc * cyc * 3.4) : cyc < 15 ? 250 - (cyc - 9) * 30 : Math.max(0, 70 - (cyc - 15) * 9)
      var rpm = cyc > 20 ? 800 : 1300 + ((speed % 45) / 45) * 3500
      update({
        ignitionLevel: 2, wheelspeed: speed / 3.6, rpmTacho: rpm, fuel: 0.62, oiltemp: 40 + Math.min(t * 3, 64), watertemp: 92,
        signal_L: (cyc > 16 && cyc < 20 && Math.floor(t * 2.6) % 2 === 0) ? 1 : 0, highbeam: cyc > 6 && cyc < 9 ? 1 : 0,
        parkingbrake: cyc > 21 ? 1 : 0, esc: cyc > 2 && cyc < 3.2 && Math.floor(t * 8) % 2 === 0 ? 1 : 0,
        driveTechProfile: Math.floor(t / 6) % 4, driveTechStability: cyc > 10 && cyc < 14 ? 1 : 0, driveTechAutoStop: cyc > 22.5 ? 1 : 0
      }, performance.now())
      requestAnimationFrame(frame)
    })()
  } else if (MODE === 'preview') {
    var data = {
      ignitionLevel: 2, wheelspeed: q('kmh', 128) / 3.6, rpmTacho: q('rpm', 2350), fuel: q('fuel', 0.62), oiltemp: q('oil', 104), watertemp: 90,
      signal_L: q('blinkL', 1), signal_R: q('blinkR', 0), highbeam: q('highbeam', 1), fog: q('fog', 0), parkingbrake: q('pbrake', 0),
      lowfuel: q('lowfuel', 0), esc: q('esc', 0), driveTechProfile: q('profile', 2), driveTechStability: q('stability', 1), driveTechLaunchArmed: q('launch', 0)
    }
    if (q('lamptest', 0)) update({ ignitionLevel: 1 }, 0) // ignition step 1 -> 2 triggers the bulb check
    update(data, 1)
  } else if (MODE === 'live') {
    update({ ignitionLevel: 0 }, performance.now())
  }
})()
