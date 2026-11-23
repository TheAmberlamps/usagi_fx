local tween = require "tween"
local dandelion = require "dandelion"
local gameW = usagi.GAME_W
local gameH = usagi.GAME_H
print("GAME_W: " .. gameW)
print("GAME_H: " .. gameH)
local drops = {currDrops = 1 , maxDrops = 50}
local dropsTween = tween.new(10, drops, {currDrops = drops.maxDrops}, 'inCubic')
local barsOffset = {x = 0}
local barsTween = nil --tween.new(2, barsOffset, {x = gameW * 2}, 'linear')

function _init()
  -- Live reload preserves globals across saved edits but resets locals.
  -- Stash mutable game state in a capitalized global like `State` so it
  -- survives reloads; F5 calls _init again to reset.
  State = {
    raindrops = {},
    droplets = {},
    snowflakes = {},
    flakeNum = {currFlakes = 1, maxFlakes = 75},
    flakesTween = nil,
    raining = true,
    snowing = false
  }
  State.flakesTween = tween.new(10, State.flakeNum, {currFlakes = State.flakeNum.maxFlakes}, 'inCubic')
end

function Rain(dt)
  -- use an easing function to go from a handful of drops to proper rainfall
  while #State.raindrops < drops.currDrops do
    -- 95 is an offset to make sure the rain spawns in from offscreen properly
    -- well, "properly"... if I change xE and alter the angle the rain comes down at, this would need to be changed to account for that
    local startPoint = math.random(gameW + 95)
    -- OK... step 1: Use math.atan2 to describe the line and get an angle
    -- atan2 is deprecated, just use atan
    -- step 2: Use usagi.vec_from_angle to get a vector as an {x, y}
    -- step 3: Run it through math.atan to get a velocity
    -- step 4: Move raindrop using velocity
    -- step 5: Change to a splash when raindrop reaches a certain point
    -- step 6: Remove raindrop when splash animation is complete
    local raindrop = {
      xS = startPoint,
      yS = -10,
      xE = startPoint - 5,
      yE = 0,
      rad = 5,
      splashPoint = math.random(gameH + 10),
      splashing = false
    }
    local step1 = math.atan(raindrop.yS - raindrop.yE, raindrop.xS - raindrop.xE)
    local getVec = util.vec_from_angle(step1, 150)
    raindrop.vel = getVec
    table.insert(State.raindrops, raindrop)
  end
  function Splash(x, y, num)
    for i=1, num do
      local droplet = {
        x = x,
        y = y,
        xVel = math.random(-1, 1),
        yVel = -math.random(3, 5),
        grav = 0.1
      }
      table.insert(State.droplets, droplet)
    end
  end
  for i=1, #State.raindrops do
    local drop = State.raindrops[i]
    if drop.yE <= drop.splashPoint then
      drop.xS -= drop.vel.x * dt
      drop.yS -= drop.vel.y * dt
      drop.xE -= drop.vel.x * dt
      drop.yE -= drop.vel.y * dt
      gfx.line(drop.xS, drop.yS, drop.xE, drop.yE, gfx.COLOR_TRUE_WHITE)
    elseif drop.splashing == true then
      -- run the tween update here, when 'true' flag for removal
      local splash = drop.tween:update(dt)
      gfx.circ(drop.xE, drop.yE, drop.currRad, gfx.COLOR_TRUE_WHITE, drop.alpha)
      --dandelion.Spawn("new_splash", drop.xE, drop.yE)
      if splash == true then
        drop.remove = true
      end
    else
      gfx.circ(drop.xE, drop.yE, drop.rad, gfx.COLOR_TRUE_WHITE)
      Splash(drop.xE, drop.yE, 5)
      drop.splashing = true
      drop.currRad = 1
      drop.alpha = 1
      drop.tween = tween.new(0.5, drop, {currRad = drop.rad, alpha = 0}, 'linear')
      -- insert an easing function into the raindrop here to handle splash animation
    end
  end
  print(#State.droplets)
  for i=1, #State.droplets do
    local drop = State.droplets[i]
    drop.x += drop.xVel
    drop.y += drop.yVel
    drop.yVel += drop.grav
    gfx.px(drop.x, drop.y, gfx.COLOR_TRUE_WHITE, 1)
  end
  for i=#State.raindrops, 1, -1 do
    -- ok, working like a charm; once the splashing tween is implemented, change this to check for the removal flag
    if State.raindrops[i].remove == true then
      table.remove(State.raindrops, i)
    end
  end
end

function Snow(dir, dur, dt)
  local dir = dir
  local dur = dur
  local driftVal = {-15, 15}
  if dir == 'l' then
    driftVal = {-15, -5}
  elseif dir == 'r' then
    driftVal = {5, 15}
  end
  -- linear seems to be the way to go here
  local tweenTypes = {'linear'}
  while #State.snowflakes < State.flakeNum.currFlakes do
    local startPoint = math.random(gameW)
    if dir == 'l' then
      startPoint = math.random(gameW + 50)
    elseif dir == 'r' then
      startPoint = math.random(-50, gameW)
    end
    local snowFlake = {
      x = startPoint,
      y = 0,
      endPoint = math.random(gameH + 50),
      snowTween = nil,
      alpha = 1,
      melt = false
    }
    snowFlake.snowTween = tween.new(dur, snowFlake, {x = snowFlake.x + math.random(driftVal[1], driftVal[2])}, tweenTypes[math.random(#tweenTypes)])
    table.insert(State.snowflakes, snowFlake)
  end
  for i=1, #State.snowflakes do
    local flake = State.snowflakes[i]
    if not flake.melt then
      flake.y += 1
    end
    -- hah, this won't work because flake.x is being overwritten by the tween... maybe if I run it after the update?
    -- well that 'worked' in that it did overwrite the tween positioning, but then the update runs again and it jumps back
    -- so, the solution is altering the parameters of the math.random in the tween based on the value of dir
    if flake.y >= flake.endPoint and flake.melt == false then
      flake.melt = true
      flake.snowTween = tween.new(1, flake, {alpha = 0}, 'linear')
    end
    local flakeCheck = flake.snowTween:update(dt)
    if flakeCheck == true then
      if flake.melt == true then
        flake.remove = true
      else
        flake.snowTween = tween.new(dur, flake, {x = flake.x + math.random(driftVal[1], driftVal[2])}, tweenTypes[math.random(#tweenTypes)])
      end
    end
    gfx.px(flake.x, flake.y, gfx.COLOR_TRUE_WHITE, flake.alpha)
  end
  for i=#State.snowflakes, 1, -1 do
    if State.snowflakes[i].remove == true then
      table.remove(State.snowflakes, i)
    end
  end
end

function BarsTransition(dt)
  local colour = gfx.COLOR_BLACK
  local aspectRatio = gameW / gameH
  for i=1, gameH do
    if i % 2 == 0 then
      -- right-hand side
      -- draw left-to-right
      -- 1.78 is hard-coded game width divided by game height, it should be dynamic so that it'll operate correctly if the size of the screen isn't set to the default
      -- offset all of these lines so that they start off the side of the screen
      gfx.line(gameW, i, gameW * 2 - (i * aspectRatio) - barsOffset.x, i, colour)
    else
      -- left-hand side
      -- draw right-to-left
      -- so, draw should always originate from 0, and get offset by i * offset value
      -- then use a linear tween to move across the screen
      gfx.line(0, i, -(i * aspectRatio) + barsOffset.x, i, colour)
    end
  end
end

function _update(dt)
  if input.pressed(input.BTN1) then
    if State.snowing then
      State.snowing = false
      State.flakesTween = tween.new(10, State.flakeNum, {currFlakes = 0}, 'outCubic')
    else
      State.snowing = true
      State.flakesTween = tween.new(10, State.flakeNum, {currFlakes = State.flakeNum.maxFlakes}, 'inCubic')
    end
  end
end

function _draw(dt)
  gfx.clear(gfx.COLOR_BLACK)
  gfx.text("Hello, Usagi!", 10, 10, gfx.COLOR_WHITE)
  dandelion.DrawExcept()
  if State.raining then
    dropsTween:update(dt)
    drops.currDrops = math.floor(drops.currDrops)
    Rain(dt)
  else
    State.raindrops = {}
    drops.currDrops = 1
  end
  if State.snowing or #State.snowflakes > 0 then
    State.flakesTween:update(dt)
    State.flakeNum.currFlakes = math.floor(State.flakeNum.currFlakes)
    Snow('c', 1, dt)
  end
  if barsTween ~= nil then
    BarsTransition(dt)
    local barsCheck = barsTween:update(dt)
    if barsCheck == true then
      print("alakazam!")
      if barsOffset.x == 0 then
        barsTween = nil
        return
      end
      barsTween = tween.new(2, barsOffset, {x = 0}, 'linear')
    end
  end
end