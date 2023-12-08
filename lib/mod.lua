-- mod to combine multiple Grids into a single virtual Grid
-- https://github.com/dstroud/combiner

-- todo ideas:
-- flip key/led on axis (left/right hand mode)
-- level remapping

local mod = require 'core/mods'
local filepath = "/home/we/dust/data/combiner/"
combiner = {}     -- TODO LOCAL!
combiner.version = 0.2  -- TODO UPDATE
dlookup = {} -- lookup grid.devices id
local menu_pos = 1
local editing = 1 -- which index in dlookup is being edited
local snap_quantum = 16
vgrid = grid.connect(1)  -- Virtual Grid -- saves having to set path for setting functions
port = {}  -- local!
settings = {}  -- local
led_routing = {}  -- routing table for virtual>>physical Grids
local glyphs = {"arrow"}
glyphs.arrow = {
  {3,1}, {4,1},
  {2,2}, {3,2}, {4,2}, {5,2}, 
  {1,3}, {2,3}, {3,3}, {4,3}, {5,3}, {6,3}, 
  {3,4}, {4,4}, 
  {3,5}, {4,5}, 
  {3,6}, {4,6}, 
}

local settings_keys = { "x", "y", "rot", "lvl"}
settings_def = {
  x = {min = -63, max = 63, quantum = 4},
  y = {min = -63, max = 63, quantum = 4},
  rot = {min = 0, max = 3, quantum = 3},
  lvl = {min = 1, max = 15, quantum = 1}
}


local function read_prefs()
  local prefs = {}
  if util.file_exists(filepath.."prefs.data") then
    prefs = tab.load(filepath.."prefs.data")
    print('table >> read: ' .. filepath.."prefs.data")
    if (prefs.version or 0) >= 0.2 then -- TODO adjust for breaking changes
      -- combiner.rotation_1 = prefs.rotation_1
      -- combiner.rotation_2 = prefs.rotation_2
      -- combiner.intensity_1 = prefs.intensity_1
      -- combiner.intensity_2 = prefs.intensity_2
      -- port[3]:rotation(combiner.rotation_1)
      -- port[4]:rotation(combiner.rotation_2)
      -- port[3]:intensity(combiner.intensity_1)
      -- port[4]:intensity(combiner.intensity_2)
    end
  end
end


local function write_prefs(from)
  local prefs = {}
  if util.file_exists(filepath) == false then
    util.make_dir(filepath)
  end
  prefs.version = combiner.version
  -- prefs.rotation_1 = combiner.rotation_1
  -- prefs.rotation_2 = combiner.rotation_2
  -- prefs.intensity_1 = combiner.intensity_1
  -- prefs.intensity_2 = combiner.intensity_2
  tab.save(prefs, filepath .. "prefs.data")
  print("table >> write: " .. filepath.."prefs.data")
end


-- todo use this for glyph, too probably
function rotate_pairs(coordinates, cols, rows, rotation)  -- todo local
  local x, y = coordinates[1], coordinates[2]

  for r = 1, rotation do
    local rows = (r % 2 == 0) and cols or rows -- flip 'em
    x, y = rows + 1 - y, x -- 90-degree rotation CW
  end

  return x, y
end


-- define new key input handlers directly on devices, bypassing vports
local function define_handlers()
  for k, v in pairs(grid.devices) do
    v.key = function(x, y, s)
      local settings = settings[k]
      local x, y = rotate_pairs({x, y}, v.cols, v.rows, (settings.rot * 3) % 4)
      local y = y + settings.y - combiner.y_min
      local x = x + settings.x - combiner.x_min
      vgrid.key(x, y, s)
    end
  end
end


