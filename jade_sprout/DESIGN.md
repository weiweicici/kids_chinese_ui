---
name: Jade Sprout
colors:
  surface: '#f4fbf8'
  surface-dim: '#d4dcd9'
  surface-bright: '#f4fbf8'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eef5f2'
  surface-container: '#e8efec'
  surface-container-high: '#e3eae7'
  surface-container-highest: '#dde4e1'
  on-surface: '#161d1b'
  on-surface-variant: '#3e4945'
  inverse-surface: '#2b3230'
  inverse-on-surface: '#ebf2ef'
  outline: '#6e7a75'
  outline-variant: '#bdc9c4'
  surface-tint: '#006b58'
  primary: '#006b58'
  on-primary: '#ffffff'
  primary-container: '#66c2aa'
  on-primary-container: '#004e40'
  inverse-primary: '#7bd7be'
  secondary: '#8f4e00'
  on-secondary: '#ffffff'
  secondary-container: '#fc9d41'
  on-secondary-container: '#6b3900'
  tertiary: '#0060ac'
  on-tertiary: '#ffffff'
  tertiary-container: '#7bb4ff'
  on-tertiary-container: '#00457e'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#97f4da'
  primary-fixed-dim: '#7bd7be'
  on-primary-fixed: '#002019'
  on-primary-fixed-variant: '#005142'
  secondary-fixed: '#ffdcc2'
  secondary-fixed-dim: '#ffb77a'
  on-secondary-fixed: '#2e1500'
  on-secondary-fixed-variant: '#6d3a00'
  tertiary-fixed: '#d4e3ff'
  tertiary-fixed-dim: '#a4c9ff'
  on-tertiary-fixed: '#001c39'
  on-tertiary-fixed-variant: '#004883'
  background: '#f4fbf8'
  on-background: '#161d1b'
  surface-variant: '#dde4e1'
typography:
  display-character:
    fontFamily: Noto Serif
    fontSize: 120px
    fontWeight: '500'
    lineHeight: 140px
  card-character:
    fontFamily: Noto Serif
    fontSize: 64px
    fontWeight: '500'
    lineHeight: 80px
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '800'
    lineHeight: 40px
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '500'
    lineHeight: 26px
  label-bold:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '700'
    lineHeight: 20px
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  margin-page: 40px
  gutter-grid: 24px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 32px
---

## Brand & Style

The design system is centered on a "Playful Zen" aesthetic tailored for early childhood education. It balances the discipline of Chinese calligraphy with the soft, approachable nature of modern children’s media. The target audience is children aged 5-10 and their parents, requiring a UI that feels safe, encouraging, and academically credible yet fun.

The design style is **Soft Minimalism** with **Tactile** elements. It avoids the over-stimulation of typical "bright" kids' apps in favor of a focused, calm learning environment. Surfaces use gentle rounded corners and subtle depth to make interactive elements feel "touchable" on an iPad screen, while heavy whitespace ensures the complex strokes of Chinese characters remain the focal point.

## Colors

The palette is anchored by a refreshing **Mint Teal** (#66C2AA), chosen for its association with growth and clarity. This primary color is reserved strictly for primary actions and success states. 

The background uses a **Soft Pastel Mint** (#F0F7F4), which reduces eye strain during long study sessions compared to pure white. For text, a deep **Charcoal Grey** (#2D3436) is used instead of pure black to maintain high legibility while appearing softer against the pastel background. Secondary colors like warm orange are used sparingly for "streak" icons or celebratory moments to provide a rhythmic pop of energy.

## Typography

The typography strategy employs a dual-font approach. For all UI elements, labels, and English instructions, **Plus Jakarta Sans** is used for its friendly, open counters and bold weights that are highly legible for young readers. 

For the Chinese characters, **Noto Serif** (serving as a digital-optimized KaiTi/Calligraphy style) is required. It provides the necessary stroke contrast and traditional aesthetic essential for character recognition and stroke-order learning. Headlines should always be bold to create a clear information hierarchy, while body text remains medium-weight for comfort.

## Layout & Spacing

Designed specifically for the iPad’s 4:3 aspect ratio, the layout uses a **Fixed Grid** model. 
- **The Learning Grid**: A central 4x4 grid for character cards. This grid uses a 24px gutter to ensure distinct touch targets for small fingers.
- **Navigation**: A fixed top navigation bar (80px height) houses "Back" and "Progress" indicators. A bottom action bar (100px height) contains the primary "Next" or "Check" buttons.
- **Safe Zones**: Page margins are set to a generous 40px to prevent fingers from obscuring content while holding the tablet.

## Elevation & Depth

This design system uses **Tonal Layers** combined with **Ambient Shadows** to create a tactile, physical feel.
- **Base Level**: The soft pastel mint background.
- **Card Level**: White surfaces with a very soft, diffused shadow (10% opacity of the primary teal) to make cards look like they are sitting on top of the page.
- **Interactive Level**: Buttons use a "Pressable" effect—when active, they have a slight inner shadow to simulate being pushed down into the screen.
- **Zero Outlines**: Avoid harsh borders. Use subtle color shifts or soft shadows to define boundaries.

## Shapes

The shape language is consistently **Rounded**. 
- Standard UI components (Inputs, Small Cards) use a **0.5rem (8px)** radius.
- Large Character Cards and Primary Action Buttons use **1rem (16px)** radius to feel friendlier and more substantial.
- Progress bars and pill-shaped tags use full rounding (capsule style).
- Any "Active" state for a grid item should be highlighted with a 4px thick stroke in the primary mint color, following the same corner radius.

## Components

### Buttons
Primary buttons are Mint (#66c2aa) with bold white text. They should have a "squishy" feel, achieved by using a slightly darker teal bottom-border (3px) to give a 3D effect that flattens on press.

### Character Cards
White background, 1rem corner radius. The Chinese character is centered using the `card-character` style. A subtle "Pinyin" label sits at the top-center of the card in a light grey.

### Progress Bar
A thick, track-style bar. The "empty" state is a darker version of the background mint, while the "fill" state is the primary Mint Teal.

### Navigation Bars
Transparent or semi-translucent background to maintain a sense of lightness. Icons should be "chunky" with rounded terminals, matching the weight of the typography.

### Checkboxes / Selection Indicators
When a card is selected in the 4x4 grid, it scales up slightly (1.05x) and gains a Mint border. A small circular checkmark appears in the top-right corner of the card.