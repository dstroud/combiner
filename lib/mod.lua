-- mod to combine multiple Grids into a single virtual Grid
-- https://github.com/dstroud/combiner

-- TODO P0 OLD PREFS FORMAT?
-- TODO test with no grids

-- todo ideas:
-- flip grid on axis (left/right hand mode)
-- gamma/level curves
-- m-m-M-MEGAGRID
-- define virtual size and add some way of navigating via smaller grid (pmap an x/y param?)

local mod = require 'core/mods'
local filepath = "/home/we/dust/data/combiner/"
local state = "running"
local combiner = {}     -- TODO LOCAL!
combiner.version = 0.2  -- TODO UPDATE
dproperties = {} -- consolidated devices and properties, sequential
dcache = {}      -- cached configurable dproperties
local keypresses = 0
local menu_pos = 1
editing_index = 1 -- which index in dproperties is being edited
local snap_quantum = 16
vgrid = grid.connect(1)  -- Virtual Grid vport
led_routing = {}  -- routing table for virtual>>physical Grids
local glyphs = {"arrow"}
glyphs.arrow = {  -- felt cute, might delete later
                {3,1}, {4,1},
         {2,2}, {3,2}, {4,2}, {5,2}, 
  {1,3}, {2,3}, {3,3}, {4,3}, {5,3}, {6,3}, 
                {3,4}, {4,4}, 
                {3,5}, {4,5}, 
                {3,6}, {4,6}, 
}

