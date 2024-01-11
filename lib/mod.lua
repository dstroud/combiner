-- https://github.com/dstroud/combiner

local mod = require 'core/mods'
local filepath = "/home/we/dust/data/combiner/"
local state = "running"
local m = {}                  -- system mod menu for settings
local combiner = {}
local version = 0.22          -- TODO update
local dproperties = {}        -- sequential devices + properties
local dcache = {}             -- cached user-configurable properties
local keypresses = 0
local menu_pos = 1
local editing_index = 1       -- which index in dproperties is being edited
local snap_quantum = 4
local vgrid = grid.connect(1) -- virtual Grid vport- hardcoded to 1
local led_routing = {}        -- routing table for virtual>>physical Grids
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


local function intensity(id, val) _norns.monome_intensity(grid.devices[id].dev, val) end


local function read_prefs()
  local prefs = {}
  if util.file_exists(filepath.."prefs.data") then
    prefs = tab.load(filepath.."prefs.data")
    print('table >> read: ' .. filepath.."prefs.data")
    if (prefs.version or 0) >= 0.2 then -- TODO adjust for breaking changes!
      dcache = prefs.dcache

      for i = 1, #dproperties do        -- apply settings to matching device names
        for cached_name, tab in pairs(dcache) do
          if dproperties[i].name == cached_name then
            for k, v in pairs(tab) do
              dproperties[i][k] = v
            end
          end
        end
        intensity(dproperties[i].id, dproperties[i].lvl)
      end

    end
  end
end


local function write_prefs(from)
  for device_idx = 1, #dproperties do
    local name = dproperties[device_idx].name
    local saved = {
      lvl = dproperties[device_idx].lvl,
      x = dproperties[device_idx].x,
      y = dproperties[device_idx].y,
      rot = dproperties[device_idx].rot,
      enabled = dproperties[device_idx].enabled
    }
    dcache[name] = {}
    dcache[name] = saved
  end

  local prefs = {}
  if util.file_exists(filepath) == false then
    util.make_dir(filepath)
  end

  prefs.version = version
  prefs.dcache = dcache

  tab.save(prefs, filepath .. "prefs.data")
  -- print("table >> write: " .. filepath.."prefs.data")
end


-- running n times doesn't seem particularly efficient
local function rotate_pairs(coordinates, cols, rows, rotation)
  local x, y = coordinates[1], coordinates[2]
  for r = 1, rotation do
    local rows = (r % 2 == 0) and cols or rows -- flip 'em
    x, y = rows + 1 - y, x -- 90-degree rotation CW
  end
  return x, y
end


