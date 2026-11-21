# StockVault Dashboard — Design System & UI Specification

---

## 1. Design Philosophy

**"Dark, premium, data-dense."**

StockVault is a financial data explorer. The design language should evoke the feel of a professional trading terminal (think Bloomberg Terminal meets modern web aesthetics). Every pixel should communicate competence, precision, and sophistication.

### Design Principles
1. **Glassmorphism** — Frosted glass cards with subtle backdrop blur and translucent backgrounds
2. **Dark-first** — Deep charcoal/navy backgrounds that reduce eye strain and make data pop
3. **Data density** — Show as much useful data as possible without clutter
4. **Micro-animations** — Subtle transitions that make the interface feel alive and responsive
5. **Gradient accents** — Vibrant gradients used sparingly on borders, buttons, and highlights

---

## 2. Color Palette

### Primary Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `--bg-primary` | `#0a0f1a` | Main background (deep navy-black) |
| `--bg-secondary` | `#111827` | Card backgrounds, sidebar |
| `--bg-card` | `rgba(17, 24, 39, 0.8)` | Glassmorphism card base |
| `--border-glass` | `rgba(255, 255, 255, 0.08)` | Subtle card borders |
| `--text-primary` | `#f1f5f9` | Primary text (near-white) |
| `--text-secondary` | `#94a3b8` | Secondary text (muted slate) |
| `--text-muted` | `#475569` | Disabled / tertiary text |

### Accent Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `--accent-gold` | `#f0b429` | Logo highlight, premium indicators |
| `--accent-green` | `#10b981` | Positive values, gains, online status |
| `--accent-red` | `#ef4444` | Negative values, losses, errors |
| `--accent-blue` | `#3b82f6` | Links, interactive elements, selected states |
| `--accent-purple` | `#8b5cf6` | Charts, secondary visual accent |
| `--accent-cyan` | `#06b6d4` | Hover effects, tertiary accent |

### Gradient Definitions

```css
/* Primary gradient — used on active sidebar items and CTAs */
--gradient-primary: linear-gradient(135deg, #3b82f6, #8b5cf6);

/* Gold gradient — used on the logo and premium badges */
--gradient-gold: linear-gradient(135deg, #f0b429, #f59e0b);

/* Card border gradient — subtle shimmer effect */
--gradient-border: linear-gradient(135deg, rgba(59,130,246,0.3), rgba(139,92,246,0.3));

/* Green-to-teal for positive metrics */
--gradient-positive: linear-gradient(135deg, #10b981, #06b6d4);
```

---

## 3. Typography

### Font Stack

| Role | Font | Weight | Size | Source |
|------|------|--------|------|--------|
| **Headings** | Inter | 700 (Bold) | 24px – 32px | Google Fonts |
| **Body** | Inter | 400 (Regular) | 14px – 16px | Google Fonts |
| **Code / SQL** | JetBrains Mono | 400 | 13px – 14px | Google Fonts |
| **KPI Numbers** | Inter | 800 (ExtraBold) | 36px – 48px | Google Fonts |
| **Labels / Captions** | Inter | 500 (Medium) | 11px – 12px | Google Fonts |

### Type Scale

```
48px — KPI hero numbers (₹28,364 Cr)
32px — Page titles (h1)
24px — Section titles (h2)
18px — Card titles (h3)
16px — Body text
14px — Table data, secondary info
12px — Labels, badges, captions
11px — Fine print, timestamps
```

---

## 4. Component Specifications

### 4.1 Sidebar Navigation

```
Width: 240px (collapsed: 64px)
Background: --bg-secondary
Border-right: 1px solid --border-glass
```

| State | Style |
|-------|-------|
| Default | Text in --text-secondary, icon opacity 0.6 |
| Hover | Background: rgba(59,130,246,0.1), text brightens to --text-primary |
| Active | Left border: 3px solid --accent-blue, background: rgba(59,130,246,0.15), text: --text-primary |
| Section divider | 1px dashed --border-glass, uppercase label in --text-muted |

**Logo**: "STOCK" in --text-primary, "VAULT" in --accent-gold, font-weight 800.

### 4.2 KPI Stat Cards

```
Background: --bg-card with backdrop-filter: blur(12px)
Border: 1px solid --border-glass
Border-radius: 16px
Padding: 24px
Box-shadow: 0 4px 24px rgba(0, 0, 0, 0.2)
```

| Element | Style |
|---------|-------|
| Icon | 40×40px, rounded background with gradient fill |
| Value | 36px Inter ExtraBold, --text-primary |
| Label | 12px Inter Medium, --text-secondary, uppercase |
| Delta badge | Pill shape, green bg + text for positive, red for negative |

**Animation**: Numbers animate from 0 to value using `countUp` effect on mount (300ms ease-out).

### 4.3 Charts

