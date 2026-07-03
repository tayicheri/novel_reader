# EchoRead (Audio Web Reader) — Design System

Source: Google Stitch project **Audio Web Reader** (`projects/8324331772808102895`)

---
name: EchoRead
colors:
  surface: '#f9f9ff'
  surface-dim: '#cfdaf2'
  surface-bright: '#f9f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f0f3ff'
  surface-container: '#e7eeff'
  surface-container-high: '#dee8ff'
  surface-container-highest: '#d8e3fb'
  on-surface: '#111c2d'
  on-surface-variant: '#434655'
  inverse-surface: '#263143'
  inverse-on-surface: '#ecf1ff'
  outline: '#737686'
  outline-variant: '#c3c6d7'
  surface-tint: '#0053db'
  primary: '#004ac6'
  on-primary: '#ffffff'
  primary-container: '#2563eb'
  on-primary-container: '#eeefff'
  inverse-primary: '#b4c5ff'
  secondary: '#5a5f62'
  on-secondary: '#ffffff'
  secondary-container: '#dce0e4'
  on-secondary-container: '#5e6367'
  tertiary: '#46566c'
  on-tertiary: '#ffffff'
  tertiary-container: '#5e6e85'
  on-tertiary-container: '#e9f0ff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dbe1ff'
  primary-fixed-dim: '#b4c5ff'
  on-primary-fixed: '#00174b'
  on-primary-fixed-variant: '#003ea8'
  secondary-fixed: '#dfe3e7'
  secondary-fixed-dim: '#c3c7cb'
  on-secondary-fixed: '#171c1f'
  on-secondary-fixed-variant: '#43474b'
  tertiary-fixed: '#d3e4fe'
  tertiary-fixed-dim: '#b7c8e1'
  on-tertiary-fixed: '#0b1c30'
  on-tertiary-fixed-variant: '#38485d'
  background: '#f9f9ff'
  on-background: '#111c2d'
  surface-variant: '#d8e3fb'
typography:
  headline-lg:
    fontFamily: Hanken Grotesk
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Hanken Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Hanken Grotesk
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  headline-lg-mobile:
    fontFamily: Hanken Grotesk
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  container-margin: 20px
  stack-gap-sm: 8px
  stack-gap-md: 16px
  stack-gap-lg: 24px
  player-height: 80px
---

## Brand & Style
The brand personality is calm, methodical, and utilitarian. It targets professionals and students who consume long-form content via audio, requiring a UI that recedes into the background to prioritize focus. 

The design system employs a **Corporate / Modern** aesthetic with a lean toward **Minimalism**. It uses generous whitespace and a "content-first" hierarchy. The emotional response is one of reliability and clarity, ensuring the user feels the application is a stable tool for learning rather than a distracting social platform.

## Colors
The palette is anchored by **Deep Charcoal (#1E293B)** for primary text and high-contrast elements, providing a grounded, professional feel. **Soft Blue (#2563EB)** serves as the primary action color, used for play buttons, active states, and progress indicators. 

The background utilizes a series of off-whites and cool grays to reduce eye strain during long reading sessions. Use `secondary_color_hex` for large surface areas and `tertiary_color_hex` for secondary metadata and icons.

## Typography
The system uses **Hanken Grotesk** for headlines to provide a sharp, contemporary edge that feels modern and precise. For all body text and interface labels, **Inter** is used for its exceptional legibility and systematic performance on mobile screens. 

Line heights are intentionally generous (1.5x for body) to ensure that users can scan document titles and transcripts without fatigue. Tracking is slightly tightened on headlines for a more premium, editorial appearance.

## Layout & Spacing
This design system utilizes a **fluid grid** optimized for mobile viewports. A standard 4-column grid is used for mobile, with a fixed 20px outer margin to ensure content does not hit the edge of the device.

Vertical rhythm is maintained through an 8px base unit. Component internal padding should follow this scale (8, 16, 24). The most critical layout feature is the **Fixed Player Control**, which maintains a constant height of 80px at the bottom of the viewport, requiring a bottom padding buffer on all scrollable views to prevent content occlusion.

## Elevation & Depth
Depth is signaled through **ambient shadows** and **tonal layers**. 

1.  **Level 0 (Base):** The main canvas, using a very light gray or white.
2.  **Level 1 (Cards/Inputs):** Subtle 1px borders in a soft gray, with no shadow, to keep the UI flat and clean.
3.  **Level 2 (Fixed Controls/Modals):** The bottom player and floating action buttons use a diffused, low-opacity shadow (e.g., `y: 4, blur: 12, color: rgba(30, 41, 59, 0.08)`) to lift them above the scrolling content.

Avoid heavy blacks in shadows; use the Deep Charcoal color at low opacity to maintain color harmony.

## Shapes
The shape language is consistently **Rounded**. Standard UI elements like buttons, input fields, and article cards use a 0.5rem (8px) corner radius. This balances the professional tone of the typography with a friendly, accessible feel. 

Progress bars and audio waveforms should use fully rounded (pill-shaped) caps to emphasize the fluid nature of audio playback.

## Components

-   **Buttons:** Primary buttons use a solid Soft Blue fill with white text. Secondary buttons use a transparent background with a 1px border of the same blue. 
-   **Audio Player:** The persistent bottom player should feature a blurred backdrop (glassmorphism) to subtly hint at the content passing beneath it. Use high-contrast charcoal icons for playback controls.
-   **Progress Bars:** Use a thick 6px track. The background track is light gray, while the progress fill is Soft Blue. The "scrubber" handle only appears during active interaction.
-   **Cards:** Article or book cards should have a 1px border. Do not use shadows for cards unless they are being actively dragged or reordered.
-   **Input Fields:** Search and filter bars should use a subtle background tint (Soft Gray) rather than a white background to differentiate them from the main canvas.
-   **Lists:** Use 16px vertical padding for list items with a thin separator line that stops 20px before the right edge to maintain the container margin.