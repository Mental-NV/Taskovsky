# Visual measurements: settings window

These are a first reproducible set of measurements, not a complete design system. On 3 November 2026, the installed macOS TickTick app was in light appearance and the Computer Use capture of its Settings window decoded as an **800 × 680 JPEG**. Coordinates below are raster pixels in that capture, measured from the upper left. The capture may be scaled and JPEG is lossy; these numbers are not established macOS points, exact asset colors, font sizes, or universal dimensions. Re-measure at known display scale and other window sizes before treating them as implementation constants. No personal content was needed for the samples.

## Smart Lists capture

| Element | Approximate raster bounds or position |
| --- | --- |
| Window capture | 800 × 680 px |
| Sidebar | x 0–219; divider at approximately x 219 |
| Main content | starts at x 220; title starts near (266, 45) |
| First rounded group | x 248–771, y 70–357; seven rows, centers approximately y 95, 135, 175, 215, 255, 295, 335 |
| Second rounded group | x 248–771, y 372–459; two row centers near y 395 and 435 |
| Third rounded group | x 248–771, y 474–602; three row centers near y 499, 539, 579 |
| Group inset | row icons centered near x 278; names start near x 296; selector values end near x 733 |
| Selected sidebar item | approximately x 4–215, y 196–232, rounded; icon at x 26, text starts near x 44 |
| All visibility menu | approximately x 664–772, y 108–185, with two vertically stacked choices and a soft shadow |

These are approximate visual bounds; rounded corners and shadows have antialiased edges. The group gaps are about 14–15 px, and the first group's row pitch is about 40 px in this capture. The selector's active option is blue with a right-side checkmark. Pointer hover adds a rounded pale-gray background to the selector.

## Sampled raster colors

Samples are single decoded JPEG pixels, so compression and antialiasing can shift them. They are evidence of the captured appearance, not exact design tokens.

| Surface / point | RGB sample | Approximate hex |
| --- | --- | --- |
| Main white background at (230, 300) | 255, 255, 255 | `#ffffff` |
| Sidebar background at (100, 300) | 248, 248, 248 | `#f8f8f8` |
| Selected sidebar fill at (180, 215) | 239, 239, 239 | `#efefef` |
| Group fill at (350, 100) | 250, 250, 250 | `#fafafa` |
| Divider at (219, 300) | 238, 238, 238 | `#eeeeee` |
| Enabled Time Zone switch blue at (733, 264) in Date & Time capture | 72, 110, 255 | `#486eff` |

The enabled switch in the Date & Time capture occupied approximately x 728–753 and y 256–272, including its white circular thumb; the disabled switch above had a gray track. Do not derive an exact blue token from a compressed edge or a single sample.

## Outstanding measurement work

Capture losslessly or quantify JPEG distortion, verify display scaling and point conversion, inspect dark mode and theme variants, measure font family/weights/baselines and icons, sample normal/hover/focus/disabled/selected states, and repeat at controlled window dimensions. Measure actual split-pane limits, automatic collapse thresholds and motion durations separately. These settings-window observations do not cover the rest of the app.

## Task workspace: two window sizes

On 3 November, the Inbox was observed with the same selected task at two sizes, using the native window zoom action and then restoring the prior size. The smaller capture was **1018 × 645 px**; the zoomed capture was **1920 × 1050 px**. In both captures the navigation rail ended near x 62 and the list sidebar ended near x 273. The divider between task list and detail was near x 693 in the smaller capture and x 1201 in the zoomed capture. Thus the observed task-list widths were about 420 and 928 px, and detail widths about 325 and 719 px, respectively. The selected task remained selected; its detail title wrapped in the smaller view and fit on one line in the wider view. Row text and checkboxes remained aligned on the same horizontal row in both observed states.

These are two sample layouts, not a formula for every intermediate width. Attempts to drag a pane divider and a window edge returned Computer Use `windowNotFoundAtPosition` before any drag was performed. They provide no evidence about minimum/maximum widths, collapse thresholds or drag behavior. The prior window size was restored via the same zoom action. Capture scaling and coordinate units are not independently established, and screenshots contained private task data and were not saved into this specification.
