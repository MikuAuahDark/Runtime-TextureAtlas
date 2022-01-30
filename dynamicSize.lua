-- Copyright (c) 2021 EngineerSmith
-- Under the MIT license, see license suppiled with this file
local path = select(1, ...):match("(.-)[^%.]+$")
local util = require(path .. "util")
local baseAtlas = require(path .. "baseAtlas")
local dynamicSizeTA = setmetatable({}, baseAtlas)
dynamicSizeTA.__index = dynamicSizeTA

-- Custom algorithm, see the file for more information
local grid = require(path .. "packing")
local treeNode = require(path .. "treeNode")

local lg = love.graphics
local newImageData = love.image.newImageData
local sort = table.sort

local algoList = {
  grid = grid,
  tree = treeNode
}

dynamicSizeTA.new = function(padding, extrude, spacing, algorithm)
  local t = setmetatable(baseAtlas.new(padding, extrude, spacing), dynamicSizeTA)
  t.algorithm = assert(algoList[algorithm or "grid"], "invalid algorithm")
  return t
end

local area = function(a, b)
  local aW, aH = util.getImageDimensions(a.image)
  local bW, bH = util.getImageDimensions(b.image)
  return aW * aH > bW * bH
end

local height = function(a, b)
  local aH = select(2, util.getImageDimensions(a.image))
  local bH = select(2, util.getImageDimensions(b.image))
  return aH > bH
end

local width = function(a, b)
  local aW = util.getImageDimensions(a.image)
  local bW = util.getImageDimensions(b.image)
  return aW > bW
end

-- sortBy options: "height"(default), "area", "width", "none"
dynamicSizeTA.bake = function(self, sortBy)
  if self._dirty and not self._hardBake then
    local shallowCopy = {unpack(self.images)}
    if sortBy == "height" then
      sort(shallowCopy, height)
    elseif sortBy == "area" or sortBy == nil then
      sort(shallowCopy, area)
    elseif sortBy == "width" then
      sort(shallowCopy, width)
    end

    -- Calculate positions and size of canvas
    local maxWidth, maxHeight = 0, 0
    local packer = self.algorithm.new(self.maxWidth or self._maxCanvasSize, self.maxHeight or self._maxCanvasSize)

    for _, image in ipairs(shallowCopy) do
      local img = image.image
      local width, height = util.getImageDimensions(img)
      width = width + self.spacing + self.extrude * 2 + self.padding * 2
      height = height + self.spacing + self.extrude * 2 + self.padding * 2
      local node = packer:insert(width, height, image) -- will always be successful or will error
      if self.algorithm == treeNode then
        if node then
          if node.x + width > maxWidth then
            maxWidth = node.x + width
          end
          if node.y + height > maxHeight then
            maxHeight = node.y + height
          end
        else
          error("Could not fit image inside tree. Image ID: "..image.id)
        end
      end
    end

    if self.algorithm == grid then
      maxWidth, maxHeight = packer.currentWidth - self.spacing, packer.currentHeight - self.spacing
    end

    if self.bakeAsPow2 then
      maxWidth = math.pow(2, math.ceil(math.log(maxWidth)/math.log(2)))
      maxHeight = math.pow(2, math.ceil(math.log(maxHeight)/math.log(2)))
    end

    local data
    if self._pureImageMode then
      data = newImageData(maxWidth, maxHeight, "rgba8")
      packer:draw(self.quads, maxWidth, maxHeight, self.extrude, self.padding, data)
      self.image = data
    else
      local canvas = lg.newCanvas(maxWidth, maxHeight, self._canvasSettings)
      lg.push("all")
      lg.setBlendMode("replace")
      lg.setCanvas(canvas)
      packer:draw(self.quads, maxWidth, maxHeight, self.extrude, self.padding)
      lg.pop()
      data = canvas:newImageData()
      self.image = lg.newImage(data)
      self.image:setFilter(self.filterMin, self.filterMag)
    end

    self._dirty = false
    return self, data
  end

  return self
end

return dynamicSizeTA
