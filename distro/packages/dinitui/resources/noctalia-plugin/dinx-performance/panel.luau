--!nonstrict
-- Settings-style panel for Normal, Lite, Gaming, and custom DinitUI profiles.

local profile = noctalia.state.get("profile") or "normal"
local selectedIndex = 0
local status = "Select a profile. Customize service membership in DinitUI."
local profiles = { "normal", "lite", "gaming" }

local function indexFor(value)
  for index, item in ipairs(profiles) do
    if item == value then return index - 1 end
  end
  return 0
end

local function setPowerProfile(value, onDone)
  local power = value == "gaming" and "performance" or "balanced"
  noctalia.runAsync({ "noctalia", "msg", "power-set", power }, function(result)
    if result.exitCode ~= 0 then
      onDone(false, result.stderr ~= "" and result.stderr or "unknown error")
      return
    end
    onDone(true, "")
  end)
end

local function render()
  panel.render(ui.column({ flexGrow = 1, gap = 16, align = "stretch" }, {
    ui.label({ text = "DINX Performance", fontSize = 18, fontWeight = "bold" }),
    ui.label({ text = "Gaming keeps network, audio, login, and display services available. Optional services are explicit and editable in DinitUI.", color = "on_surface_variant" }),
    ui.select({ options = profiles, selectedIndex = selectedIndex, onChange = "onProfileSelected" }),
    ui.button({ text = "Apply profile", variant = "primary", onClick = "onApplyClicked" }),
    ui.button({ text = "Customize profiles in DinitUI", onClick = "onOpenDinitUI" }),
    ui.label({ text = `Active: {profile} · {status}`, color = "on_surface_variant" }),
  }))
end

local function apply(value)
  status = `Applying {value}…`
  render()
  noctalia.runAsync({ "dinitui", "--apply-profile", value }, function(result)
    if result.exitCode ~= 0 then
      status = `Failed: {result.stderr}`
      render()
      return
    end
    profile = value
    selectedIndex = indexFor(value)
    noctalia.state.set("profile", value)
    setPowerProfile(value, function(power_ok, detail)
      if power_ok then
        status = "Applied"
        noctalia.notify("DINX Performance", `Profile {value} applied`)
      else
        status = `Applied; power profile sync failed: {detail}`
        noctalia.notify("DINX Performance", status)
      end
      render()
    end)
  end)
end

function onOpen(_context)
  selectedIndex = indexFor(profile)
  render()
end

function onProfileSelected(index, _text)
  selectedIndex = tonumber(index) or 0
  profile = profiles[selectedIndex + 1] or "normal"
  status = "Ready to apply"
  render()
end

function onApplyClicked()
  apply(profile)
end

function onOpenDinitUI()
  noctalia.runAsync({ "dinitui" })
end

noctalia.state.watch("profile", function(value)
  profile = value or "normal"
  selectedIndex = indexFor(profile)
  render()
end)
