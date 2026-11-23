// The WebGL graph pane. Swift owns the data and navigation; this file only draws a scene
// and reports clicks, so a native renderer can replace it behind the same messages.
import Graph from "graphology";
import forceAtlas2 from "graphology-layout-forceatlas2";
import Sigma from "sigma";
import { layerDashed, layerPlain, pathLine, sdfCircle } from "sigma/rendering";
import { animateNodes } from "sigma/utils";

// Matches `Palette` in App/Views/Theme.swift. The page is transparent over the native canvas.
const theme = {
  surface: "#0d171b",
  label: "#e6eef0",
  series: ["#5ed6b2", "#8f7dff", "#ff6b4a"],
  other: "#5f6b72",
  hub: "#f1cf86",
  ghost: "#22343a",
  dust: "#3a4a50",
  edge: "#2b4a4e",
  treeEdge: "#1c3438",
  dimNode: "#16282c",
  dimEdge: "#0e1c1f",
  activeEdge: "#f1cf86",
  // A selected ring-one item can own hundreds of tree lines, so they stay quieter than real links.
  activeTreeEdge: "rgba(241,207,134,0.26)",
  suspect: "#ff5fd2",
  // Most links between projects are suspect, so at rest they're only a hint.
  restingSuspect: "#6d3a68",
  dimSuspect: "#2c1a30",
};

const post = (message) => window.webkit?.messageHandlers?.studio?.postMessage(message);

window.addEventListener("error", (event) => post({ type: "error", message: String(event.message) }));

const graph = new Graph({ multi: false, type: "undirected" });
const container = document.getElementById("canvas");
const areaLayer = document.getElementById("areas");
const underCanvas = document.getElementById("under");
const overCanvas = document.getElementById("over");
const under = underCanvas.getContext("2d");
const over = overCanvas.getContext("2d");
const GOLDEN_ANGLE = 2.399963229728653;

let hovered = null;
let selected = null;
let isolatedGroup = null;
let slotByGroup = new Map();
let labelByGroup = new Map();
let layout = "links";
let seedPositions = {};
let forceCache = null;
let stopAnimation = null;
let areaClusters = [];
let insets = { left: 0, right: 0, top: 0, bottom: 0 };
let allowsMotion = true;
let fittedRatio = 1;
// In review mode the scene is one finding, and clicks don't move the selection off it.
let isReviewing = false;
let spotlightIds = null;

// A sphere lit from the top left. Tiny nodes stay flat, because shading only muddies a few pixels.
function layerOrb() {
  return {
    name: "orb",
    uniforms: [],
    attributes: [{ name: "orbColor", size: 4, type: WebGL2RenderingContext.UNSIGNED_BYTE, normalized: true, source: "color" }],
    glsl: `
vec4 layer_orb(vec4 v_orbColor) {
  float radiusInPixels = context.shapeSize / max(context.pixelToUV, 0.0001);
  float shading = smoothstep(2.5, 7.0, radiusInPixels);
  vec2 p = context.uv / context.shapeSize;
  float z = sqrt(clamp(1.0 - dot(p, p), 0.0, 1.0));
  vec3 normal = vec3(p, z);
  vec3 light = normalize(vec3(-0.42, 0.55, 0.72));
  float diffuse = max(dot(normal, light), 0.0);
  float specular = pow(max(dot(reflect(-light, normal), vec3(0.0, 0.0, 1.0)), 0.0), 32.0);
  float rim = pow(1.0 - z, 2.5);
  vec3 lit = v_orbColor.rgb * (0.34 + 0.86 * diffuse);
  lit += mix(v_orbColor.rgb, vec3(1.0), 0.5) * rim * 0.32;
  lit += vec3(1.0) * specular * 0.8;
  return vec4(mix(v_orbColor.rgb, lit, shading), v_orbColor.a);
}
`,
  };
}

function colourFor(node) {
  if (node.ring === 0) return theme.hub;
  if (node.ghost) return theme.ghost;
  if (isDust(node)) return theme.dust;
  const slot = slotByGroup.get(node.group);
  return slot === undefined || slot < 0 ? theme.other : theme.series[slot];
}

// Something that is entirely generated code is drawn as dust, not as a real item.
// Areas pack items into tight clusters, where full-size orbs would overlap.
const shownSize = (size) => (layout === "areas" ? Math.min(size, 11) : size);

const isDust = (node) => (node.noise ?? 0) >= node.value && node.value > 0;

function edgeBaseColour(edge) {
  return edge.tree ? theme.treeEdge : theme.edge;
}

