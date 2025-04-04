local Widget = require("ui/widget/widget")
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")

local GraphWidget = Widget:extend{
  width = 320,
  height = 170,
  lineColor = Blitbuffer.COLOR_BLUE,
  axisColor = Blitbuffer.COLOR_GRAY,
  labelColor = Blitbuffer.COLOR_BLACK,
  fontSize = 12,
  values = {}

}

function GraphWidget:setData(table)
  local new_values = {}
  if type(table) ~= "table" then
    error("Invalid data: expected a table")
  end
  if type(table) == "table" then
    for key, value in pairs(table) do
      -- print table from results
      if key == "results" then
        for i, result in ipairs(value) do
          for k, v in pairs(result) do
            if k == "c" then
              new_values[i] = v
            end
          end
        end
      end
    end
  GraphWidget.values = new_values
  end
end

local function drawLine(bb, x0, y0, x1, y1, color)
  local dx = math.abs(x1 - x0)
  local dy = -math.abs(y1 - y0)
  local sx = x0 < x1 and 1 or -1
  local sy = y0 < y1 and 1 or -1
  local err = dx + dy

  while true do
    bb:paintRect(x0, y0, 1, 1, color)
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2 * err
    if e2 >= dy then
      err = err + dy
      x0 = x0 + sx
    end
    if e2 <= dx then
      err = err + dx
      y0 = y0 + sy
    end
  end
end



function GraphWidget:paintTo(bb, x, y)
  local numPoints = #self.values
  if numPoints < 2 then return end

  local paddingLeft = 35
  local paddingBottom = 20
  local graphWidth = self.width - paddingLeft
  local graphHeight = self.height - paddingBottom

  local maxVal = math.max(table.unpack(self.values))
  local minVal = math.min(table.unpack(self.values))
  local range = maxVal - minVal
  if range == 0 then range = 1 end

  local stepX = graphWidth / (numPoints - 1)

  -- Draw Y axis
  drawLine(bb, x + paddingLeft, y, x + paddingLeft, y + graphHeight, self.axisColor)

  -- Draw X axis
  drawLine(bb, x + paddingLeft, y + graphHeight, x + paddingLeft + graphWidth, y + graphHeight, self.axisColor)

  -- Y Axis Ticks & Labels (e.g. 5 labels)
  local numTicks = 5
  for i = 0, numTicks do
    local tickVal = minVal + (range * i / numTicks)
    local tickY = y + graphHeight - math.floor((tickVal - minVal) / range * graphHeight)
    drawLine(bb, x + paddingLeft - 3, tickY, x + paddingLeft, tickY, self.axisColor)
  end

  -- X Axis Ticks (simple evenly spaced, no date logic for now)
  local xStep = math.floor(numPoints / 4)
  for i = 1, numPoints, xStep do
    local xTick = x + paddingLeft + math.floor((i - 1) * stepX)
    drawLine(bb, xTick, y + graphHeight, xTick, y + graphHeight + 3, self.axisColor)
  end
  -- Plot Line
  for i = 1, numPoints - 1 do
    local x1 = math.floor(x + paddingLeft + (i - 1) * stepX)
    local y1 = math.floor(y + graphHeight - ((self.values[i] - minVal) / range) * graphHeight)
    local x2 = math.floor(x + paddingLeft + i * stepX)
    local y2 = math.floor(y + graphHeight - ((self.values[i + 1] - minVal) / range) * graphHeight)

    drawLine(bb, x1, y1, x2, y2, self.lineColor)
  end
end

function GraphWidget:getSize()
  return Geom:new{ w = self.width + 20, h = self.height }
end

return GraphWidget