local menu_properties = { "x", "y", "rot", "lvl"}
local menu_defs = {
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
      
      -- load cache from file
      dcache = prefs.dcache
      
      -- apply settings to matching device names
      for i = 1, #dproperties do
        for cached_name, tab in pairs(dcache) do
          if dproperties[i].name == cached_name then
            for k, v in pairs(tab) do
              dproperties[i][k] = v
            end
          end
        end
      end
  
    end
  end
end


local function write_prefs(from)
  local prefs = {}
  if util.file_exists(filepath) == false then
    util.make_dir(filepath)
  end

  prefs.version = combiner.version
  prefs.dcache = dcache

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


-- determines overall dimensions for virtual grid and generates LED routing table
local function gen_layout()
  local x_min = nil -- x origin of virtual grid
  local y_min = nil -- y origin of virtual grid
  local x_max = nil -- x max of virtual grid
  local y_max = nil -- y max of virtual grid
    
  for i = 1, #dproperties do -- todo test with 0 configured. Also need enabled/disabled
    if dproperties[i].enabled == false then
      local dproperties = dproperties[i]
      local rotation = dproperties.rot
      local swap = (rotation % 2) ~= 0
      local cols = swap and dproperties.rows or dproperties.cols
      local rows = swap and dproperties.cols or dproperties.rows
      local x_offset = dproperties.x
      local y_offset = dproperties.y
      
      local x = cols + x_offset
      if x >= (x_max or x) then
        x_max = x
      end
      local x = x_offset
      if x <= (x_min or x) then
        x_min = x
      end
      combiner.cols = x_max - x_min
      combiner.x_min = x_min
      
      local y = rows + y_offset
      if y >= (y_max or y) then 
        y_max = y
      end
      local y = y_offset
      if y <= (y_min or y) then
        y_min = y
      end
      combiner.rows = y_max - y_min
      combiner.y_min = y_min
    end
  end 
  
  -- print(combiner.cols, combiner.rows)
  
  vgrid.cols = combiner.cols
  vgrid.rows = combiner.rows
  -- print("Combiner: " .. combiner.cols .. "x" .. combiner.rows .. " virtual Grid configured")
  
  -- generate led_routing to translate from virtual to physical grids
  led_routing = {}
  for x = 1, vgrid.cols do
    led_routing[x] = {}
    for y = 1, vgrid.rows do
      led_routing[x][y] = {}
    end
  end
  
  for i = 1, #dproperties do -- todo test with 0 configured. Also need enabled/disabled devices
    local dproperties = dproperties[i]
    local x_offset = dproperties.x
    local y_offset = dproperties.y
    local rotation = dproperties.rot
    local swap = (rotation % 2) ~= 0
    local cols = swap and dproperties.rows or dproperties.cols 
    local rows = swap and dproperties.cols or dproperties.rows
    
    for x_real = 1, cols do
      for y_real = 1, rows do
        local x_virtual = x_real + x_offset - x_min
        local y_virtual = y_real + y_offset - y_min
        local x_real, y_real = rotate_pairs({x_real, y_real}, cols, rows, rotation)
        table.insert(led_routing[x_virtual][y_virtual], {dproperties.id, x_real, y_real})
      end
    end

  end
end


local function gen_dev_tables()
  dproperties = {}
  for k, v in pairs(grid.devices) do
    local min_dim = math.min(v.cols, v.rows)
    snap_quantum = min_dim < snap_quantum and min_dim or snap_quantum

    table.insert(dproperties, {})
    -- todo: duplicate name check and append id if needed (NeoTrellis)
    dproperties[#dproperties] = {
      -- todo think about whether we want to bring all this in and operate off this table or if we want to keep going back to `devices` proper
      -- main thing we need is a place for `enabled`
      
      id = v.id,
      name = v.name,
      shortname = string.sub(v.name, 1, #v.name - string.len(v.serial) - 1),
      serial = v.serial or "id_" .. v.id,
      cols = v.cols,
      rows = v.rows,
      dev = v.dev,
      description = v.cols .. "x" .. v.rows,
      port = v.port,
      
      -- defaults
      x = 0,
      y = 0,
      rot = 0,
      lvl = 15,
      enabled = false
    }
  end
end


-- set virtual grid functions
-- while in menus, suspend calls from scripts
local function grid_functions()
  
  if state == "running" then
    
    -- nil faux menu functions (necessary?)
    combiner.led = nil
    combiner.all = nil
    combiner.refresh = nil
    
   -- todo optimize
    function vgrid:led(x, y, val)
      if led_routing[x] then -- optional, in case script sends invalid coords
        local routing = led_routing[x][y] or {}
        for i = 1, #routing do
          _norns.grid_set_led(grid.devices[routing[i][1]].dev, routing[i][2], routing[i][3], val)
        end
      end
    end
  
    function vgrid:all(val)
      for i = 1, #dproperties do
        _norns.grid_all_led(dproperties[i].dev, val)
      end
    end
  
    function vgrid:refresh()
      for i = 1, #dproperties do      
        _norns.monome_refresh(dproperties[i].dev)
      end
    end
  
    function vgrid:rotation() end
    function vgrid:intensity() end
    function vgrid:tilt_enable() end  -- todo
    -- function vgrid:add() end    -- unsure
    -- function vgrid:remove() end -- unsure

  elseif state == "menu" then
    
    -- block real Grid functions and restore on deinit
    function vgrid:led(x, y, val) end
    function vgrid:all(val) end
    function vgrid:refresh() end
    function vgrid:rotation() end
    function vgrid:intensity() end
    function vgrid:tilt_enable() end
    -- function vgrid:add() end    -- unsure
    -- function vgrid:remove() end -- unsure
    
    -- use faux Grid functions while menu is open
    function combiner:led(x, y, val)
      if led_routing[x] then -- optional, in case script sends invalid coords
        local routing = led_routing[x][y] or {}
        for i = 1, #routing do
          _norns.grid_set_led(grid.devices[routing[i][1]].dev, routing[i][2], routing[i][3], val)
        end
      end
    end

    function combiner:all(val)
      for i = 1, #dproperties do        
        _norns.grid_all_led(dproperties[i].dev, val)
      end
    end
  
    function combiner:refresh()
      for i = 1, #dproperties do
        _norns.monome_refresh(dproperties[i].dev)
      end
    end

  end 
    
end


-- called when grids are plugged/unplugged, grid vports are changed, and once at startup after system hook
local function init_virtual()
  gen_layout() -- confirm if needed here
  
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

  grid_functions()

end


-- Visuals drawn on physical grids to assist with config
function grid_viz()
  -- print("grid_viz called")
  -- if state == "grid_viz" then
  if state == "menu" then

    -- highlight Grid we're editing_index
    local id = dproperties[editing_index].id
    for k, v in pairs(grid.devices) do
      local dev = v.dev -- todo what??
      _norns.grid_all_led(dev, k == id and 2 or 0)
    end

    -- draw border around virtual grid
    local rows = vgrid.rows
    local cols = vgrid.cols
    for x = 1, cols do
      for y = 1, rows do
        if x == 1 or x == cols or y == 1 or y == rows then
          combiner:led(x, y, 15)
        end
      end
    end
    
    combiner:refresh()
  end
end


-- todo this needs to updated any time a change occurs, or make sure to update when device is unplugged, before cleanup
function update_cache()
  for device_idx = 1, #dproperties do
    -- local ins = true
    local name = dproperties[device_idx].name
    local saved = {
      lvl = dproperties[device_idx].lvl,
      x = dproperties[device_idx].x,
      y = dproperties[device_idx].y,
      rot = dproperties[device_idx].rot,
      enabled = dproperties[device_idx].enabled
    }
    print("caching " .. name .. ":")
    tab.print(saved)
    dcache[name] = {}
    dcache[name] = saved
  end
end


-- todo need to think about how to handle grid-settings mod. Disable?
mod.hook.register("system_post_startup", "combiner post startup", function()
  
  
  -- redefine some buggy system code
  _norns.grid.remove = function(id)
    print("REDEFINED grid.remove CALLED")
    
    -- so we don't have to update_cache() every time dproperties is changed
    update_cache()    -- save latest settings to cache
    write_prefs()     -- write them immediately
    
    local g = grid.devices[id]
    if g then
      
      -- fix for error when unassigned Grid is unplugged
      if grid.vports[g.port] ~= nil and grid.vports[g.port].remove then -- todo PR this line
        grid.vports[g.port].remove()
      end
      if grid.remove then
        grid.remove(grid.devices[id])
      end
    end
    grid.devices[id] = nil
    grid.update_devices()
  end

  
  -- due to update_devices() overwriting vports after mod hook, redefine it
  local old_update_devices = grid.update_devices
  function grid.update_devices()
    print("REDEFINED GRID.UPDATE_DEVICES CALLED")
    tab.print(dproperties)
    
    -- kinda weird but this is to make sure settings are saved if device is unplugged
    -- update_cache()    -- save latest settings to cache in case device was just unplugged
    -- write_prefs()     -- write them immediately because they're about to be read again (for device add)
    
    old_update_devices()
    gen_dev_tables()  -- update dproperties
    read_prefs()      -- load prefs -- will cause settings to be lost if device is replugged live?
    init_virtual()    -- generate virtual interface

  end
end)


-- requires norns 231114
mod.hook.register("script_post_init", "combiner post init", function()
  key_handlers()
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


function m.enc(n, d)
  if n == 2 then
    local d = util.clamp(d, -1, 1)
    menu_pos = util.clamp(menu_pos + d, 1, 5)
  elseif n == 3 then
    if menu_pos == 1 then
      editing_index = util.clamp(editing_index + d, 1, #dproperties)

    else
      local dproperties = dproperties[editing_index]
      local key = menu_properties[menu_pos - 1]
      if key == "x" or key == "y" then
        d = util.clamp(d, -1, 1) -- * snap_quantum -- todo not snapping to quantum feels good
        dproperties[key] = math.max(dproperties[key] + d, 0)
        gen_layout()
      elseif key == "rot" then
        local d = util.clamp(d, -1, 1) * 3
        local new_rot = (dproperties[key] + d) % 4
        dproperties[key] = new_rot
        gen_layout()
      elseif key == "lvl" then
        local d = util.clamp(d, -1, 1)
        dproperties[key] = util.clamp(dproperties[key] + d, 0, 15)
        intensity(dproperties.id, dproperties[key])
      end
    end
    grid_viz() -- works but also fires unnecessarily
  end
  m.redraw()
end


function m.redraw()
  screen.clear()
  screen.blend_mode(2)
  local pos = 1

  local index = 1
  local serial = dproperties[editing_index].serial
  local name = dproperties[editing_index].description
  screen.level(menu_pos == index and 15 or 4)
  screen.move(86, 10)
  screen.text(serial)
  screen.move(86, 20)
  screen.text(name)

  index = 2
  for _, v in ipairs(menu_properties) do
    screen.level(menu_pos == index and 15 or 4)
    screen.move(86, (index + 1) * 10)
    screen.text(v)
    screen.move(127, (index + 1) * 10)
    screen.text_right(dproperties[editing_index][v] * (v == "rot" and 90 or 1))
    index = index + 1
  end
  
  screen.level(2)
  screen.move(81,5)
  screen.line(81,60)
  screen.stroke()
  
  -- draw tiny Grids!
  for i = 1, #dproperties do  -- todo only configured/enabled
    local dproperties = dproperties[i]
    local rotation = (dproperties.rot * 3) % 4  -- feels bad
    local rotated = (rotation % 2) ~= 0

    local cols = rotated and dproperties.rows or dproperties.cols 
    local rows = rotated and dproperties.cols or dproperties.rows
    
    local x_offset = dproperties.x
    local y_offset = dproperties.y

    screen.level(editing_index == i and 5 or 2)
    screen.rect(x_offset, y_offset, cols, rows)
    screen.fill()

    -- direction arrows
    if cols >= 8 and rows >= 8 then -- allow smaller than 8x8 but no arrows
      screen.level(15)
      for i = 1, #glyphs.arrow do
        local pixel_x, pixel_y = rotate_pairs({glyphs.arrow[i][1], glyphs.arrow[i][2]}, 6, 6, rotation)
        screen.pixel(pixel_x + x_offset + (cols / 2) - 4, pixel_y + y_offset + (rows / 2) - 4)
      end
      screen.fill()
    end
    
  end
  
  screen.update()
end


function m.init() -- on menu entry
  print("Menu entered")
  state = "menu"
  -- gen_dev_tables()  -- 
  grid_functions()
  grid_viz()
  key_handlers()
end


function m.deinit() -- on menu exit
  state = "running"
  grid_functions()  -- re-enable vgrid functions
  
  -- simplified. should really do this every time config changes AND before grid cleanup/unplug
  update_cache()
  write_prefs()
  key_handlers()
  vgrid:all(0)
  vgrid:refresh()
  -- TODO should we kill off any unused stuff on exit or does GC do this?
end


mod.menu.register(mod.this_name, m)


function key_handlers()
  if state == "running" then
    if norns.state.script ~= "" then  -- translate physical Grid keypresses to virtual layout
      print("setting virtual key handlers")
      for i = 1, #dproperties do
        local dproperties = dproperties[i]
        
        grid.devices[dproperties.id].key = function(x, y, s)
          if vgrid.key ~= nil then  -- prevents error if script has no key callback
            local x, y = rotate_pairs({x, y}, dproperties.cols, dproperties.rows, (dproperties.rot * 3) % 4)
            local y = y + dproperties.y - combiner.y_min
            local x = x + dproperties.x - combiner.x_min
            vgrid.key(x, y, s)
          end
        end
        
        -- -- looks like there is a bug that prevents devices from getting cleaned up unless this is set??
        -- grid.devices[dproperties.id].remove = function() 
        --   print("Combiner: Removing grid.devices[" .. id .. "]")
        -- end
        
        
      end
    else  -- clear handlers
      print("clearing key handlers")
      for i = 1, #dproperties do
        grid.devices[dproperties[i].id].key = nil
      end
    end
  else -- raw keypresses are used to configure layout while mod menu is open
    print("setting mod menu key handlers")
    local rotate = false
    local join_coords = {}
    
    local function orient_to_corner(x, y, cols, rows)
      local rot = 0
      if x == 1 and y == 1 then rot = 0
      elseif x == cols and y == 1 then rot = 1
      elseif x == cols and y == rows then rot = 2
      elseif x == 1 and y == rows then rot = 3
      end
      return(rot)
    end
    
    for i = 1, #dproperties do
      local dproperties = dproperties[i]
      local cols = dproperties.cols
      local rows = dproperties.rows
      grid.devices[dproperties.id].key = function(x, y, s)
        if s == 1 then
          -- print("Grid ID " .. k .. ": " .. x, y)
          
          editing_index = i

          if keypresses == 0 then
            rotate = true
          else
            rotate = false
          end
          keypresses = keypresses + 1
          
          -- set join_coords
          if keypresses == 1 then
            
            -- 1. rotate from physical to virtual oriantation
            local x, y = rotate_pairs({x, y}, cols, rows, (dproperties.rot * 3) % 4)

            -- 2. adjust next Grid's origin depending on corner
            local rotation = dproperties.rot
            local swap = (rotation % 2) ~= 0
            local cols = swap and dproperties.rows or dproperties.cols 
            local rows = swap and dproperties.cols or dproperties.rows
            if x == 1 and y == 1 then
              x = x - 1
              y = y - 1
            elseif x == cols and y == 1 then
              y = y - 1
            elseif x == cols and y == rows then
                           
            elseif x == 1 and y == rows then
              x = x -1
            end
            
            -- 3. apply offsets
            local x = x + dproperties.x
            local y = y + dproperties.y
            
            -- PROBLEM: source grid can be changed after this!
            -- need to either pass source grid ID and process on keypress 2 or...
            -- prevent any changes while keypress > 0 (prob easier)
            join_coords = {x, y}
          
          elseif keypresses == 2 then
            dproperties.rot = orient_to_corner(x, y, cols, rows)
            x, y = join_coords[1], join_coords[2]
            dproperties.x = x
            dproperties.y = y
          
          end
          
        elseif s == 0 then
          keypresses = math.max(keypresses - 1, 0)
          if keypresses > 1 then
            rotate = false
          end

          if rotate == true then
            dproperties.rot = orient_to_corner(x, y, cols, rows)
            rotate = false
          end

        end
        gen_layout()
        grid_viz()
        m.redraw()
      end -- of v.key function
    end
  end
end