const renderer = new Sigma(graph, container, {
  settings: {
    allowInvalidContainer: true,
    itemSizesReference: "screen",
    // Sizes are pixels when the graph is fitted, and grow gently as you zoom in from there.
    zoomToSizeRatioFunction: (ratio) => Math.sqrt(ratio / fittedRatio),
    stagePadding: 50,
    renderEdgeLabels: false,
    labelDensity: 0.6,
    labelGridCellSize: 110,
    labelRenderedSizeThreshold: 7,
  },
  customNodeState: { isActive: false },
  customEdgeState: { isActive: false },
  customGraphState: { hasFocus: false, isReviewing: false },
  primitives: {
    nodes: {
      shapes: [sdfCircle()],
      layers: [layerOrb()],
      label: { font: { family: "-apple-system, BlinkMacSystemFont, sans-serif", weight: "500", size: 12 } },
    },
    edges: {
      paths: [pathLine()],
      variables: {
        plainColor: { type: "color", default: "transparent" },
        dashColor: { type: "color", default: "transparent" },
        dashLength: { type: "number", default: 0 },
        gapLength: { type: "number", default: 0 },
      },
      // Every edge runs both layers. A plain edge has a zero gap, which turns the dashes off.
      layers: [
        layerPlain({ color: { attribute: "plainColor" } }),
        layerDashed({
          dashColor: { attribute: "dashColor" },
          dashSize: { attribute: "dashLength", default: 0, mode: "pixels" },
          gapSize: { attribute: "gapLength", default: 0, mode: "pixels" },
        }),
      ],
    },
  },
  styles: {
    nodes: [
      {
        x: { attribute: "x" },
        y: { attribute: "y" },
        size: (attributes) => shownSize(attributes.size),
        color: { attribute: "color" },
        label: { attribute: "label" },
        labelColor: theme.label,
        labelSize: 12,
        labelFont: "-apple-system, BlinkMacSystemFont, sans-serif",
        labelVisibility: "auto",
        depth: "nodes",
        zIndex: { attribute: "rank", defaultValue: 0 },
      },
      { whenData: "isDust", then: { labelVisibility: "hidden", opacity: 0.7 } },
      {
        when: (_attributes, state, graphState) => graphState.hasFocus && !state.isActive,
        then: { color: theme.dimNode, labelVisibility: "hidden" },
      },
      { whenState: "isActive", then: { depth: "topNodes" } },
      {
        // The lens has its own name chip, so the label would only collide with the ring.
        whenState: "isHighlighted",
        then: { labelVisibility: "hidden", depth: "topNodes" },
      },
      {
        whenState: "isHovered",
        then: {
          label: { attribute: "hoverText" },
          labelVisibility: "visible",
          labelBackgroundColor: theme.surface,
          labelBackgroundPadding: 5,
          depth: "topNodes",
        },
      },
    ],
    edges: [
      {
        size: { attribute: "size" },
        color: { attribute: "baseColor" },
        plainColor: { attribute: "baseColor" },
        dashColor: "transparent",
        dashLength: 0,
        gapLength: 0,
        depth: "edges",
      },
      { whenData: "isSuspect", then: { plainColor: "transparent", dashColor: theme.restingSuspect, dashLength: 3, gapLength: 5 } },
      {
        when: (attributes, state, graphState) => graphState.hasFocus && !state.isActive && !attributes.isSuspect,
        then: { plainColor: theme.dimEdge },
      },
      {
        when: (attributes, state, graphState) => graphState.hasFocus && !state.isActive && attributes.isSuspect,
        then: { dashColor: theme.dimSuspect },
      },
      {
        when: (attributes, state) => state.isActive && !attributes.isSuspect,
        then: {
          plainColor: { whenData: "tree", then: theme.activeTreeEdge, else: theme.activeEdge },
          depth: "topEdges",
        },
      },
      {
        when: (attributes, state) => state.isActive && attributes.isSuspect,
        then: { dashColor: theme.suspect, depth: "topEdges" },
      },
      // A review scene is one finding, so its suspect links are the point and stay bright.
      {
        when: (attributes, _state, graphState) => graphState.isReviewing && attributes.isSuspect && !graphState.hasFocus,
        then: { dashColor: theme.suspect },
      },
    ],
  },
});

// MARK: Screen scale. Sigma reads the pixel ratio on every resize, but only resizes its canvas when
// the page's size changes. A change of ratio on its own, such as the window moving to a screen with
// another scale or the web view starting before it's on a Retina screen, then draws every node,
// line and label twice as big from the bottom-left corner, with the glows left where the nodes belong.

const stageCanvas = container.querySelector("canvas");

renderer.on("beforeRender", () => {
  const { width, height } = renderer.getDimensions();
  const ratio = window.devicePixelRatio || 1;
  // A canvas is whole pixels: sigma's fractional sizes are cut down.
  if (stageCanvas && (stageCanvas.width !== Math.floor(width * ratio) || stageCanvas.height !== Math.floor(height * ratio))) {
    renderer.resize(true);
  }
});

// Nothing else redraws when only the scale changes.
function watchPixelRatio() {
  matchMedia(`(resolution: ${window.devicePixelRatio || 1}dppx)`).addEventListener("change", () => {
    renderer.scheduleRender();
    watchPixelRatio();
  }, { once: true });
}
watchPixelRatio();

// MARK: Focus. Hover wins over selection, and selection wins over an isolated legend group.

let activeNodes = new Set();
let activeEdges = new Set();
let flowEdges = [];

function applyEmphasis() {
  // Review keeps the whole finding lit, and only hovering narrows it.
  const focus = isReviewing ? hovered : hovered ?? selected;
  const flowSource = hovered ?? selected;
  const nodes = new Set();
  const edges = new Set();
  if (focus !== null && graph.hasNode(focus)) {
    nodes.add(focus);
    graph.forEachNeighbor(focus, (neighbour) => nodes.add(neighbour));
    graph.forEachEdge(focus, (edge) => edges.add(edge));
  } else if (spotlightIds !== null) {
    for (const id of spotlightIds) if (graph.hasNode(id)) nodes.add(id);
  } else if (isolatedGroup !== null) {
    graph.forEachNode((id, attributes) => {
      if (attributes.group === isolatedGroup) nodes.add(id);
    });
    graph.forEachEdge((edge, _attributes, _source, _target, source, target) => {
      if (source.group === isolatedGroup && target.group === isolatedGroup) edges.add(edge);
    });
  }
  for (const id of activeNodes) if (!nodes.has(id)) renderer.setNodeState(id, { isActive: false });
  for (const id of nodes) if (!activeNodes.has(id)) renderer.setNodeState(id, { isActive: true });
  for (const id of activeEdges) if (!edges.has(id)) renderer.setEdgeState(id, { isActive: false });
  for (const id of edges) if (!activeEdges.has(id)) renderer.setEdgeState(id, { isActive: true });
  activeNodes = nodes;
  activeEdges = edges;
  renderer.setGraphState({ hasFocus: nodes.size > 0 });

  // Moving dots only ever run along the suspect links of the thing in focus.
  flowEdges = flowSource === null || !graph.hasNode(flowSource)
    ? []
    : graph.edges(flowSource).filter((edge) => graph.getEdgeAttribute(edge, "isSuspect")).slice(0, 40);
  drawOverlays();
  startOverlayLoop();
}