| Property | Value |
|----------|-------|
| Background | Same glassmorphism card as KPI |
| Chart colors | Cycle through: --accent-blue, --accent-purple, --accent-cyan, --accent-gold, --accent-green |
| Grid lines | --border-glass (very subtle) |
| Tooltips | Dark bg, rounded, 12px text, shows exact value |
| Axis labels | --text-muted, 11px |

### 4.4 Data Table (SQL Results)

```
Background: --bg-card
Header row: --bg-secondary, sticky, 12px uppercase --text-muted
Data rows: 14px --text-primary
Alternating rows: every-other-row gets rgba(255,255,255,0.02)
Hover: row background rgba(59,130,246,0.08)
Border between rows: 1px solid --border-glass
```

### 4.5 Monaco Editor (SQL Playground)

```
Theme: vs-dark (built-in Monaco dark theme)
Border: 1px solid --border-glass with --gradient-border on focus
Height: 300px (resizable)
Font: JetBrains Mono, 14px
Line numbers: enabled
Minimap: disabled (saves horizontal space)
```

**Run Button**: Gradient background (--gradient-primary), white text, rounded, with a ▶ icon. Pulses subtly on hover.

### 4.6 ERD Diagram Nodes (Schema Explorer)

| Element | Style |
|---------|-------|
| Table node | Glassmorphism card, 200px wide |
| Table name header | --accent-gold text, 14px bold, dark header bar |
| Column rows | 12px, icon for PK (🔑) and FK (🔗) |
| ISA indicator | Dashed border + "ISA" badge for EQUITY/MUTUAL_FUND |
| FK edges | Curved bezier lines, --accent-blue, animated dash on hover |
| Selected node | Glowing border with --gradient-primary shadow |

---

## 5. Layout Grid

### Overall Layout
```
┌─────────────────────────────────────────────────────┐
│  Sidebar (240px fixed)  │  Main Content (fluid)      │
│                         │                             │
│                         │  ┌─────────────────────┐   │
│                         │  │  Ticker Bar (48px)    │   │
│                         │  ├─────────────────────┤   │
│                         │  │                       │   │
│                         │  │  Page Content         │   │
│                         │  │  (scrollable)         │   │
│                         │  │                       │   │
│                         │  └─────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### Dashboard Grid
```
KPI Cards:  4 columns, gap 20px, responsive (2-col on < 1280px)
Charts:     2 columns, gap 20px, each chart in a glassmorphism card
Full-width: Broker performance table spans full width below charts
```

### SQL Playground Layout
```
Top:     Monaco Editor (300px height, full width)
Middle:  Run button bar (48px)
Bottom:  Results table (remaining height, scrollable)
```

### Schema Explorer Layout
```
Left:    Table list panel (280px)
Center:  ERD canvas (fluid, React Flow)
Right:   Column inspector panel (320px, slides in on table select)
```

---

## 6. Animations & Micro-Interactions

| Interaction | Animation | Duration | Easing |
|------------|-----------|----------|--------|
| Page transition | Fade in + slide up 8px | 200ms | ease-out |
| KPI card mount | Scale from 0.95 → 1.0 + fade in | 300ms | spring(1, 80, 10) |
| KPI number count-up | Animate from 0 to final value | 800ms | ease-out |
| Sidebar item hover | Background color fade | 150ms | ease |
| Chart load | Bars/segments grow from 0 | 500ms | ease-out |
| Table row hover | Background color transition | 100ms | ease |
| Run button click | Scale 0.95 + opacity flash | 100ms | ease |
| ERD node select | Border glow pulse | 300ms | ease-in-out |
| Toast notification | Slide in from top-right | 200ms | spring |
| Error banner | Shake left-right 4px | 300ms | ease |

---

## 7. Responsive Breakpoints

| Breakpoint | Width | Layout Changes |
|------------|-------|----------------|
| Desktop XL | ≥ 1440px | Full layout, 4-col KPI grid |
| Desktop | ≥ 1280px | Full layout, 4-col KPI grid |
| Desktop SM | ≥ 1024px | Sidebar collapses to icons, 2-col KPI grid |
| Below 1024px | < 1024px | Not officially supported (show "Use desktop" message) |

---

## 8. Ticker Bar (Top Banner)

A scrolling horizontal ticker bar at the top of the main content area showing live-ish security data:

```
★ RELIANCE: ₹2,450.50  ★ TCS: ₹3,780.00  ★ INFY: ₹1,520.25  ★ HDFC BANK: ₹1,680.75
```

| Property | Value |
|----------|-------|
| Height | 40px |
| Background | --bg-secondary |
| Text | 13px, --accent-gold for tickers, --text-primary for prices |
| Animation | CSS `marquee` / `translateX` infinite scroll, 30s duration |
| Data source | Loaded from `SECURITY` table on page mount |

---

## 9. Dark Mode

The entire application is dark-mode only. There is no light mode toggle. This is intentional:
- Financial terminals are traditionally dark
- Reduces eye strain during extended data exploration sessions
- Makes gradient accents and chart colors pop
- Simpler to maintain a single design variant
