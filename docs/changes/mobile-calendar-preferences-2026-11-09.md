# Mobile Calendar preferences

The phone uses the shared Calendar settings and source-selection rules. Mode changes save locally. Filters and View Options stage edits until Done. Cancel and unchanged Done leave the saved bytes alone. Time Zone Settings stages up to four named, ordered rulers within View Options. A secondary ruler changes display only.

A preference transaction owns only the Calendar options object in the app-container settings file. It verifies the saved revision and supported fields before atomic replacement. Older settings with missing Calendar keys retain their decoded defaults. Unsupported Calendar values block replacement. The workspace and unrelated settings bytes stay intact.

Apply the supported visibility, color, style, Year, range and zone preferences to the existing seven Calendar views. Keep projected items read-only, and defer external Calendar integrations. Verify the settings and workspace independently after relaunch.
