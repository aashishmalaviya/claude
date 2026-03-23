// =============================================================================
// Fair Value Gap (FVG) - WealthScript
// =============================================================================
// Based on LuxAlgo Fair Value Gap [Pine Script v5]
// Converted for WealthCharts WealthScript
//
// WHAT THIS DOES:
//   Detects Fair Value Gaps (FVGs) - 3-candle price imbalance patterns:
//     Bullish FVG : low[0] > high[2]  AND  close[1] > high[2]
//     Bearish FVG : high[0] < low[2]  AND  close[1] < low[2]
//   Tracks the most recently active FVG in each direction.
//   In Dynamic mode the FVG boundary compresses as price fills the gap.
//   Detects mitigation when price closes through the FVG.
//
// PLOTS:
//   1-2 : Bullish FVG band  (hbands, green)
//   3-4 : Bearish FVG band  (hbands, red)
//   5   : Bullish FVG detected  (triangle up,   green, at middle-bar low)
//   6   : Bearish FVG detected  (triangle down, red,   at middle-bar high)
//   7   : Bullish FVG mitigated (triangle down, green, optional)
//   8   : Bearish FVG mitigated (triangle up,   red,   optional)
//   9   : Bull count  (histogram, subchart)
//  10   : Bear count  (histogram, subchart)
//
// LIMITATIONS vs Pine Script version:
//   - Tracks only ONE active FVG per direction (no historical array)
//   - No individual boxes drawn per FVG (no drawing objects API)
//   - No "Unmitigated Levels" for N last FVGs
//   - No multi-timeframe mode  (no request.security in WealthScript)
//   - No statistics dashboard  (no table drawing API)
//   - No alert conditions
// =============================================================================


// =============================================================================
// INPUTS
// =============================================================================
input threshPct(0)          // Threshold % - minimum gap size (0 = all)
input autoThresh(false)     // Auto threshold (avg body-range based)
input dynamicMode(false)    // Compress FVG boundary as price fills gap
input showMitigation(false) // Show marker when FVG is mitigated


// =============================================================================
// AUTO THRESHOLD  (cumulative avg of (high-low)/low)
// =============================================================================
var cumRng(0)
var barCnt(0)
var thresh(0)

barCnt = barCnt + 1
cumRng = cumRng + (high - low) / low

if autoThresh then
    thresh = cumRng / barCnt
else
    thresh = threshPct / 100
end


// =============================================================================
// FVG DETECTION
// =============================================================================
// Bullish: gap between current candle's low and 2-bars-ago high
let bullGap   = low - high[2]
let isBullRaw = low > high[2] and close[1] > high[2]
let isBull    = isBullRaw and (bullGap / high[2]) > thresh

// Bearish: gap between 2-bars-ago low and current candle's high
let bearGap   = low[2] - high
let isBearRaw = high < low[2] and close[1] < low[2]
let isBear    = isBearRaw and (bearGap / high) > thresh


// =============================================================================
// STATE VARIABLES  (most recent active FVG per direction)
// =============================================================================
var bullMax(0)      // Bull FVG upper boundary
var bullMin(0)      // Bull FVG lower boundary
var bullOn(false)   // Bull FVG currently unmitigated

var bearMax(0)      // Bear FVG upper boundary
var bearMin(0)      // Bear FVG lower boundary
var bearOn(false)   // Bear FVG currently unmitigated

var bullCnt(0)      // Total bullish FVGs detected
var bearCnt(0)      // Total bearish FVGs detected
var bullMit(0)      // Total bullish FVGs mitigated
var bearMit(0)      // Total bearish FVGs mitigated


// =============================================================================
// BULL FVG LOGIC
// =============================================================================
// New bull FVG detected - record its boundaries
if isBull then
    bullMax = low       // top of gap = current bar low
    bullMin = high[2]   // bottom of gap = 2 bars ago high
    bullOn  = true
    bullCnt = bullCnt + 1
end

// Dynamic mode: compress top boundary toward bottom as price fills the gap
// Pine Script: max_bull_fvg = math.max(math.min(close, max), min)
if dynamicMode and bullOn and not isBull then
    if close < bullMax then
        if close > bullMin then
            bullMax = close
        else
            bullMax = bullMin
        end
    end
end

