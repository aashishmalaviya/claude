// =============================================================================
// ICT Macros - WealthScript
// =============================================================================
// Based on LuxAlgo ICT Macros (Pine Script v5)
// Converted for WealthCharts WealthScript
//
// WHAT THIS DOES:
//   Detects ICT Macro trading windows and displays:
//   - Top/Bottom/Mid lines of each macro range (live during active macro)
//   - Triangle markers at macro START (green, below bar) and END (red, above bar)
//   - Subchart histogram: 1 = in macro, 0 = not in macro
//
// LIMITATIONS vs Pine Script version:
//   WealthScript does not support dynamic drawing objects (line.new, label.new,
//   linefill.new). This version uses real-time plots that show macro range
//   only while the macro window is active. No persistent historical boxes.
//   No macro classification (Accumulation/Manipulation/Expansion) — that
//   requires lower-timeframe pivot point data unavailable in WealthScript.
//
// TIMEZONE ASSUMPTION:
//   WealthCharts uses Eastern Time (ET).
//   NY macros are native ET.
//   London macros are converted from UTC to ET (see offsets below).
//
// CHART TIMEFRAMES:  Works on 1-min, 3-min, 5-min charts.
// =============================================================================


// =============================================================================
// INPUTS
// =============================================================================

// DST Controls
input boolean londonDST(true)  // London BST active? (UTC+1 in summer, UTC+0 in winter)
input boolean nyDST(true)      // New York EDT active? (UTC-4 summer, UTC-5 winter)

// --- London Macros ---
input boolean macro0233(false)  // London 02:33 AM - 03:00 AM (UTC)
input boolean macro0403(false)  // London 04:03 AM - 04:30 AM (UTC)

// --- New York Macros ---
input boolean macro0850(false)  // NY 08:50 AM - 09:10 AM ET
input boolean macro0950(true)   // NY 09:50 AM - 10:10 AM ET
input boolean macro1050(true)   // NY 10:50 AM - 11:10 AM ET
input boolean macro1150(false)  // NY 11:50 AM - 12:10 PM ET
input boolean macro1310(true)   // NY 01:10 PM - 01:40 PM ET
input boolean macro1515(true)   // NY 03:15 PM - 03:45 PM ET


// =============================================================================
// TIMEZONE OFFSET CALCULATIONS
// =============================================================================
// London macro times are given in UTC. WealthCharts uses Eastern Time.
//
// ET offsets from UTC:
//   NY Standard (winter): UTC - 5h
//   NY DST (summer):      UTC - 4h
//
// London 02:33 UTC -> ET:
//   NY standard: 02:33 - 5 = previous evening 21:33 ET
//   NY DST:      02:33 - 4 = previous evening 22:33 ET
//   (London BST 02:33 = 01:33 UTC -> ET std: 20:33, ET DST: 21:33)
//
// London 04:03 UTC -> ET:
//   NY standard: 04:03 - 5 = previous evening 23:03 ET
//   NY DST:      04:03 - 4 = 00:03 ET (midnight)
//   (London BST 04:03 = 03:03 UTC -> ET std: 22:03, ET DST: 23:03)
//
// For simplicity, when BOTH London and NY are on DST simultaneously (common in
// spring/autumn transition gap), the effective difference is still 5h.
// Default inputs assume both on DST (summer): londonDST=true, nyDST=true.

// ET hour for London 02:33 macro start:
//   Both DST: London BST 02:33 = UTC 01:33 -> ET(DST) = 01:33-4 = prev 21:33
//   London std, NY std: UTC 02:33 -> ET = 02:33-5 = prev 21:33
//   London std, NY DST: UTC 02:33 -> ET = 02:33-4 = prev 22:33
//   London DST, NY std: UTC 01:33 -> ET = 01:33-5 = prev 20:33
let ln1_startH = (londonDST and nyDST) ? 21 : (londonDST and not nyDST ? 20 : (not londonDST and nyDST ? 22 : 21))
let ln1_startM = 33
let ln1_endH   = ln1_startH + 0   // end is 27 min later - handle via minute check
let ln1_endM   = 0   // :00 of ln1_startH+1 hour

