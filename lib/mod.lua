-- combiner: grid aggregator
local mod = require 'core/mods'
local filepath = "/home/we/dust/data/combiner/"
local v = 1
local a = 3
local b = 4


local function init_virtual()
  local vport_path = grid.vports[v]

  grid.vports[v].name = "virtual 256"
  grid.vports[v].rows = 16
  grid.vports[v].cols = 16
  
  grid.vports[v].device = {
    id = 1,
    port = 1,
    name = "virtual 256",
    serial = "00000000",
    -- dev = NA, @tparam userdata dev : opaque pointer to device.
    cols = 16,
    rows = 16,
  }

  function vport_path:led(x, y, val)
    if y <= 8 then
      grid_a:led(x, y, val)
    else
      grid_b:led(x, y - 8, val)
    end
  end
  
  function vport_path:all(val)
    grid_a:all(val)
    grid_b:all(val)
  end
  
  function vport_path:refresh()
    grid_a:refresh(val)
    grid_b:refresh(val)
  end  

end


-- define new key input handlers that pass to virtual grid
local function define_handlers()
  
  grid.vports[a].key = function(x, y, s)
    if y <=8 then  -- little debug assist for Zero
      grid_v.key(x, y, s)
    end
  end
  
  grid.vports[b].key = function(x, y, s)
    if y <=8 then  -- little debug assist for Zero
      local y = y + 8
      grid_v.key(x, y, s)
    end
  end
  
end  


local function connect_vports()
  grid_v = grid.connect(1)  -- virtual grid
  grid_a = grid.connect(a)  -- physical grid a
  grid_b = grid.connect(b)  -- physical grid b
end
  
mod.hook.register("system_post_startup", "combiner post startup", function()
  
  -- grid.vport tables are overwritten after system_post_startup hook with contents of grid.devices
  -- can't just set grid.devices, however, because we don't have a dev to point to
  -- script hooks happen after some scripts check for grid
  -- weird solution: redefine grid.update_devices() to create a virtual grid
  function grid.update_devices()
    grid.list = {}
    for _,device in pairs(grid.devices) do
      device.port = nil
    end
  
    -- connect available devices to vports
    for i=1,4 do
      grid.vports[i].device = nil
      grid.vports[i].rows = 0
      grid.vports[i].cols = 0       
  
      for _,device in pairs(grid.devices) do
        if device.name == grid.vports[i].name then
          grid.vports[i].device = device
          grid.vports[i].rows = device.rows
          grid.vports[i].cols = device.cols
          device.port = i
        end
      end
    end
    
    -- our bits --
    init_virtual()
    connect_vports()

  end

end)


-- requires norns 231114
mod.hook.register("script_post_init", "combiner post init", function() 
  define_handlers()
end)

  