// Mitigation: price closes below the FVG bottom -> gap invalidated
if bullOn and not isBull and close < bullMin then
    bullOn  = false
    bullMit = bullMit + 1
end


// =============================================================================
// BEAR FVG LOGIC
// =============================================================================
// New bear FVG detected - record its boundaries
if isBear then
    bearMax = low[2]    // top of gap = 2 bars ago low
    bearMin = high      // bottom of gap = current bar high
    bearOn  = true
    bearCnt = bearCnt + 1
end

// Dynamic mode: compress bottom boundary upward as price fills the gap
// Pine Script: min_bear_fvg = math.min(math.max(close, min), max)
if dynamicMode and bearOn and not isBear then
    if close > bearMin then
        if close < bearMax then
            bearMin = close
        else
            bearMin = bearMax
        end
    end
end

// Mitigation: price closes above the FVG top -> gap invalidated
if bearOn and not isBear and close > bearMax then
    bearOn  = false
    bearMit = bearMit + 1
end


// =============================================================================
// TRANSITION FLAGS  (for markers)
// =============================================================================
var prevBull(false)
var prevBear(false)
var prevBullOn(false)
var prevBearOn(false)

let newBullSignal     = isBull and not prevBull
let newBearSignal     = isBear and not prevBear
let bullJustMitigated = not bullOn and prevBullOn
let bearJustMitigated = not bearOn and prevBearOn

prevBull   = isBull
prevBear   = isBear
prevBullOn = bullOn
prevBearOn = bearOn


// =============================================================================
// PLOT VALUES  (pre-compute to avoid ternary inside plot() calls)
// =============================================================================
var p1(0)
var p2(0)
var p3(0)
var p4(0)
var p5(0)
var p6(0)
var p7(0)
var p8(0)

// Bull FVG band
if bullOn then
    p1 = bullMax
    p2 = bullMin
else
    p1 = 0
    p2 = 0
end

// Bear FVG band
if bearOn then
    p3 = bearMax
    p4 = bearMin
else
    p3 = 0
    p4 = 0
end

// Bull FVG detected marker (at middle-candle low)
if newBullSignal then
    p5 = low[1]
else
    p5 = 0
end

// Bear FVG detected marker (at middle-candle high)
if newBearSignal then
    p6 = high[1]
else
    p6 = 0
end

// Bull mitigation marker
if showMitigation and bullJustMitigated then
    p7 = high
else
    p7 = 0
end

// Bear mitigation marker
if showMitigation and bearJustMitigated then
    p8 = low
else
    p8 = 0
end


// =============================================================================
// PLOTS
// =============================================================================

// -- Bullish FVG Band --
[PlotStyle(1, hbands, 2)]
plot1(p1, "Bull FVG Top", RGB(8, 153, 129))

[PlotStyle(2, hbands, 2)]
plot2(p2, "Bull FVG Bottom", RGB(8, 153, 129))

// -- Bearish FVG Band --
[PlotStyle(3, hbands, 2)]
plot3(p3, "Bear FVG Top", RGB(242, 54, 69))

[PlotStyle(4, hbands, 2)]
plot4(p4, "Bear FVG Bottom", RGB(242, 54, 69))

// -- Bullish FVG Detected Marker --
[PlotStyle(5, triangleUp, 4)]
plot5(p5, "Bull FVG", RGB(8, 153, 129))

// -- Bearish FVG Detected Marker --
[PlotStyle(6, triangleDown, 4)]
plot6(p6, "Bear FVG", RGB(242, 54, 69))

// -- Bull Mitigation Marker --
[PlotStyle(7, triangleDown, 3)]
plot7(p7, "Bull Mitigated", RGB(8, 153, 129))

// -- Bear Mitigation Marker --
[PlotStyle(8, triangleUp, 3)]
plot8(p8, "Bear Mitigated", RGB(242, 54, 69))

// -- Count Histograms in Subchart --
[PlotStyle(9, histogram, 2)]
[PlotSubchart(9, 1)]
plot9(bullCnt, "Bull FVG Count", RGB(8, 153, 129))

[PlotStyle(10, histogram, 2)]
[PlotSubchart(10, 1)]
plot10(bearCnt, "Bear FVG Count", RGB(242, 54, 69))