// ET hour for London 04:03 macro start:
//   Both DST: London BST 04:03 = UTC 03:03 -> ET(DST) = 03:03-4 = prev 23:03
//   London std, NY std: UTC 04:03 -> ET = 04:03-5 = prev 23:03
//   London std, NY DST: UTC 04:03 -> ET = 04:03-4 = 00:03
//   London DST, NY std: UTC 03:03 -> ET = 03:03-5 = prev 22:03
let ln2_startH = (londonDST and nyDST) ? 23 : (londonDST and not nyDST ? 22 : (not londonDST and nyDST ? 0 : 23))
let ln2_startM = 3
let ln2_endH   = ln2_startH       // 04:30 = ln2_startH:30
let ln2_endM   = 30


// =============================================================================
// MACRO STATE VARIABLES
// =============================================================================
// mHx = running high, mLx = running low, mAx = active flag
// One set per macro window (8 total: 2 London + 6 NY)

var mH1(0), var mL1(999999), var mA1(false)   // London 02:33
var mH2(0), var mL2(999999), var mA2(false)   // London 04:03
var mH3(0), var mL3(999999), var mA3(false)   // NY 08:50
var mH4(0), var mL4(999999), var mA4(false)   // NY 09:50
var mH5(0), var mL5(999999), var mA5(false)   // NY 10:50
var mH6(0), var mL6(999999), var mA6(false)   // NY 11:50
var mH7(0), var mL7(999999), var mA7(false)   // NY 13:10
var mH8(0), var mL8(999999), var mA8(false)   // NY 15:15


// =============================================================================
// MACRO LOGIC
// =============================================================================

// ---- London 02:33 UTC (ET: ~21:33) - 03:00 UTC (ET: ~22:00) ----
if macro0233 then
    if hour == ln1_startH and minute == ln1_startM then
        mH1 = high
        mL1 = low
        mA1 = true
    end
    if mA1 then
        mH1 = high > mH1 ? high : mH1
        mL1 = low  < mL1 ? low  : mL1
        if hour == (ln1_startH + 1) then
            mA1 = false
        end
    end
end

// ---- London 04:03 UTC (ET: ~23:03/00:03) - 04:30 UTC ----
if macro0403 then
    if hour == ln2_startH and minute == ln2_startM then
        mH2 = high
        mL2 = low
        mA2 = true
    end
    if mA2 then
        mH2 = high > mH2 ? high : mH2
        mL2 = low  < mL2 ? low  : mL2
        if hour == ln2_endH and minute >= ln2_endM then
            mA2 = false
        end
        if hour > ln2_endH and ln2_endH != 23 then
            mA2 = false
        end
    end
end

// ---- NY 08:50 AM - 09:10 AM ----
if macro0850 then
    if hour == 8 and minute == 50 then
        mH3 = high
        mL3 = low
        mA3 = true
    end
    if mA3 then
        mH3 = high > mH3 ? high : mH3
        mL3 = low  < mL3 ? low  : mL3
        if hour == 9 and minute > 10 then
            mA3 = false
        end
        if hour > 9 then
            mA3 = false
        end
    end
end

// ---- NY 09:50 AM - 10:10 AM ----
if macro0950 then
    if hour == 9 and minute == 50 then
        mH4 = high
        mL4 = low
        mA4 = true
    end
    if mA4 then
        mH4 = high > mH4 ? high : mH4
        mL4 = low  < mL4 ? low  : mL4
        if hour == 10 and minute > 10 then
            mA4 = false
        end
        if hour > 10 then
            mA4 = false
        end
    end
end

// ---- NY 10:50 AM - 11:10 AM ----
if macro1050 then
    if hour == 10 and minute == 50 then
        mH5 = high
        mL5 = low
        mA5 = true
    end
    if mA5 then
        mH5 = high > mH5 ? high : mH5
        mL5 = low  < mL5 ? low  : mL5
        if hour == 11 and minute > 10 then
            mA5 = false
        end
        if hour > 11 then
            mA5 = false
        end
    end
end

