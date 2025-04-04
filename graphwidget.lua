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
  values = {185.64, 184.25, 181.91, 181.18, 185.56, 185.14, 186.19, 185.59, 185.92, 183.63, 182.68, 188.63, 191.56, 193.89, 195.18, 194.5, 194.17, 192.42, 191.73, 188.04, 184.4, 186.86, 185.85, 187.68, 189.3, 189.41, 188.32, 188.85, 187.15, 185.04, 184.15, 183.86, 182.31, 181.56, 182.32, 184.37, 182.52, 181.16, 182.63, 181.42, 180.75, 179.66, 175.1, 170.12, 169.12, 169, 170.73, 172.75, 173.23, 171.13, 173, 172.62, 173.72, 176.08, 178.67, 171.37, 172.28, 170.85, 169.71, 173.31, 171.48, 170.03, 168.84, 169.65, 168.82, 169.58, 168.45, 169.67, 167.78, 175.04, 176.55, 172.69, 169.38, 168, 167.04, 165, 165.84, 166.9, 169.02, 169.89, 169.3, 173.5}, -- expects an array of numbers

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
