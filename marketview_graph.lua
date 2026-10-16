local Widget = require("ui/widget/widget")
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local data = require("marketview_data")
local GraphWidget = Widget:extend{ width = 320, height = 170 }
function GraphWidget:init()
    self.bars = {}
    self.width = math.max(80, math.floor(self.width))
    self.height = math.max(50, math.floor(self.height))
end
function GraphWidget:setData(series) self.bars = series and series.bars or {} end
local function line(bb, x0, y0, x1, y1, color)
    local dx, dy = math.abs(x1 - x0), -math.abs(y1 - y0)
    local sx, sy = x0 < x1 and 1 or -1, y0 < y1 and 1 or -1
    local err = dx + dy
    while true do
        bb:paintRect(x0, y0, 1, 1, color)
        if x0 == x1 and y0 == y1 then break end
        local e2 = 2 * err
        if e2 >= dy then err = err + dy; x0 = x0 + sx end
        if e2 <= dx then err = err + dx; y0 = y0 + sy end
    end
end
function GraphWidget:paintTo(bb, x, y)
    x, y = math.floor(x), math.floor(y)
    bb:paintRect(x, y, self.width, self.height, Blitbuffer.COLOR_WHITE)
    local points = data.plot(self.bars, self.width, self.height)
    if #points == 0 then return end
    line(bb, x + 20, y + 10, x + 20, y + self.height - 20, Blitbuffer.COLOR_GRAY)
    line(bb, x + 20, y + self.height - 20, x + self.width - 20, y + self.height - 20, Blitbuffer.COLOR_GRAY)
    for i, p in ipairs(points) do
        if i > 1 then local prev = points[i - 1]; line(bb, x + prev.x, y + prev.y, x + p.x, y + p.y, Blitbuffer.COLOR_BLACK) end
        if #points <= 30 then bb:paintRect(x + p.x - 1, y + p.y - 1, 3, 3, Blitbuffer.COLOR_BLACK) end
    end
end
function GraphWidget:getSize() return Geom:new{ w = self.width, h = self.height } end
return GraphWidget
