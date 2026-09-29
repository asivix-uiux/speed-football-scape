local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }

-- 2700 -> "2.7K", 1000000 -> "1M", 950 -> "950"
function Format.abbreviate(value)
    value = math.floor(value or 0)
    if value < 1000 then
        return tostring(value)
    end

    local index = 0
    local scaled = value
    while scaled >= 1000 and index < #SUFFIXES do
        scaled = scaled / 1000
        index = index + 1
    end

    local text
    if scaled >= 100 then
        text = string.format("%d", math.floor(scaled))
    else
        text = string.format("%.1f", math.floor(scaled * 10) / 10)
        text = string.gsub(text, "%.0$", "")
    end

    return text .. SUFFIXES[index]
end

-- Leaderboard style: 6700000 -> "6.7e+6"; small values use abbreviate
function Format.scientific(value)
    value = math.floor(value or 0)
    if value < 100000 then
        return Format.abbreviate(value)
    end
    local exponent = math.floor(math.log10(value))
    local mantissa = math.floor(value / 10 ^ exponent * 10) / 10
    return string.format("%.1fe+%d", mantissa, exponent)
end

function Format.clock(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

return Format