function setSelected(id) {
  if (selected !== null && graph.hasNode(selected)) renderer.setNodeState(selected, { isHighlighted: false });
  selected = id;
  if (selected !== null) renderer.setNodeState(selected, { isHighlighted: true });
  lensStarted = performance.now();
  applyEmphasis();
}

function applySurface() {
  document.body.style.setProperty("--label", theme.label);
}

renderer.on("enterNode", ({ node }) => {
  hovered = node;
  applyEmphasis();
});

renderer.on("leaveNode", () => {
  hovered = null;
  applyEmphasis();
});

renderer.on("clickNode", ({ node }) => {
  if (isReviewing) return;
  setSelected(node);
  post({ type: "select", id: node });
});

renderer.on("doubleClickNode", ({ node, preventSigmaDefault }) => {
  preventSigmaDefault();
  if (isReviewing) return;
  post({ type: "drill", id: node });
});

renderer.on("clickStage", () => {
  if (isReviewing) return;
  setSelected(null);
  post({ type: "clear" });
});

// MARK: Overlays. Dust and glows sit under the graph, the lens and moving dots over it.

const LENS_DURATION = 260;
const GLOW_LIMIT = 80;
let lensStarted = 0;
let glowNodes = [];
let dustClouds = [];
let overlayLoop = null;
const glowSprites = new Map();

function glowSprite(colour) {
  if (glowSprites.has(colour)) return glowSprites.get(colour);
  const size = 128;
  const sprite = document.createElement("canvas");
  sprite.width = size;
  sprite.height = size;
  const context = sprite.getContext("2d");
  const gradient = context.createRadialGradient(size / 2, size / 2, size * 0.14, size / 2, size / 2, size / 2);
  gradient.addColorStop(0, `${colour}66`);
  gradient.addColorStop(0.45, `${colour}1c`);
  gradient.addColorStop(1, `${colour}00`);
  context.fillStyle = gradient;
  context.fillRect(0, 0, size, size);
  glowSprites.set(colour, sprite);
  return sprite;
}

