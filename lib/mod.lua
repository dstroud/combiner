-- mod to combine multiple Grids into a single virtual Grid
-- https://github.com/dstroud/combiner

-- TODO fix: test with no grids
--          limit where grids can be touched


-- TODO ideas:
-- fine snap quantum (and limit to min of 4)
-- flip grid on axis (left/right hand mode)
-- gamma/level curves
-- m-m-M-MEGAGRID
-- define virtual size and add some way of navigating via smaller grid (pmap an x/y param?)

local mod = require 'core/mods'
local filepath = "/home/we/dust/data/combiner/"
local state = "running" -- needs to be checked by redefined update_devices. Make combiner. ?
combiner = {}     -- TODO LOCAL but probably just kill this off??
combiner.version = 0.2  -- TODO UPDATE
dproperties = {}        -- sequential devices + properties
local dcache = {}       -- cached user-configurable properties
local keypresses = 0
local menu_pos = 1
editing_index = 1       -- which index in dproperties is being edited
local snap_quantum = 4
vgrid = grid.connect(1) -- Virtual Grid vport
led_routing = {}  -- routing table for virtual>>physical Grids
local glyphs = {
  arrow = {
                {3,1}, {4,1},
         {2,2}, {3,2}, {4,2}, {5,2}, 
  {1,3}, {2,3}, {3,3}, {4,3}, {5,3}, {6,3}, 
                {3,4}, {4,4}, 
                {3,5}, {4,5}, 
                {3,6}, {4,6} -- felt cute, might delete later
  }
}

local menu_properties = {"x", "y", "rot", "lvl"}


local function read_prefs()
  local prefs = {}
  if util.file_exists(filepath.."prefs.data") then
    prefs = tab.load(filepath.."prefs.data")
    print('table >> read: ' .. filepath.."prefs.data")
    if (prefs.version or 0) >= 0.2 then -- TODO adjust for breaking changes
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
        intensity(dproperties[i].id, dproperties[i].lvl) -- todo confirm only place needed
      end
  
    end
  end
end


local function write_prefs(from)
  update_cache()
  local prefs = {}
  if util.file_exists(filepath) == false then
    util.make_dir(filepath)
  end

  prefs.version = combiner.version
  prefs.dcache = dcache

  tab.save(prefs, filepath .. "prefs.data")
  print("table >> write: " .. filepath.."prefs.data")