-- determines overall dimensions for virtual grid
local function calc_dimensions()
  local x_min = nil -- x origin of virtual grid
  local y_min = nil -- y origin of virtual grid
  local x_max = nil -- x max of virtual grid
  local y_max = nil -- y max of virtual grid
    
  for i = 1, #dlookup do -- todo test with 0 configured. Also need enabled/disabled
    local device = grid.devices[dlookup[i]]
    local settings = settings[dlookup[i]]
    local rotation = settings.rot
    local swap = (rotation % 2) ~= 0
    local cols = swap and device.rows or device.cols 
    local rows = swap and device.cols or device.rows
    local x = settings.x
    local y = settings.y
    
    local x = cols + settings.x
    if x >= (x_max or x) then
      x_max = x
    end
    local x = settings.x
    if x <= (x_min or x) then
      x_min = x
    end
    combiner.cols = x_max - x_min
    combiner.x_min = x_min
    
    local y = rows + settings.y
    if y >= (y_max or y) then 
      y_max = y
    end
    local y = settings.y
    if y <= (y_min or y) then
      y_min = y
    end
    combiner.rows = y_max - y_min
    combiner.y_min = y_min
  end 
  
  vgrid.cols = combiner.cols
  vgrid.rows = combiner.rows
  print("Combiner: " .. combiner.cols .. "x" .. combiner.rows .. " virtual Grid configured")
  
  -- generate led_routing to translate from virtual to physical grids
  led_routing = {}
  for x = 1, vgrid.cols do
    led_routing[x] = {}
    for y = 1, vgrid.rows do
      led_routing[x][y] = {}
    end
  end
  
  for i = 1, #dlookup do -- todo test with 0 configured. Also need enabled/disabled devices
    local id = dlookup[i]
    local device = grid.devices[id]
    local settings = settings[id]
    local x_offset = settings.x
    local y_offset = settings.y
    local rotation = settings.rot
    local swap = (rotation % 2) ~= 0
    local cols = swap and device.rows or device.cols 
    local rows = swap and device.cols or device.rows
    
    for x_real = 1, cols do
      for y_real = 1, rows do
        local x_virtual = x_real + x_offset - x_min
        local y_virtual = y_real + y_offset - y_min
        local x_real, y_real = rotate_pairs({x_real, y_real}, cols, rows, rotation)
        table.insert(led_routing[x_virtual][y_virtual], {id, x_real, y_real})
      end
    end

  end
end


-- device-id indexed
-- todo at some point we'll likely need to store and retrieve settings values based on device name (with serial #)
local function gen_dev_tables()
  dlookup = {}
  for k, v in pairs(grid.devices) do
    local min_dim = math.min(v.cols, v.rows)
    snap_quantum = min_dim < snap_quantum and min_dim or snap_quantum
    table.insert(dlookup, k)
    settings[k] = {}
    settings[k] = {x = 0, y = 0, rot = 0, lvl = 15}
  end  
end


-- called when grids are plugged/unplugged, grid vports are changed, and once at startup after system hook
-- todo think about what we actually want here vs elsewhere now that we're not using vports
local function init_virtual()

  calc_dimensions() -- check if needed here
  
  vgrid.name = "virtual"
  vgrid.rows = combiner.rows
  vgrid.cols = combiner.cols
  vgrid.device = {
    id = 1,
    port = 1,
    name = "virtual",
    serial = "V0000001",
    -- dev = NA, @tparam userdata dev : opaque pointer to device.
    cols = combiner.cols,
    rows = combiner.rows,
  }

  -- todo optimize
  function vgrid:led(x, y, val)
    local routing = led_routing[x][y]
    for i = 1, #routing do
      _norns.grid_set_led(grid.devices[routing[i][1]].dev, routing[i][2], routing[i][3], val)
    end
  end

  -- todo dynamic grid qty handling
  function vgrid:all(val)
    _norns.grid_all_led(grid.devices[dlookup[1]].dev, val)
    _norns.grid_all_led(grid.devices[dlookup[2]].dev, val)
  end

  function vgrid:refresh()
    _norns.monome_refresh(grid.devices[dlookup[1]].dev)
    _norns.monome_refresh(grid.devices[dlookup[2]].dev)
  end

  function vgrid:rotation()
    -- supported through mod menu
  end

  function vgrid:intensity()
    -- supported through mod menu
  end
  
  function vgrid:tilt_enable()
  end

  function vgrid:add()    -- unsure
  end

  function vgrid:remove() -- unsure
  end
  
end


function highlight_grid(id)
  for k, v in pairs(grid.devices) do
    local dev = v.dev
    _norns.grid_all_led(dev, 0)
    if k == id then
      for x = 1, v.cols do
        for y = 1, v.rows do
          _norns.grid_set_led(dev, x, y, 1)
        end
      end
    end
  _norns.monome_refresh(dev)
  end
end


