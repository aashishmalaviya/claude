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
input londonDST(true)  // London BST active? (UTC+1 in summer, UTC+0 in winter)
input nyDST(true)      // New York EDT active? (UTC-4 summer, UTC-5 winter)

// --- London Macros ---
input macro0233(false)  // London 02:33 AM - 03:00 AM (UTC)
input macro0403(false)  // London 04:03 AM - 04:30 AM (UTC)

// --- New York Macros ---
input macro0850(false)  // NY 08:50 AM - 09:10 AM ET
input macro0950(true)   // NY 09:50 AM - 10:10 AM ET
input macro1050(true)   // NY 10:50 AM - 11:10 AM ET
input macro1150(false)  // NY 11:50 AM - 12:10 PM ET
input macro1310(true)   // NY 01:10 PM - 01:40 PM ET
input macro1515(true)   // NY 03:15 PM - 03:45 PM ET


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
var ln1_startH(21)
if londonDST and nyDST then
    ln1_startH = 21
elseif londonDST and not nyDST then
    ln1_startH = 20
elseif not londonDST and nyDST then
    ln1_startH = 22
else
    ln1_startH = 21
end
let ln1_startM = 33
let ln1_endM   = 0   // :00 of ln1_startH+1 hour

// ET hour for London 04:03 macro start:
//   Both DST: London BST 04:03 = UTC 03:03 -> ET(DST) = 03:03-4 = prev 23:03
//   London std, NY std: UTC 04:03 -> ET = 04:03-5 = prev 23:03
//   London std, NY DST: UTC 04:03 -> ET = 04:03-4 = 00:03
//   London DST, NY std: UTC 03:03 -> ET = 03:03-5 = prev 22:03
var ln2_startH(23)
if londonDST and nyDST then
    ln2_startH = 23
elseif londonDST and not nyDST then
    ln2_startH = 22
elseif not londonDST and nyDST then
    ln2_startH = 0
else
    ln2_startH = 23
end
let ln2_startM = 3
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
        if high > mH1 then
            mH1 = high
        end
        if low < mL1 then
            mL1 = low
        end
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
        if high > mH2 then
            mH2 = high
        end
        if low < mL2 then
            mL2 = low
        end
        if hour == ln2_startH and minute >= ln2_endM then
            mA2 = false
        end
        if hour > ln2_startH and ln2_startH != 23 then
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
        if high > mH3 then
            mH3 = high
        end
        if low < mL3 then
            mL3 = low
        end
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
        if high > mH4 then
            mH4 = high
        end
        if low < mL4 then
            mL4 = low
        end
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
        if high > mH5 then
            mH5 = high
        end
        if low < mL5 then
            mL5 = low
        end
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
        if high > mH6 then
            mH6 = high
        end
        if low < mL6 then
            mL6 = low
        end
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
        if high > mH7 then
            mH7 = high
        end
        if low < mL7 then
            mL7 = low
        end
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
        if high > mH8 then
            mH8 = high
        end
        if low < mL8 then
            mL8 = low
        end
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
let prevAny = mA1[1] or mA2[1] or mA3[1] or mA4[1] or mA5[1] or mA6[1] or mA7[1] or mA8[1]

// Pick the active macro's high/low (first active macro wins)
var activeHigh(0)
var activeLow(0)
if mA1 then
    activeHigh = mH1
    activeLow  = mL1
elseif mA2 then
    activeHigh = mH2
    activeLow  = mL2
elseif mA3 then
    activeHigh = mH3
    activeLow  = mL3
elseif mA4 then
    activeHigh = mH4
    activeLow  = mL4
elseif mA5 then
    activeHigh = mH5
    activeLow  = mL5
elseif mA6 then
    activeHigh = mH6
    activeLow  = mL6
elseif mA7 then
    activeHigh = mH7
    activeLow  = mL7
elseif mA8 then
    activeHigh = mH8
    activeLow  = mL8
else
    activeHigh = 0
    activeLow  = 0
end

let activeMid = (activeHigh + activeLow) / 2

// Transition flags
let macroJustStarted = anyMacro and not prevAny
let macroJustEnded   = not anyMacro and prevAny


// =============================================================================
// PLOT VALUES  (pre-compute to avoid ternary inside plot() calls)
// =============================================================================
var pTop(0)
var pMid(0)
var pBot(0)
var pStart(0)
var pEnd(0)
var pInMacro(0)

if anyMacro then
    pTop     = activeHigh
    pMid     = activeMid
    pBot     = activeLow
    pInMacro = 1
else
    pTop     = 0
    pMid     = 0
    pBot     = 0
    pInMacro = 0
end

if macroJustStarted then
    pStart = low
else
    pStart = 0
end

if macroJustEnded then
    pEnd = high
else
    pEnd = 0
end


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
plot1(pTop, "Macro Top", Blue)

[PlotStyle(2, dashes, 1)]
plot2(pMid, "Macro Mid", DarkGray)

[PlotStyle(3, line, 2)]
plot3(pBot, "Macro Bottom", Blue)

[PlotStyle(4, triangleUp, 4)]
plot4(pStart, "Macro Start", Green)

[PlotStyle(5, triangleDown, 4)]
plot5(pEnd, "Macro End", Red)

[PlotStyle(6, histogram, 2)]
[PlotSubchart(6, 1)]
plot6(pInMacro, "In Macro", RGB(100, 149, 237))