// ---- NY 11:50 AM - 12:10 PM ----
if macro1150 then
    if hour == 11 and minute == 50 then
        mH6 = high
        mL6 = low
        mA6 = true
    end
    if mA6 then
        mH6 = high > mH6 ? high : mH6
        mL6 = low  < mL6 ? low  : mL6
        if hour == 12 and minute > 10 then
            mA6 = false
        end
        if hour > 12 then
            mA6 = false
        end
    end
end

// ---- NY 01:10 PM - 01:40 PM (13:10 - 13:40) ----
if macro1310 then
    if hour == 13 and minute == 10 then
        mH7 = high
        mL7 = low
        mA7 = true
    end
    if mA7 then
        mH7 = high > mH7 ? high : mH7
        mL7 = low  < mL7 ? low  : mL7
        if hour == 13 and minute > 40 then
            mA7 = false
        end
        if hour > 13 then
            mA7 = false
        end
    end
end

// ---- NY 03:15 PM - 03:45 PM (15:15 - 15:45) ----
if macro1515 then
    if hour == 15 and minute == 15 then
        mH8 = high
        mL8 = low
        mA8 = true
    end
    if mA8 then
        mH8 = high > mH8 ? high : mH8
        mL8 = low  < mL8 ? low  : mL8
        if hour == 15 and minute > 45 then
            mA8 = false
        end
        if hour > 15 then
            mA8 = false
        end
    end
end


// =============================================================================
// AGGREGATE STATE
// =============================================================================

let anyMacro = mA1 or mA2 or mA3 or mA4 or mA5 or mA6 or mA7 or mA8

// Previous bar aggregate (for transition detection)
let prevAny   = mA1[1] or mA2[1] or mA3[1] or mA4[1] or mA5[1] or mA6[1] or mA7[1] or mA8[1]

// Pick the active macro's high/low (first active macro wins)
let activeHigh = mA1 ? mH1 : (mA2 ? mH2 : (mA3 ? mH3 : (mA4 ? mH4 : (mA5 ? mH5 : (mA6 ? mH6 : (mA7 ? mH7 : (mA8 ? mH8 : 0)))))))
let activeLow  = mA1 ? mL1 : (mA2 ? mL2 : (mA3 ? mL3 : (mA4 ? mL4 : (mA5 ? mL5 : (mA6 ? mL6 : (mA7 ? mL7 : (mA8 ? mL8 : 0)))))))
let activeMid  = (activeHigh + activeLow) / 2

// Transition flags
let macroJustStarted = anyMacro and not prevAny
let macroJustEnded   = not anyMacro and prevAny


// =============================================================================
// PLOTS
// =============================================================================
// Plot 1: Macro Top   - solid line at macro high during active window
// Plot 2: Macro Mid   - dashed line at macro midpoint during active window
// Plot 3: Macro Bot   - solid line at macro low during active window
// Plot 4: Macro Start - green triangle below bar when macro starts
// Plot 5: Macro End   - red triangle above bar when macro ends
// Plot 6: In Macro    - histogram in subchart (1=in macro, 0=outside)
//
// NOTE: When not in macro, plots 1-3 output 0 which appears below the price
// chart. This is a WealthScript limitation vs Pine Script's na/suppressed lines.
// Use the subchart histogram (plot 6) as a cleaner "in macro" signal.

[PlotStyle(1, line, 2)]
plot1(anyMacro ? activeHigh : 0, "Macro Top", Blue)

[PlotStyle(2, dashes, 1)]
plot2(anyMacro ? activeMid : 0, "Macro Mid", DarkGray)

[PlotStyle(3, line, 2)]
plot3(anyMacro ? activeLow : 0, "Macro Bottom", Blue)

[PlotStyle(4, triangleUp, 4)]
plot4(macroJustStarted ? low : 0, "Macro Start", Green)

[PlotStyle(5, triangleDown, 4)]
plot5(macroJustEnded ? high : 0, "Macro End", Red)

[PlotStyle(6, histogram, 2)]
[PlotSubchart(6, 1)]
plot6(anyMacro ? 1 : 0, "In Macro", RGB(100, 149, 237))