// The same pseudo-random numbers every time, so a node's dust doesn't change between redraws.
function seededRandom(seed) {
  let state = seed | 0;
  return () => {
    state = (state + 0x6d2b79f5) | 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function hashString(text) {
  let hash = 2166136261;
  for (let index = 0; index < text.length; index++) hash = Math.imul(hash ^ text.charCodeAt(index), 16777619);
  return hash;
}

function buildOverlayData(nodes) {
  glowNodes = nodes
    .filter((node) => !node.ghost && !isDust(node))
    .sort((a, b) => b.value - a.value)
    .slice(0, GLOW_LIMIT)
    .map((node) => node.id);

  const noisy = nodes.filter((node) => (node.noise ?? 0) > 0 && !isDust(node));
  const totalNoise = noisy.reduce((sum, node) => sum + node.noise, 0);
  const noisePerSpeck = Math.max(1, totalNoise / 1600);
  dustClouds = noisy.map((node) => {
    const random = seededRandom(hashString(node.id));
    const count = Math.min(900, Math.max(6, Math.round(node.noise / noisePerSpeck)));
    const specks = [];
    for (let index = 0; index < count; index++) {
      const angle = random() * Math.PI * 2;
      const gaussian = Math.abs(Math.sqrt(-2 * Math.log(random() + 1e-9)) * Math.cos(Math.PI * 2 * random()));
      const distance = 1.5 + gaussian * 2.1;
      specks.push({ x: Math.cos(angle) * distance, y: Math.sin(angle) * distance, size: 0.5 + random() * 1.1, bucket: Math.floor(random() * 3) });
    }
    return { id: node.id, specks };
  });
}

function sizeOverlays() {
  const ratio = window.devicePixelRatio || 1;
  const { width, height } = renderer.getDimensions();
  for (const [canvas, context] of [[underCanvas, under], [overCanvas, over]]) {
    if (canvas.width !== Math.round(width * ratio) || canvas.height !== Math.round(height * ratio)) {
      canvas.width = Math.round(width * ratio);
      canvas.height = Math.round(height * ratio);
    }
    context.setTransform(ratio, 0, 0, ratio, 0, 0);
  }
}

function screenPosition(id) {
  const { x, y } = graph.getNodeAttributes(id);
  return renderer.graphToViewport({ x, y });
}

const screenRadius = (id) => renderer.scaleSize(shownSize(graph.getNodeAttribute(id, "size")));

const DUST_FILLS = [
  "rgba(160,182,188,0.16)",
  "rgba(160,182,188,0.3)",
  "rgba(160,182,188,0.46)",
];
const WARM_DUST_FILLS = [
  "rgba(226,206,160,0.2)",
  "rgba(226,206,160,0.36)",
  "rgba(226,206,160,0.55)",
];

function drawUnder() {
  const { width, height } = renderer.getDimensions();
  under.clearRect(0, 0, width, height);
  const hasFocus = activeNodes.size > 0;

  for (const id of glowNodes) {
    if (!graph.hasNode(id) || (hasFocus && !activeNodes.has(id))) continue;
    const radius = screenRadius(id);
    if (radius < 5) continue;
    const { x, y } = screenPosition(id);
    const reach = radius * 3.1;
    if (x < -reach || y < -reach || x > width + reach || y > height + reach) continue;
    under.drawImage(glowSprite(graph.getNodeAttribute(id, "color")), x - reach, y - reach, reach * 2, reach * 2);
  }

  for (const cloud of dustClouds) {
    if (!graph.hasNode(cloud.id)) continue;
    const isFocused = cloud.id === selected;
    if (hasFocus && !activeNodes.has(cloud.id)) continue;
    const { x, y } = screenPosition(cloud.id);
    const radius = Math.max(screenRadius(cloud.id), 4);
    const fills = isFocused ? WARM_DUST_FILLS : DUST_FILLS;
    for (let bucket = 0; bucket < 3; bucket++) {
      under.fillStyle = fills[bucket];
      for (const speck of cloud.specks) {
        if (speck.bucket !== bucket) continue;
        const px = x + speck.x * radius;
        const py = y + speck.y * radius;
        if (px < 0 || py < 0 || px > width || py > height) continue;
        under.fillRect(px, py, speck.size, speck.size);
      }
    }
  }
}

function lensProgress(now) {
  if (!allowsMotion) return 1;
  const t = Math.min(1, (now - lensStarted) / LENS_DURATION);
  return 1 - (1 - t) ** 3;
}

function drawLens(now) {
  if (selected === null || !graph.hasNode(selected)) return;
  const { x, y } = screenPosition(selected);
  const radius = Math.max(screenRadius(selected), 5);
  const progress = lensProgress(now);
  const value = graph.getNodeAttribute(selected, "value");
  const noise = graph.getNodeAttribute(selected, "noise") ?? 0;
  const share = value > 0 ? Math.min(noise / value, 1) : 0;

  const ring = (radius + 12) * (0.86 + 0.14 * progress);
  const gauge = ring + 15;
  const bracket = gauge + 11;
  over.save();
  over.globalAlpha = progress;
  over.translate(x, y);

  over.strokeStyle = "rgba(241,207,134,0.6)";
  over.lineWidth = 1;
  over.beginPath();
  over.arc(0, 0, ring, 0, Math.PI * 2);
  over.stroke();

  for (let index = 0; index < 72; index++) {
    const angle = (index / 72) * Math.PI * 2;
    const major = index % 6 === 0;
    over.strokeStyle = major ? "rgba(241,207,134,0.5)" : "rgba(241,207,134,0.22)";
    over.beginPath();
    over.moveTo(Math.cos(angle) * (ring + 3), Math.sin(angle) * (ring + 3));
    over.lineTo(Math.cos(angle) * (ring + (major ? 10 : 6)), Math.sin(angle) * (ring + (major ? 10 : 6)));
    over.stroke();
  }

  if (share > 0) {
    const start = -Math.PI / 2;
    const sweep = share * Math.PI * 2 * progress;
    over.lineCap = "round";
    over.lineWidth = 3;
    if (share < 1) {
      over.strokeStyle = "rgba(94,214,178,0.45)";
      over.beginPath();
      over.arc(0, 0, gauge, start + sweep + 0.08, start + Math.PI * 2 - 0.08);
      over.stroke();
    }
    over.strokeStyle = theme.activeEdge;
    over.shadowColor = theme.activeEdge;
    over.shadowBlur = 10;
    over.beginPath();
    over.arc(0, 0, gauge, start, start + sweep);
    over.stroke();
    over.shadowBlur = 0;
    over.lineCap = "butt";
  }

  over.strokeStyle = "rgba(255,255,255,0.55)";
  over.lineWidth = 1.2;
  for (const [sx, sy] of [[-1, -1], [1, -1], [1, 1], [-1, 1]]) {
    over.beginPath();
    over.moveTo(sx * bracket, sy * (bracket - 10));
    over.lineTo(sx * bracket, sy * bracket);
    over.lineTo(sx * (bracket - 10), sy * bracket);
    over.stroke();
  }
  over.restore();

  drawLensChip(x, y, bracket, share, noise, value, progress);
}

function drawLensChip(x, y, bracket, share, noise, value, progress) {
  const { width } = renderer.getDimensions();
  const fullName = graph.getNodeAttribute(selected, "label") ?? "";
  const name = fullName.length > 30 ? `${fullName.slice(0, 29)}…` : fullName;
  const percent = share > 0 ? `${Math.round(share * 100)}%` : "";
  const unit = graph.getNodeAttribute(selected, "unit") ?? (value === 1 ? "item" : "items");
  const detail = share > 0 ? `${noise.toLocaleString()} of ${value.toLocaleString()}` : `${value.toLocaleString()} ${unit}`;
  const nameFont = "600 12px -apple-system, sans-serif";
  const percentFont = "600 13px ui-monospace, Menlo, monospace";
  const textFont = "500 11px -apple-system, sans-serif";

  over.save();
  over.globalAlpha = progress;
  over.font = nameFont;
  const nameWidth = over.measureText(name).width;
  over.font = percentFont;
  const percentWidth = over.measureText(percent).width;
  over.font = textFont;
  const shareWidth = share > 0 ? percentWidth + over.measureText(" generated").width : 0;
  const chipWidth = Math.max(nameWidth, shareWidth, over.measureText(detail).width) + 18;
  const chipHeight = share > 0 ? 54 : 38;
  // A drawer can cover the right edge, so the chip flips to the left when it would land there.
  const right = width - insets.right;
  const left = x + bracket + 10 + chipWidth > right ? x - bracket - 10 - chipWidth : x + bracket + 10;
  const top = Math.max(y - chipHeight / 2, 8);
  over.fillStyle = "rgba(8,14,16,0.86)";
  over.strokeStyle = "rgba(241,207,134,0.3)";
  over.lineWidth = 1;
  over.beginPath();
  over.roundRect(left, top, chipWidth, chipHeight, 8);
  over.fill();
  over.stroke();

  over.textBaseline = "alphabetic";
  over.font = nameFont;
  over.fillStyle = "#fff4dc";
  over.fillText(name, left + 9, top + 16);
  let lineY = top + 32;
  if (share > 0) {
    over.font = percentFont;
    over.fillStyle = theme.activeEdge;
    over.fillText(percent, left + 9, lineY);
    over.font = textFont;
    over.fillStyle = "rgba(230,238,240,0.75)";
    over.fillText(" generated", left + 9 + percentWidth, lineY);
    lineY += 14;
  }
  over.font = textFont;
  over.fillStyle = "rgba(154,171,176,0.95)";
  over.fillText(detail, left + 9, lineY);
  over.restore();
}

function drawFlow(now) {
  if (flowEdges.length === 0) return;
  over.save();
  over.fillStyle = theme.suspect;
  over.shadowColor = theme.suspect;
  over.shadowBlur = 8;
  flowEdges.forEach((edge, index) => {
    const [source, target] = graph.extremities(edge);
    const from = screenPosition(source);
    const to = screenPosition(target);
    for (let dot = 0; dot < 2; dot++) {
      const phase = index * 0.17 + dot * 0.5;
      const t = allowsMotion ? (now / 1800 + phase) % 1 : (phase % 1);
      over.beginPath();
      over.arc(from.x + (to.x - from.x) * t, from.y + (to.y - from.y) * t, 1.7, 0, Math.PI * 2);
      over.fill();
    }
  });
  over.restore();
}

function drawOverlays() {
  const now = performance.now();
  const { width, height } = renderer.getDimensions();
  sizeOverlays();
  drawUnder();
  over.clearRect(0, 0, width, height);
  drawFlow(now);
  drawLens(now);
}

function overlayNeedsAnimation() {
  if (!allowsMotion) return false;
  return flowEdges.length > 0 || (selected !== null && performance.now() - lensStarted < LENS_DURATION);
}

// The overlays only animate while something moves, so an idle graph costs nothing.
function startOverlayLoop() {
  if (overlayLoop !== null || !overlayNeedsAnimation()) return;
  const step = () => {
    drawOverlays();
    overlayLoop = overlayNeedsAnimation() ? requestAnimationFrame(step) : null;
  };
  overlayLoop = requestAnimationFrame(step);
}

renderer.on("afterRender", drawOverlays);

// Dots shrink as a level gets busier, otherwise hundreds of them merge into one blob.
function nodeSize(value, maximum, count, ceiling = 22) {
  const largest = Math.max(6, Math.min(ceiling, 22 * Math.sqrt(40 / count)));
  const smallest = Math.max(1.5, Math.min(4, 4 * Math.sqrt(100 / count)));
  const ratio = maximum <= 1 ? 0.3 : Math.sqrt(value / maximum);
  return smallest + ratio * (largest - smallest);
}

function iterationsFor(count) {
  if (count <= 200) return 400;
  if (count <= 1000) return 200;
  return 80;
}

const valueOf = (id) => graph.getNodeAttribute(id, "value");

function byGroupThenValue(a, b) {
  const groupA = graph.getNodeAttribute(a, "group");
  const groupB = graph.getNodeAttribute(b, "group");
  return groupA !== groupB ? groupA - groupB : valueOf(b) - valueOf(a);
}

// MARK: Layouts. Each returns { id: { x, y } } without moving anything.

// Starts from the same seed every time, so switching views doesn't change the result.
function forceLayout() {
  if (forceCache) return forceCache;
  if (graph.order < 2) {
    forceCache = { ...seedPositions };
    return forceCache;
  }
  const current = {};
  graph.forEachNode((id, attributes) => {
    current[id] = { x: attributes.x, y: attributes.y };
    graph.mergeNodeAttributes(id, seedPositions[id]);
  });
  forceCache = forceAtlas2(graph, {
    iterations: iterationsFor(graph.order),
    getEdgeWeight: "weight",
    settings: {
      ...forceAtlas2.inferSettings(graph),
      barnesHutOptimize: graph.order > 300,
      linLogMode: true,
      scalingRatio: graph.order > 100 ? 40 : 10,
      outboundAttractionDistribution: true,
    },
  });
  graph.forEachNode((id) => graph.mergeNodeAttributes(id, current[id]));
  return forceCache;
}

// Sigma's y axis points up, so this starts at twelve o'clock and runs clockwise.
const angleFromTop = (fraction) => Math.PI / 2 - fraction * 2 * Math.PI;

// Everything on one ring, grouped so each colour sits together. Links cross the middle.
function circleLayout() {
  const nodes = graph.nodes().sort(byGroupThenValue);
  const positions = {};
  nodes.forEach((id, index) => {
    const angle = angleFromTop(index / nodes.length);
    positions[id] = { x: Math.cos(angle) * 100, y: Math.sin(angle) * 100 };
  });
  return positions;
}

// Ring two: the gap between children on one arc, and the room each gets in a crowded wedge.
const CHILD_SPACING = 7;
const CHILD_AREA = CHILD_SPACING * CHILD_SPACING * 2.5;
// The golden ratio's fraction, which spreads any count of steps evenly across a range.
const GOLDEN_FRACTION = 0.6180339887498949;

// The centre, its children on ring one, and each child's own children fanned out behind it.
// A child's slice of the circle grows with how many children it has.
function ringsLayout() {
  const ringOf = (id) => graph.getNodeAttribute(id, "ring");
  const first = graph.filterNodes((id) => ringOf(id) === 1).sort(byGroupThenValue);
  if (first.length === 0) return circleLayout();

  const children = new Map(first.map((id) => [id, []]));
  graph.forEachNode((id, attributes) => {
    if (attributes.ring === 2 && children.has(attributes.parent)) children.get(attributes.parent).push(id);
  });
  for (const list of children.values()) list.sort((a, b) => valueOf(b) - valueOf(a));

  const hasOuterRing = [...children.values()].some((list) => list.length > 0);
  const innerRadius = hasOuterRing ? 150 : 170;
  const outerRadius = 250;
  // The floor keeps small items from bunching together next to a huge neighbour's slice.
  const weights = first.map((id) => 4 + Math.sqrt(children.get(id).length));
  const totalWeight = weights.reduce((sum, weight) => sum + weight, 0);

  const positions = {};
  graph.forEachNode((id, attributes) => {
    if (attributes.ring === 0) positions[id] = { x: 0, y: 0 };
  });
  let used = 0;
  first.forEach((id, index) => {
    const share = weights[index] / totalWeight;
    const span = share * 2 * Math.PI;
    const middle = angleFromTop(used + share / 2);
    positions[id] = { x: Math.cos(middle) * innerRadius, y: Math.sin(middle) * innerRadius };

    const list = children.get(id);
    if (list.length > 0) {
      const usable = span * 0.9;
      const capacity = Math.max(1, Math.floor((usable * outerRadius) / CHILD_SPACING));
      if (list.length <= capacity) {
        // They fit on one arc behind their item.
        list.forEach((child, childIndex) => {
          const angle = list.length === 1 ? middle : middle + usable / 2 - (usable * (childIndex + 0.5)) / list.length;
          positions[child] = { x: Math.cos(angle) * outerRadius, y: Math.sin(angle) * outerRadius };
        });
      } else {
        // A crowded slice fills a wedge behind its item, biggest nearest the centre. Steps of the
        // golden ratio spread them evenly across the wedge, and a little jitter, the same on every
        // redraw, keeps that from reading as rows and columns.
        const reach = Math.sqrt(outerRadius ** 2 + (2 * list.length * CHILD_AREA) / usable);
        const phase = (hashString(id) >>> 0) / 4294967296;
        list.forEach((child, childIndex) => {
          const random = seededRandom(hashString(child));
          const depth = Math.min(1, (childIndex + 0.1 + 0.8 * random()) / list.length);
          const radius = Math.sqrt(outerRadius ** 2 + depth * (reach ** 2 - outerRadius ** 2));
          const across = ((childIndex * GOLDEN_FRACTION + phase) % 1) - 0.5 + (random() - 0.5) * 0.12;
          const angle = middle + Math.max(-0.5, Math.min(0.5, across)) * usable;
          positions[child] = { x: Math.cos(angle) * radius, y: Math.sin(angle) * radius };
        });
      }
    }
    used += share;
  });
  return positions;
}

// One cluster per area (where things live), largest first. Members spiral out from the
// cluster's centre, biggest in the middle, and clusters are pushed apart until none overlap.
function areasLayout() {
  const spacing = 6;
  const members = new Map();
  graph.forEachNode((id, attributes) => {
    const key = attributes.area ?? labelByGroup.get(attributes.group) ?? "Other";
    if (!members.has(key)) members.set(key, []);
    members.get(key).push(id);
  });
  const clusters = [...members.entries()]
    .map(([label, ids]) => ({
      label,
      ids: ids.sort((a, b) => valueOf(b) - valueOf(a)),
      radius: spacing * (Math.sqrt(ids.length) + 2),
      x: 0,
      y: 0,
    }))
    .sort((a, b) => b.ids.length - a.ids.length);

  clusters.forEach((cluster, index) => {
    const angle = index * GOLDEN_ANGLE;
    const distance = index === 0 ? 0 : (clusters[0].radius + cluster.radius) * Math.sqrt(index);
    cluster.x = Math.cos(angle) * distance;
    cluster.y = Math.sin(angle) * distance;
  });
  const gap = spacing * 3;
  for (let pass = 0; pass < 400; pass++) {
    for (const cluster of clusters) {
      cluster.x *= 0.97;
      cluster.y *= 0.97;
    }
    let overlapping = false;
    for (let i = 0; i < clusters.length; i++) {
      for (let j = i + 1; j < clusters.length; j++) {
        const a = clusters[i];
        const b = clusters[j];
        let dx = b.x - a.x;
        let dy = b.y - a.y;
        let distance = Math.hypot(dx, dy);
        const minimum = a.radius + b.radius + gap;
        if (distance >= minimum) continue;
        overlapping = true;
        if (distance < 0.001) {
          dx = Math.cos(j);
          dy = Math.sin(j);
          distance = 1;
        }
        const push = (minimum - distance) / 2;
        a.x -= (dx / distance) * push;
        a.y -= (dy / distance) * push;
        b.x += (dx / distance) * push;
        b.y += (dy / distance) * push;
      }
    }
    if (!overlapping && pass > 40) break;
  }

  const positions = {};
  for (const cluster of clusters) {
    cluster.ids.forEach((id, index) => {
      const radius = spacing * Math.sqrt(index + 0.5);
      positions[id] = {
        x: cluster.x + Math.cos(index * GOLDEN_ANGLE) * radius,
        y: cluster.y + Math.sin(index * GOLDEN_ANGLE) * radius,
      };
    });
  }
  areaClusters = clusters;
  return positions;
}

function positionsFor(name) {
  switch (name) {
    case "circle": return circleLayout();
    case "rings": return ringsLayout();
    case "areas": return areasLayout();
    default: return forceLayout();
  }
}

// MARK: Area names, drawn as HTML above the canvas.

function rebuildAreaLabels() {
  areaLayer.replaceChildren();
  if (layout !== "areas") {
    areaClusters = [];
    return;
  }
  for (const cluster of areaClusters) {
    // A one-dot area would just repeat the dot's own label.
    if (cluster.ids.length < 2) continue;
    const element = document.createElement("div");
    element.className = "area";
    element.textContent = cluster.label;
    areaLayer.appendChild(element);
    cluster.element = element;
  }
  positionAreaLabels();
}

function positionAreaLabels() {
  for (const cluster of areaClusters) {
    if (!cluster.element) continue;
    const top = renderer.graphToViewport({ x: cluster.x, y: cluster.y + cluster.radius });
    const bottom = renderer.graphToViewport({ x: cluster.x, y: cluster.y - cluster.radius });
    cluster.element.style.left = `${top.x}px`;
    cluster.element.style.top = `${Math.min(top.y, bottom.y) - 4}px`;
    const inIsolation = isolatedGroup === null
      || cluster.ids.some((id) => graph.getNodeAttribute(id, "group") === isolatedGroup);
    cluster.element.style.opacity = inIsolation ? "0.75" : "0.2";
  }
}

renderer.on("afterRender", positionAreaLabels);

// MARK: Camera. The panels float over the canvas, so "centre" means the middle of what's left.

const CENTERED = { x: 0.5, y: 0.5, ratio: 1, angle: 0 };

// Labels are drawn to the right of their dots, so framing leaves room for them on that side.
const LABEL_ROOM = 110;

// The area the camera frames. `insets` are what the chrome covers. With nothing open on the right,
// the right side mirrors the left rail, so the graph sits in the middle of the window.
function framing() {
  const labels = renderer.getSetting("renderLabels") ? LABEL_ROOM : 0;
  return {
    left: insets.left,
    right: Math.max(insets.right, insets.left) + labels,
    top: insets.top,
    bottom: insets.bottom,
  };
}

// Screen pixels per unit of sigma's framed space at ratio 1, signed because y runs upward.
function pixelsPerUnit() {
  const origin = renderer.framedGraphToViewport({ x: 0.5, y: 0.5 }, { cameraState: CENTERED });
  const step = renderer.framedGraphToViewport({ x: 0.6, y: 0.6 }, { cameraState: CENTERED });
  return { x: (step.x - origin.x) / 0.1, y: (step.y - origin.y) / 0.1 };
}

// The camera state that puts a framed-space point in the middle of the free area.
function cameraOn(x, y, ratio) {
  const scale = pixelsPerUnit();
  const free = framing();
  const shiftX = (free.left - free.right) / 2;
  const shiftY = (free.top - free.bottom) / 2;
  return { x: x - (shiftX * ratio) / scale.x, y: y - (shiftY * ratio) / scale.y, ratio, angle: 0 };
}

// The framed-space point in the middle of the free area, for the camera as it is now.
function centreOfFreeArea() {
  const { width, height } = renderer.getDimensions();
  const free = framing();
  const point = { x: (free.left + width - free.right) / 2, y: (free.top + height - free.bottom) / 2 };
  // The camera may have moved since the last frame, so the matrix is worked out afresh.
  return renderer.viewportToFramedGraph(point, { cameraState: renderer.getCamera().getState() });
}

// Where the drawn nodes reach in framed space, as of sigma's last pass over them. Between a
// refresh and the frame that processes it, sigma's display data holds raw positions, and a
// resize or a change of insets can land in that gap.
let framedExtent = null;

renderer.on("afterProcess", () => {
  let minX = Infinity;
  let maxX = -Infinity;
  let minY = Infinity;
  let maxY = -Infinity;
  graph.forEachNode((id) => {
    const data = renderer.getNodeDisplayData(id);
    if (!data) return;
    minX = Math.min(minX, data.x);
    maxX = Math.max(maxX, data.x);
    minY = Math.min(minY, data.y);
    maxY = Math.max(maxY, data.y);
  });
  framedExtent = minX === Infinity ? null : { minX, maxX, minY, maxY };
});

// Frames every drawn node inside the free area.
function homeCamera() {
  if (!framedExtent) return CENTERED;
  const { minX, maxX, minY, maxY } = framedExtent;
  const { width, height } = renderer.getDimensions();
  const scale = pixelsPerUnit();
  const free = framing();
  const freeWidth = Math.max(120, width - free.left - free.right - 48);
  const freeHeight = Math.max(120, height - free.top - free.bottom - 48);
  const ratio = Math.max(0.75, ((maxX - minX) * Math.abs(scale.x)) / freeWidth, ((maxY - minY) * Math.abs(scale.y)) / freeHeight);
  const { x, y } = cameraOn((minX + maxX) / 2, (minY + maxY) / 2, ratio);
  return { x, y, ratio, angle: 0 };
}

// The camera is home while it frames the whole graph, and home follows the window and the chrome
// as they change. Once someone pans or zooms, whatever is in the middle stays in the middle.
let homeState = null;
let headingHome = true;
let freeCentre = null;

const nearly = (a, b) => Math.abs(a - b) <= 1e-6 * Math.max(1, Math.abs(b));

function isHome() {
  if (!homeState) return true;
  const camera = renderer.getCamera();
  if (camera.isAnimating()) return headingHome;
  const state = camera.getState();
  return nearly(state.x, homeState.x) && nearly(state.y, homeState.y) && nearly(state.ratio, homeState.ratio);
}

function goHome(duration) {
  const camera = renderer.getCamera();
  const home = homeCamera();
  fittedRatio = home.ratio;
  homeState = camera.validateState(home);
  headingHome = true;
  if (duration > 0 && allowsMotion) {
    camera.animate(home, { duration });
  } else {
    if (camera.isAnimating()) camera.cancelAnimation();
    camera.setState(home);
  }
}

// Called when the window or the chrome changes size: home re-frames, anywhere else holds its centre.
function reframe() {
  if (isHome()) {
    goHome(0);
  } else if (freeCentre) {
    const camera = renderer.getCamera();
    camera.setState(cameraOn(freeCentre.x, freeCentre.y, camera.getState().ratio));
  }
}

// Changes what the camera frames, such as the chrome's insets or room for labels.
function changeFraming(apply) {
  const wasHome = isHome();
  apply();
  if (graph.order === 0) return;
  if (wasHome) goHome(220);
  else freeCentre = centreOfFreeArea();
}

renderer.getCamera().on("updated", () => {
  freeCentre = centreOfFreeArea();
});
// Sigma resizes at the start of a frame, before drawing, so the new framing is in that same frame.
renderer.on("resize", reframe);
// Someone taking the camera mid-animation means it's no longer on its way home.
for (const event of ["wheel", "mousedown", "doubleClick"]) {
  renderer.getMouseCaptor().on(event, () => {
    headingHome = false;
  });
}

function applyLayout(name, animate) {
  layout = name;
  renderer.refresh();
  const targets = positionsFor(name);
  if (stopAnimation) {
    stopAnimation();
    stopAnimation = null;
  }
  if (animate && allowsMotion && graph.order <= 3000) {
    stopAnimation = animateNodes(graph, targets, { duration: 450, easing: "quadraticInOut" }, () => {
      stopAnimation = null;
      renderer.refresh();
      goHome(200);
    });
  } else {
    graph.updateEachNodeAttributes((id, attributes) => ({ ...attributes, ...targets[id] }), { attributes: ["x", "y"] });
    renderer.refresh();
    goHome(0);
  }
  rebuildAreaLabels();
}

// A new review finding arrives with a short pull-back of the camera, so stepping through feels like flying.
function playEntrance() {
  if (!allowsMotion) return;
  const camera = renderer.getCamera();
  const home = camera.getState();
  camera.setState({ ...home, ratio: home.ratio * 1.6 });
  camera.animate(home, { duration: 420, easing: "cubicOut" });
}

function render(scene, layoutName, entrance) {
  hovered = null;
  selected = null;
  isolatedGroup = null;
  activeNodes = new Set();
  activeEdges = new Set();
  flowEdges = [];
  forceCache = null;
  seedPositions = {};
  slotByGroup = new Map(scene.groups.map((group) => [group.id, group.slot]));
  labelByGroup = new Map(scene.groups.map((group) => [group.id, group.label]));

  graph.clear();
  // Each ring is sized on its own, so a few projects aren't shrunk by thousands of communities.
  const rings = new Map();
  for (const node of scene.nodes) {
    const key = node.ring ?? "all";
    const entry = rings.get(key) ?? { maximum: 1, count: 0 };
    entry.maximum = Math.max(entry.maximum, node.value);
    entry.count += 1;
    rings.set(key, entry);
  }
  const count = Math.max(scene.nodes.length, 1);
  scene.nodes.forEach((node, index) => {
    const ring = rings.get(node.ring ?? "all");
    // Seeding each group near its own angle keeps force clusters from starting tangled.
    const angle = (node.group + index / count) * GOLDEN_ANGLE;
    const radius = 10 + Math.sqrt(index) * 4;
    const seed = { x: Math.cos(angle) * radius, y: Math.sin(angle) * radius };
    seedPositions[node.id] = seed;
    graph.addNode(node.id, {
      ...seed,
      size: node.ring === 0 ? nodeSize(2, 2, 60) : nodeSize(isDust(node) ? 1 : node.value, ring.maximum, ring.count, node.ring === 1 ? 16 : 22) * (isDust(node) ? 0.6 : 1),
      label: node.label,
      hoverText: `${node.label}  ·  ${node.value.toLocaleString()}`,
      value: node.value,
      group: node.group,
      ghost: node.ghost,
      ring: node.ring,
      parent: node.parent,
      area: node.area,
      noise: node.noise,
      unit: node.unit,
      isDust: isDust(node),
      color: colourFor(node),
      // Bigger items paint over smaller ones.
      rank: Math.round(Math.sqrt(node.value)),
    });
  });

  const maxWeight = scene.edges.reduce((largest, edge) => Math.max(largest, edge.tree ? 1 : edge.weight), 1);
  for (const edge of scene.edges) {
    if (!graph.hasNode(edge.source) || !graph.hasNode(edge.target) || edge.source === edge.target) continue;
    if (graph.hasEdge(edge.source, edge.target)) continue;
    graph.addEdge(edge.source, edge.target, {
      size: edge.tree ? 0.5 : 0.5 + (Math.log1p(edge.weight) / Math.log1p(maxWeight)) * 2.5,
      weight: edge.weight,
      tree: Boolean(edge.tree),
      baseColor: edgeBaseColour(edge),
      // Mostly false matches, so the whole line is treated as suspect.
      isSuspect: (edge.suspect ?? 0) * 2 >= edge.weight && !edge.tree,
    });
  }

  buildOverlayData(scene.nodes);

  applyLayout(layoutName || layout, false);
  renderer.setGraphState({ hasFocus: false });
  if (entrance) playEntrance();
  drawOverlays();
  post({ type: "rendered", nodes: graph.order, edges: graph.size });
}

window.studio = {
  render,
  setLayout(name) {
    if (name !== layout) applyLayout(name, true);
  },
  setLabels(visible) {
    if (renderer.getSetting("renderLabels") === visible) return;
    changeFraming(() => renderer.setSetting("renderLabels", visible));
  },
  isolate(group) {
    isolatedGroup = group;
    applyEmphasis();
  },
  setReviewing(reviewing) {
    isReviewing = reviewing;
    renderer.setGraphState({ isReviewing });
    applyEmphasis();
  },
  spotlight(ids) {
    spotlightIds = ids ? new Set(ids) : null;
    applyEmphasis();
  },
  setMotion(allowed) {
    allowsMotion = allowed;
    startOverlayLoop();
    drawOverlays();
  },
  setInsets(value) {
    const same = ["left", "right", "top", "bottom"].every((side) => insets[side] === value[side]);
    if (!same) changeFraming(() => { insets = value; });
  },
  fit() {
    renderer.refresh();
    goHome(250);
  },
  zoom(zoomsIn) {
    const camera = renderer.getCamera();
    const duration = allowsMotion ? 200 : 0;
    headingHome = false;
    if (zoomsIn) camera.zoomIn({ duration });
    else camera.zoomOut({ duration });
  },
  // Selects a node and moves the camera onto it. Returns false if it isn't drawn.
  focus(id, movesCamera = true) {
    if (!graph.hasNode(id)) return false;
    setSelected(id);
    if (!movesCamera) {
      post({ type: "select", id });
      return true;
    }
    const data = renderer.getNodeDisplayData(id);
    if (data) {
      headingHome = false;
      const target = cameraOn(data.x, data.y, 0.3);
      if (allowsMotion) renderer.getCamera().animate(target, { duration: 500 });
      else renderer.getCamera().setState(target);
    }
    post({ type: "select", id });
    return true;
  },
};

applySurface();
post({ type: "ready" });
