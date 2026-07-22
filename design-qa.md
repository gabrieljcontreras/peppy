# Design QA — iOS Settings Task 9

## Source

- Figma export: `/Users/gabri/Downloads/Peppy IOS (2).fig`
- Approved frame: More
- Extracted frame raster: `38236a38867f03d49a3f73ee20e45156833af197`
- Reference size: 853 × 1844
- Implementation capture: iPhone 17 Pro simulator, light appearance, confirmed mock account
- Implementation capture SHA-256: `cb25788aa09749c2bad828d0b9834d5435cd774da231ae3b0a44d415e5e09282`
- Normalized comparison SHA-256: `d048590cc9ad79466638d67981b13c1679cf17ea0753ff14006649a13735e1ba`

## Comparison

The implementation and source raster were normalized to the same 853 × 1844
canvas and inspected side by side. The implementation preserves the reference
hierarchy, horizontal alignment, card construction, icon tones, row copy,
profile identity, version placement, logout treatment, and bottom-tab context.

The following differences are intentional:

- Labs, Connected data, and Timeline are omitted by the approved release scope;
  the remaining My data rows close without empty placeholders.
- The simulator uses the current native Dynamic Island status area and floating
  system tab bar, while the supplied raster shows an older system chrome style.
- The live version and build are read from the app bundle instead of hard-coded
  Figma values.

## Accessibility checks

- Interactive rows and logout expose at least 44-point tap targets.
- Labels combine row title and supporting copy for VoiceOver.
- Text uses native SwiftUI rendering and may reflow at larger Dynamic Type sizes.
- The root remains scrollable and keeps the tab bar available.

## Result

**Passed.** No blocking visual, interaction, or accessibility mismatch remains
for the Task 9 release root.
