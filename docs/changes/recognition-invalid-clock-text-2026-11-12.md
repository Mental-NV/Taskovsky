# Preserve rejected clock text during date recognition

## Reproduced defect

The shared recognizer consumes a trailing clock before validating it. Invalid values such as tomorrow at 25:00 return an all-day date but a highlight/removal range covering the rejected clock. With Remove date text enabled, capture silently discards that text. Four invalid-hour/minute cases reproduced eight failing range/title assertions.

## Bounded correction

Only include a trailing clock in the recognized range when it produces a valid timed date. Otherwise keep the recognized civil-date phrase but leave the clock literal in the title. Avoid partial consumption of malformed numeric clock suffixes. Preserve valid 12/24-hour forms, recognized date arithmetic, reminder/duration defaults and the valid preceding-clock path. A valid preceding clock may still supply the time, without consuming a rejected trailing clock. No general natural-language parser rewrite or TickTick parity claim.

The shared TaskCreation recognizer serves Mac preview/capture and iPhone TaskCaptureInput. Platform views remain separate; title whitespace outside the recognized span is not normalized beyond existing trimming.

## Verification

Range/title regression, malformed clocks, preceding-clock handling, valid 12/24-hour controls, removal disabled, mobile input construction, full tests and Mac/iPhone build. Native Mac preview/capture of one invalid clock should visibly retain it and persist an all-day date. Independent review and exact-head CI before merge.