-- todo need to think about how to handle grid-settings mod. Disable?
mod.hook.register("system_post_startup", "combiner post startup", function()
  
  -- due to update_devices() overwriting vports after mod hook, redefine it
  local old_update_devices = grid.update_devices
  function grid.update_devices()
    -- print("REDEFINED GRID.UPDATE_DEVICES CALLED")
    old_update_devices()
    gen_dev_tables()   -- update dlookup, will probably be used to lookup name/serial and port
    init_virtual()    -- generate virtual interface
    read_prefs()      -- load prefs
  end
  
end)


-- requires norns 231114
mod.hook.register("script_post_init", "combiner post init", function()
  define_handlers()
end)


-- system mod menu for settings
local m = {}

function m.key(n, z)
  if z == 1 then
    if n == 2 then
      mod.menu.exit()
    end
  end
end

function intensity(id, val)
  _norns.monome_intensity(grid.devices[id].dev, val)
end


-- todo look into settings being baseed on device id rather than 1-indexed
function m.enc(n, d)
  if n == 2 then
    local d = util.clamp(d, -1, 1)
    menu_pos = util.clamp(menu_pos + d, 1, 5)
  elseif n == 3 then
    if menu_pos == 1 then
      editing = util.clamp(editing + d, 1, #dlookup) -- 1-index, (not device id)
      highlight_grid(dlookup[editing])
    else
      local id = dlookup[editing]
      local key = settings_keys[menu_pos - 1]
      if key == "x" or key == "y" then
        d = util.clamp(d, -1, 1) * snap_quantum -- todo not sure this feels good
        settings[id][key] = math.max(settings[id][key] + d, 0)
        calc_dimensions()
      elseif key == "rot" then
        local d = util.clamp(d, -1, 1) * 3
        local new_rot = (settings[id][key] + d) % 4
        settings[id][key] = new_rot
        calc_dimensions()
      elseif key == "lvl" then
        local d = util.clamp(d, -1, 1)
        settings[id][key] = util.clamp(settings[id][key] + d, 0, 15)
        intensity(id, settings[id][key])
      end
    end
  end
  m.redraw()
end


function m.redraw()
  screen.clear()
  screen.blend_mode(2)
  local pos = 1

  local index = 1
  local device = grid.devices[dlookup[editing]]
  local serial = device.serial or ("Grid id " .. dlookup[editing])
  local name = device.cols .. "x" .. device.rows
  screen.level(menu_pos == index and 15 or 4)
  screen.move(86, 10)
  screen.text(serial)
  screen.move(86, 20)
  screen.text(name)

  index = 2
  for _, v in ipairs(settings_keys) do
    screen.level(menu_pos == index and 15 or 4)
    screen.move(86, (index + 1) * 10)
    screen.text(v)
    screen.move(127, (index + 1) * 10)
    screen.text_right(settings[dlookup[editing]][v] * (v == "rot" and 90 or 1))
    index = index + 1
  end
  
  screen.level(2)
  screen.move(81,5)
  screen.line(81,60)
  screen.stroke()
  
  -- draw tiny Grids!
  for i = 1, #dlookup do  -- todo only configured/enabled
    screen.level(editing == i and 5 or 2)
    local device = grid.devices[dlookup[i]]

    local settings = settings[dlookup[i]]
    local rotation = (settings.rot * 3) % 4 -- god I hate this
    local rotated = (rotation % 2) ~= 0

    local cols = rotated and device.rows or device.cols 
    local rows = rotated and device.cols or device.rows
    
    local x = settings.x
    local y = settings.y
    
    screen.rect(x, y, cols, rows)
    screen.fill()

    -- direction arrows
    if cols >= 8 and rows >= 8 then -- allow smaller than 8x8 but no arrows
      screen.level(15)
      for i = 1, #glyphs.arrow do
        local pixel_x, pixel_y = rotate_pairs({glyphs.arrow[i][1], glyphs.arrow[i][2]}, 6, 6, rotation)
        screen.pixel(pixel_x + x + (cols / 2) - 4, pixel_y + y + (rows / 2) - 4)
      end
      screen.fill()
    end
    
  end
  
  screen.update()
end


function m.init() -- on menu entry
  highlight_grid(dlookup[1])
end


function m.deinit() -- on menu exit
  write_prefs()
end


mod.menu.register(mod.this_name, m)