-- Generate the virtual device
-- called by update_devices (grids are plugged/unplugged, vports are changed)
-- also called after system hook and when rows/cols are changed
local function init_virtual(cols, rows)
  if ((vgrid.cols or 0) ~= cols) or ((vgrid.rows or 0) ~= rows) then
    local size = tostring(cols * rows)
    local serial = string.sub("m0000000", 1, 8 - #size) .. size

    vgrid.name = "virtual " .. serial
    vgrid.rows = rows or 0
    vgrid.cols = cols or 0

    vgrid.device = {
      id = 1,
      port = 1,
      name = vgrid.name,
      serial = serial,
      -- TODO how to generate dev userdata or point to faux device table?
      -- dev = NA, @tparam userdata dev : opaque pointer to device.
      cols = vgrid.cols,
      rows = vgrid.rows,
    }

    -- simulate Grid removal/add for script callbacks to detect cols/rows changes
    if grid.remove ~= nil then grid.remove(vgrid.device) end
    if grid.add ~= nil then grid.add(vgrid.device) end

  end
end


-- determines overall dimensions for virtual grid and generates LED routing table
local function gen_layout()
  combiner.cols = 0
  combiner.rows = 0
  local x_min = nil     -- x origin of virtual grid
  local y_min = nil     -- y origin of virtual grid
  local x_max = nil     -- x max of virtual grid
  local y_max = nil     -- y max of virtual grid
  local enabled = false -- flag to wipe cols/rows if no Grids are enabled
  for i = 1, #dproperties do
    if dproperties[i].enabled == true then
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

  combiner.vgrid_dirty = true -- init vgrid on m.deinit
  
  -- generate flattened led_routing to translate from virtual to physical grids
  led_routing = {}
  for x = 1, combiner.cols do
		for y = 1, combiner.rows do
      led_routing[y * combiner.cols + x] = {}
		end
	end  

  for i = 1, #dproperties do
    if dproperties[i].enabled == true then
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
          table.insert(led_routing[y_virtual * combiner.cols + x_virtual], {dproperties.id, x_real, y_real})
        end
      end
    end
  end

end


local function gen_dproperties()
  dproperties = {}
  for k, v in pairs(grid.devices) do
    local min_dim = math.min(v.cols, v.rows)

    -- TODO: duplicate name check and maybe append id if needed (NeoTrellis)
    table.insert(dproperties,
      {id = v.id,
      name = v.name,
      shortname = string.sub(v.name, 1, #v.name - string.len(v.serial) - 1),
      serial = v.serial or ("id_" .. v.id),
      cols = v.cols,
      rows = v.rows,
      dev = v.dev,
      description = v.cols * v.rows,
      port = v.port,
      x = 0,
      y = 0,
      rot = 0,
      lvl = 15,
      enabled = false}
      )
  end
end


-- define virtual grid functions
local function grid_functions()
  if state == "running" then
    combiner.led = nil  -- probably unnecessary
    combiner.all = nil
    combiner.refresh = nil

    function vgrid:led(x, y, val)
      local routing = led_routing[y * combiner.cols + x] or {}
      for i = 1, #routing do
        _norns.grid_set_led(grid.devices[routing[i][1]].dev, routing[i][2], routing[i][3], val)
      end
    end
    
    function vgrid:all(val)
      for i = 1, #dproperties do _norns.grid_all_led(dproperties[i].dev, val) end
    end

    function vgrid:refresh()
      for i = 1, #dproperties do _norns.monome_refresh(dproperties[i].dev) end
    end

    function vgrid:rotation() end
    function vgrid:intensity() end
    function vgrid:tilt_enable() end  --TODO?

  -- alternate Grid functions are used while in menu (so script doesn't interfere)
  elseif state == "menu" then
    function vgrid:led(x, y, val) end
    function vgrid:all(val) end
    function vgrid:refresh() end
    function vgrid:rotation() end
    function vgrid:intensity() end
    function vgrid:tilt_enable() end

    -- use faux Grid functions while menu is open
    function combiner:led(x, y, val)
      local routing = led_routing[y * combiner.cols + x] or {}
      for i = 1, #routing or nil do
        _norns.grid_set_led(grid.devices[routing[i][1]].dev, routing[i][2], routing[i][3], val)
      end
    end
    
    function combiner:all(val)
      for i = 1, #dproperties do _norns.grid_all_led(dproperties[i].dev, val) end
    end

    function combiner:refresh()
      for i = 1, #dproperties do _norns.monome_refresh(dproperties[i].dev) end
    end

  end
end


-- Visuals drawn on physical grids to assist with config
local function grid_viz(style)
  local rows = combiner.rows
  local cols = combiner.cols
    
  if #dproperties > 0 then
    local id = dproperties[editing_index].id
    for k, v in pairs(grid.devices) do -- highlight Grid we're editing
      _norns.grid_all_led(v.dev, k == id and 2 or 0)
    end
    
    if style == "animate" then -- animate borders to help user understand layout
      local border_1 = {}
      local border_2 = {}

      for x = 1, cols do table.insert(border_1, {x, 1}) end
      
      for y = 1, rows do
        table.insert(border_1, {cols, y})
        table.insert(border_2, {1, y})
      end  
  
      for x = 1, cols do table.insert(border_2, {x, rows}) end
      
      if animate ~= nil then clock.cancel(animate) end
      animate = clock.run(function()
        for i = 1, #border_1 do
          combiner:led(border_1[i][1], border_1[i][2], 15)
          combiner:led(border_2[i][1], border_2[i][2], 15)
          combiner:refresh()
          clock.sleep(.007)
        end
      end)
    else -- static
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
end


local function key_handlers()
  if state == "running" then
    if norns.state.script ~= "" then
      for i = 1, #dproperties do
        local dproperties = dproperties[i]
        if dproperties.enabled then -- translate physical Grid keypresses to virtual layout
          grid.devices[dproperties.id].key = function(x, y, s)
            if vgrid.key ~= nil then  -- prevents keypress errors if script has no key callback
              local x, y = rotate_pairs({x, y}, dproperties.cols, dproperties.rows, (dproperties.rot * 3) % 4)
              local y = y + dproperties.y - combiner.y_min
              local x = x + dproperties.x - combiner.x_min
              vgrid.key(x, y, s)
            end
          end
        else -- clear *device* handlers so script can use this Grid via *vport* handlers
          grid.devices[dproperties.id].key = nil
        end
      end
    else -- no scipt: clear device handlers (vport handlers still available)
      for i = 1, #dproperties do grid.devices[dproperties[i].id].key = nil end
    end

  -- ALL Grids get handlers while in the menu- even disabled ones (so we can touch-enable them)
  elseif state == "menu" then
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

    for i = 1, #dproperties do
      local dproperties = dproperties[i]
      local cols = dproperties.cols
      local rows = dproperties.rows
      grid.devices[dproperties.id].key = function(x, y, s)
        local corner = orient_to_corner(x, y, cols, rows) ~= nil
        if s == 1 then
          editing_index = i          -- any keypress flags as being edited
          dproperties.enabled = true -- and enables device for inclusion in vgrid

          if corner then
            if keypresses == 0 then
              rotate = true
            else
              rotate = false
            end
            keypresses = keypresses + 1

            if keypresses == 1 then -- set join_coords

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
              elseif x == 1 and y == rows then
                x = x -1
              end

              -- 3. apply offsets
              local x = x + dproperties.x
              local y = y + dproperties.y

              join_coords = {x, y}

            elseif keypresses == 2 then
              dproperties.rot = orient_to_corner(x, y, cols, rows)
              x, y = join_coords[1], join_coords[2]
              dproperties.x = x
              dproperties.y = y
              gen_layout()
              grid_viz("animate")
              write_prefs()
            end
          else-- non-corner presses can still enable devices
            gen_layout()
            grid_viz("animate")
            write_prefs()
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
            grid_viz("animate")
            write_prefs()
          end

        end
        m.redraw()
      end -- of v.key function

    end
  end
end


function m.key(n, z)
  if keypresses == 0 then
    if z == 1 then
      if n == 1 then
        snap_quantum = 1
      elseif n == 2 then
        mod.menu.exit()
      elseif n == 3 then
        dproperties[editing_index].enabled = not dproperties[editing_index].enabled
        gen_layout()
        grid_viz()
        m.redraw()
        write_prefs()
      end
    elseif z == 0 and n == 1 then
      snap_quantum = 4
    end
  end
end


function m.enc(n, d)
  if keypresses == 0 then
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
          local d = util.clamp(d, -1, 1) * snap_quantum
          local snapped_coord = (math.floor(dproperties[key] / snap_quantum + 0.5) * snap_quantum)
          if (d > 0 and snapped_coord > dproperties[key])
          or (d < 0 and snapped_coord < dproperties[key]) then
            dproperties[key] = snapped_coord
          else
            dproperties[key] = math.max(snapped_coord + d, 0)
          end
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
end


function m.redraw()
  screen.clear()
  screen.blend_mode(2)
  screen.line_width(1)
  screen.aa(0)
  local devices = #dproperties
  local eproperties = dproperties[editing_index]  -- editing device properties
  local vcols = combiner.cols
  local vrows = combiner.rows
  local pos = 1
  local index = 1
  local text = function(fn, x, y, string)
    screen.move(x, y)
    screen[fn](string)
  end  

  if devices == 0 then  -- no hw
    screen.level(10)
    text("text_center", 60, 40, "no grid detected")
    
  elseif vcols == 0 and vrows == 0 then -- nothing enabled
    screen.clear()

    screen.level(15)
    text("text", 0, 10, "Tap col 1, row 1")
    text("text", 0, 20, "to place first Grid")
    
    text("text", 0, 40, "Hold+tap corners")
    text("text", 0, 50, "to place more Grids")

    local function rect(x, y)
      screen.level(4)
      screen.rect(x, y, 16, 8)
      screen.fill()
    end
    
    local function keypress(x, y, blink)
      screen.level(blink and 15 or 4)
      screen.pixel(x, y)
      screen.fill()
      screen.update()
    end  
    
    rect(95, 5)
    rect(95, 35)
    rect(112, 44)
    rect(95, 44)
    rect(112, 35)    
    keypress(95 + 15, 35, true)
    keypress(95, 35 + 7, true)
    keypress(95 + 15, 35 + 7, true)
    keypress(95, 35, true)

    local blink = true
    blinky_clock = clock.run(function()
      while combiner.cols == 0 and combiner.rows == 0 do
        keypress(95, 5, blink)
        keypress(95, 44, blink)
        keypress(112, 35, blink)
        keypress(112, 44, blink)
        blink = not blink
        clock.sleep(.5)
      end
    end)

  else  -- standard mod menu
    local description = editing_index .. "/" .. devices .. " " .. eproperties.description

    screen.level(menu_pos == index and 15 or 4)
    text("text", 86, 10, description)
    
    if eproperties.enabled then
      screen.rect(124, 6, 3, 3)
      screen.fill()
    end
    
    index = 2
    for _, v in ipairs(menu_properties) do
      screen.level(menu_pos == index and 15 or 4)
      text("text", 86, (index + 1) * 10, v)
      text("text_right", 127, (index + 1) * 10, eproperties[v] * (v == "rot" and 90 or 1))
      
      index = index + 1
    end

    -- divider
    screen.level(2)
    screen.move(82,0)   -- 0-indexed
    screen.line(82,64)  -- 1-indexed
    screen.stroke()

    -- draw vgrid border
    screen.level(1)
    screen.rect((combiner.x_min or 0) + 1, (combiner.y_min or 0) + 1, vcols - 1, vrows - 1)
    screen.stroke()

    -- draw individual grids
    for i = 1, devices do
      local iproperties = dproperties[i]
      if iproperties.enabled then
        local rotation = (iproperties.rot * 3) % 4
        local rotated = (rotation % 2) ~= 0
        local cols = rotated and iproperties.rows or iproperties.cols
        local rows = rotated and iproperties.cols or iproperties.rows
        local x_offset = iproperties.x
        local y_offset = iproperties.y

        screen.rect(x_offset, y_offset, cols, rows)
        screen.level(editing_index == i and 8 or 2)
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
  
    -- overlay vgrid dimensions
    screen.level(4)
    text("text_right", 77, 60, vcols .. "x" .. vrows)
  end
  screen.update()
end


function m.init() -- on menu entry
  state = "menu"
  grid_functions()
  grid_viz("animate")
  key_handlers()
end


function m.deinit() -- on menu exit
  if animate ~= nil then clock.cancel(animate) end
  state = "running"
  if blinky_clock ~= nil then clock.cancel(blinky_clock) end
  if combiner.vgrid_dirty  then
    init_virtual(combiner.cols, combiner.rows)
    vgrid_dirty = false
  end
  grid_functions()
  write_prefs()
  key_handlers()
  vgrid:all(0)
  vgrid:refresh()
  -- TODO should I kill off any unused menu stuff on exit? I don't understand GC.
end


mod.menu.register(mod.this_name, m)


mod.hook.register("system_post_startup", "combiner post startup", function()

  -- fix for bug preventing grid.devices removal when no Grids are assigned to grid.vports
  _norns.grid.remove = function(id)
    local g = grid.devices[id]
    if g then
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


  local old_update_devices = grid.update_devices
  function grid.update_devices()
    local name = dproperties[editing_index] and dproperties[editing_index].name or nil
    old_update_devices()                        -- call original update_devices
    gen_dproperties()                           -- create dproperties with defaults
    read_prefs()                                -- load cached device properties
    gen_layout()                                -- generate layout and vgrid
    grid_functions()                            -- define vgrid functions (led, etc..)
    key_handlers()                              -- define key callback handlers
    editing_index = 1                           -- restore or pick new device to edit
    for i = 1, #dproperties do
      if dproperties[i].name == name then
        editing_index = i
      end
    end
    if state == "menu" then
      grid_viz()                                -- redraw grid viz
      m.redraw()                                -- redraw menu
    else
      init_virtual(combiner.cols, combiner.rows)  -- immediately trigger grid.add to notify scripts
    end
  end

end)


-- requires norns 231114- TODO could do a check
mod.hook.register("script_post_init", "combiner post init", function()
  key_handlers()
end)