end


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
  local enabled = false -- flag to wipe cols/rows if no Grids are enabled
  for i = 1, #dproperties do -- todo test with 0 configured. Also need enabled/disabled
    if dproperties[i].enabled == true then
      enabled = true
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
  
  print("gen_layout enabled = " .. tostring(enabled))
  -- extra check to reset cols/rows if all Grids are disabled/unplugged
  -- todo is this even needed? temporary storage but could init vgrid.cols in global scope
  -- ISSUE: init_virtual runs after this and just takes combiner.cols
  -- vgrid.cols = enabled and (combiner.cols or 0) or 0
  -- vgrid.rows = enabled and (combiner.rows or 0) or 0
  -- TODO REFACTOR INTERACTION BETWEEN THIS FUNCTION AND INIT_VIRTUAL
  combiner.cols = enabled and (combiner.cols or 0) or 0
  combiner.rows = enabled and (combiner.rows or 0) or 0  
  vgrid.cols = combiner.cols
  vgrid.rows = combiner.rows
  
  
  print("gen_layout vgrid.cols/rows " .. vgrid.cols, vgrid.rows)
  -- print("Combiner: " .. combiner.cols .. "x" .. combiner.rows .. " virtual Grid configured")
  
  -- generate led_routing to translate from virtual to physical grids
  led_routing = {}
  for x = 1, vgrid.cols do
    led_routing[x] = {}
    for y = 1, vgrid.rows do
      led_routing[x][y] = {}
    end
  end
  
  print("debug a #dproperties = " .. #dproperties)
  for i = 1, #dproperties do -- todo test with 0 configured. Also need enabled/disabled devices
    if dproperties[i].enabled == true then
      -- ISSUE: dproperties is getting disabled at some point here
      local dproperties = dproperties[i]
      local x_offset = dproperties.x
      local y_offset = dproperties.y
      local rotation = dproperties.rot
      local swap = (rotation % 2) ~= 0
      local cols = swap and dproperties.rows or dproperties.cols 
      local rows = swap and dproperties.cols or dproperties.rows
      
      for x_real = 1, cols do
        for y_real = 1, rows do
          local x_virtual = x_real + x_offset - (x_min or 0)
          local y_virtual = y_real + y_offset - (y_min or 0)
          local x_real, y_real = rotate_pairs({x_real, y_real}, cols, rows, rotation)
          table.insert(led_routing[x_virtual][y_virtual], {dproperties.id, x_real, y_real})
        end
      end
    end
  end
  
  print("led_routing count gen_layout: " .. #led_routing)
  -- tab.print(led_routing)
end


local function gen_dproperties()
  dproperties = {}
  for k, v in pairs(grid.devices) do
    local min_dim = math.min(v.cols, v.rows)
    snap_quantum = math.max(min_dim, 4)

    -- todo: duplicate name check and append id if needed (NeoTrellis)
    -- ISSUE: this is defaulting settings that haven't been cached yet! (like enabled)
    table.insert(dproperties, 
      {id = v.id,
        name = v.name,
        shortname = string.sub(v.name, 1, #v.name - string.len(v.serial) - 1),
        serial = v.serial or "id_" .. v.id,
        cols = v.cols,
        rows = v.rows,
        dev = v.dev,
        -- description = v.cols .. "x" .. v.rows, -- todo maybe key count is better (rotation!)
        description = v.cols * v.rows,
        port = v.port,
        
        -- defaults
        x = 0,
        y = 0,
        rot = 0,
        lvl = 15,
        enabled = false}
      )
  end
end


-- set virtual grid functions; while in menus, suspend calls from scripts
local function grid_functions()
  
  if state == "running" then
    -- nil faux menu functions (not really necessary?)
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

  -- alternate functions are used while in menu so script doesn't interfere
  elseif state == "menu" then
    print("setting grid led functions for menu")
    -- block real Grid functions and restore on deinit
    function vgrid:led(x, y, val) end
    function vgrid:all(val) end
    function vgrid:refresh() end
    function vgrid:rotation() end
    function vgrid:intensity() end
    function vgrid:tilt_enable() end
    
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


-- Generate the virtual device
-- called when grids are plugged/unplugged, grid vports are changed, and once at startup after system hook
-- todo either just call at global scope instead of every time a device is updated, or maybe only have it get created/added if rows and cols are >0
local function init_virtual()
  vgrid.name = "virtual"
  vgrid.rows = combiner.rows or 0
  vgrid.cols = combiner.cols or 0
  vgrid.device = {  -- generate just in case some script needs this
    id = 1,
    port = 1,
    name = "virtual",
    serial = "V0000001",
    -- dev = NA, @tparam userdata dev : opaque pointer to device.
    cols = combiner.cols or 0,
    rows = combiner.rows or 0,
  }
end


-- Visuals drawn on physical grids to assist with config
function grid_viz()
  if state == "menu" then

    -- highlight Grid we're editing
    if #dproperties > 0 then
      local id = dproperties[editing_index].id
      for k, v in pairs(grid.devices) do
        _norns.grid_all_led(v.dev, k == id and 2 or 0)
      end
  
      -- draw border around virtual grid
      local rows = vgrid.rows
      local cols = vgrid.cols
      for x = 1, cols do
        for y = 1, rows do
          if x == 1 or x == cols or y == 1 or y == rows then
            -- print("combiner:led to vcoords " .. x, y )
            combiner:led(x, y, 15)
          end
        end
      end
      
      combiner:refresh()
    end
  end
end


function intensity(id, val)
  _norns.monome_intensity(grid.devices[id].dev, val)
end


-- updates when any device config is changed
function update_cache()
  for device_idx = 1, #dproperties do
    local name = dproperties[device_idx].name
    local saved = {
      lvl = dproperties[device_idx].lvl,
      x = dproperties[device_idx].x,
      y = dproperties[device_idx].y,
      rot = dproperties[device_idx].rot,
      enabled = dproperties[device_idx].enabled
    }
    print("caching " .. name .. ":")
    -- tab.print(saved)
    dcache[name] = {}
    dcache[name] = saved
  end
end


-- system mod menu for settings
local m = {}

function m.key(n, z)
  if z == 1 then
    if n == 2 then
      mod.menu.exit()
    elseif n == 3 then
      dproperties[editing_index].enabled = not dproperties[editing_index].enabled
      gen_layout()  -- will update vgrid rows/cols
      grid_viz()
      m.redraw()
      write_prefs()
    end
  end
end


function m.enc(n, d)
  if n == 2 then
    local d = util.clamp(d, -1, 1)
    menu_pos = util.clamp(menu_pos + d, 1, #menu_properties + 1)
  elseif n == 3 then
    if menu_pos == 1 then
      editing_index = util.clamp(editing_index + d, 1, #dproperties)
    else
      local dproperties = dproperties[editing_index]
      local key = menu_properties[menu_pos - 1]
      if key == "x" or key == "y" then
        d = util.clamp(d, -1, 1) * snap_quantum -- todo K1 for fine control
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
    write_prefs()
    end
    grid_viz()
  end
  m.redraw()
end


function m.redraw()
  screen.clear()
  screen.blend_mode(2)
  local pos = 1

  local index = 1
  if #dproperties == 0 then
    screen.level(10)
    screen.move(64,40)
    screen.text_center("no grid detected")
  else
    local description = editing_index .. "/" .. #dproperties .. " " .. dproperties[editing_index].description

    screen.level(menu_pos == index and 15 or 4)
    screen.move(86, 10)
    screen.text(description)
    if dproperties[editing_index].enabled then
      screen.rect(124, 6, 3, 3)
      screen.fill()
    end
    
    index = 2
    for _, v in ipairs(menu_properties) do
      local dproperties = dproperties[editing_index]
      screen.level(menu_pos == index and 15 or 4)
      screen.move(86, (index + 1) * 10)
      screen.text(v)
      screen.move(127, (index + 1) * 10)
      screen.text_right(dproperties[v] * (v == "rot" and 90 or 1))
      index = index + 1
    end
    
    screen.level(2)
    screen.move(81,5)
    screen.line(81,60)
    screen.stroke()
    
    
    -- draw vgrid border
    if vgrid.cols > 0 and vgrid.rows > 0 then
      local x_min = combiner.x_min or 0  -- again should just init these somewhere
      local y_min = combiner.y_min or 0
    
      screen.level(2)
      screen.move(x_min, y_min + 1)
      screen.line(x_min + vgrid.cols, y_min + 1)
      screen.line(x_min + vgrid.cols, y_min + vgrid.rows)
      screen.line(x_min + 1, y_min + vgrid.rows)
      screen.line(x_min + 1, y_min)
      screen.stroke()
    end
  
    -- draw individual grids
    for i = 1, #dproperties do  -- todo only configured/enabled
      local dproperties = dproperties[i]
      if dproperties.enabled then
        local rotation = (dproperties.rot * 3) % 4  -- feels bad
        local rotated = (rotation % 2) ~= 0
    
        local cols = rotated and dproperties.rows or dproperties.cols 
        local rows = rotated and dproperties.cols or dproperties.rows
        
        local x_offset = dproperties.x
        local y_offset = dproperties.y
    
        screen.level(editing_index == i and 6 or 2)
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
      
    end
  end
  
  screen.update()
end


function m.init() -- on menu entry
  print("Menu entered")
  state = "menu"
  grid_functions()
  grid_viz()
  key_handlers()
end


function m.deinit() -- on menu exit
  state = "running"
  grid_functions()  -- re-enable vgrid functions
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
      -- print("setting virtual key handlers")
      for i = 1, #dproperties do
        -- BIG TODO: are these getting set even on disabled devices? I think so. FIX IT.
        local dproperties = dproperties[i]
        
        grid.devices[dproperties.id].key = function(x, y, s)
          if vgrid.key ~= nil then  -- prevents error if script has no key callback
            local x, y = rotate_pairs({x, y}, dproperties.cols, dproperties.rows, (dproperties.rot * 3) % 4)
            local y = y + dproperties.y - combiner.y_min
            local x = x + dproperties.x - combiner.x_min
            vgrid.key(x, y, s)
          end
        end
      
      end
    else  -- clear handlers
      -- print("clearing key handlers")
      for i = 1, #dproperties do
        grid.devices[dproperties[i].id].key = nil
      end
    end
  -- all Grids get handlers while in the menu- even disabled ones (so we can touch-enable them)
  elseif state == "menu" then
    -- print("setting mod menu key handlers")
    local rotate = false
    local join_coords = {}
    
    local function orient_to_corner(x, y, cols, rows)
      local rot = nil
      if x == 1 and y == 1 then rot = 0
      elseif x == cols and y == 1 then rot = 1
      elseif x == cols and y == rows then rot = 2
      elseif x == 1 and y == rows then rot = 3
      end
      return(rot)
    end
    
    -- note: this 
    for i = 1, #dproperties do
      local dproperties = dproperties[i]
      local cols = dproperties.cols
      local rows = dproperties.rows
      grid.devices[dproperties.id].key = function(x, y, s)
        -- print("menu key_handler called")
        -- print(x, y, s)
        local corner = orient_to_corner(x, y, cols, rows) ~= nil
        if s == 1 then
          -- print("Grid ID " .. k .. ": " .. x, y)
          editing_index = i          -- any keypress flags as being edited
          dproperties.enabled = true -- and enables device for inclusion in vgrid
            
          if corner then
            -- print("corner press")
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
              -- elseif x == cols and y == rows then
              elseif x == 1 and y == rows then
                x = x -1
              end
              
              -- 3. apply offsets
              local x = x + dproperties.x
              local y = y + dproperties.y
              
              -- PROBLEM: source grid can be changed after this!
              -- need to either pass source grid ID and process on keypress 2 or...
              -- prevent any changes while keypress > 0 (prob easier)
              -- also, can self-join!
              join_coords = {x, y}
              print("SAVED JOIN_COORDS : " .. x, y)
            
            elseif keypresses == 2 then
              dproperties.rot = orient_to_corner(x, y, cols, rows)
              x, y = join_coords[1], join_coords[2]
              print("RETRIEVED JOIN_COORDS : " .. x, y)
              dproperties.x = x
              dproperties.y = y
              gen_layout()
              write_prefs()
            end
          else
            write_prefs() -- needed for non-corner presses
            print(" NOT corner press")
          end
          
        elseif s == 0 and corner then
          keypresses = math.max(keypresses - 1, 0)
          if keypresses > 1 then
            rotate = false
          end

          if rotate == true then  -- reorient AND set as origin
            dproperties.rot = orient_to_corner(x, y, cols, rows)
            dproperties.x = 0
            dproperties.y = 0
            rotate = false
            gen_layout()
            write_prefs()
          end

        end
        grid_viz()  -- todo check if running unnecessarily
        m.redraw()
      end -- of v.key function
    end
  end
end


-- todo need to think about how to handle grid-settings mod. Disable?
mod.hook.register("system_post_startup", "combiner post startup", function()
  
  -- redefine some buggy system code and piggyback off this to trigger caching
  _norns.grid.remove = function(id)
    print("redefined grid.remove called")

    -- write_prefs()     -- write them immediately -- TODO CONFIRM NOT NEEDED ANY MORE??
    
    local g = grid.devices[id]
    if g then
      
      -- fix for bug preventing grid.devices removal with no Grids are assigned in grid.vports
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
    print("redefined update_devices called")
    
    local name = nil      -- save name of device we're editing
    if dproperties[editing_index] ~= nil then
      name = dproperties[editing_index].name
    end
    
    old_update_devices()
    gen_dproperties()     -- create dproperties with defaults
    read_prefs()          -- load cached device properties
    gen_layout()          -- generate led_routing
    init_virtual()        -- generate virtual interface -- PROBLEM: why isn't this resetting col/rows
    grid_functions()      -- define virtual to physical grid functions (led, etc..)
    key_handlers()        -- define key callback handlers

    editing_index = 1     -- restore or pick new device to edit
    for i = 1, #dproperties do
      if dproperties[i].name == name then
        editing_index = i
      end
    end
    grid_viz()            -- redraw grid viz, has to happen AFTER editing_index reset
    if state == "menu" then
      m.redraw()            -- redraw menu
    end
  end
  
end)


-- requires norns 231114
mod.hook.register("script_post_init", "combiner post init", function()
  key_handlers()
end)