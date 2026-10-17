--!nonstrict
-- DINX Gaming quick-toggle. The service policy is applied by dinitui; the
-- Noctalia power profile is kept in sync with the same explicit selection.

local gaming = false

local function render()
  shortcut.setLabel(gaming and "Gaming On" or "Gaming")
  shortcut.setIcon("gamepad-2")
  shortcut.setActive(gaming)
  shortcut.setEnabled(noctalia.commandExists("dinitui"))
end

local function setPowerProfile(profile, onDone)
  local power = profile == "gaming" and "performance" or "balanced"
  noctalia.runAsync({ "noctalia", "msg", "power-set", power }, function(result)
    onDone(result.exitCode == 0, result.stderr ~= "" and result.stderr or "unknown error")
  end)
end

local function apply(profile)
  shortcut.setEnabled(false)
  noctalia.runAsync({ "dinitui", "--apply-profile", profile }, function(result)
    if result.exitCode ~= 0 then
      noctalia.notify("DINX Performance", `Could not apply {profile}: {result.stderr}`)
      render()
      return
    end
    gaming = profile == "gaming"
    noctalia.state.set("profile", profile)
    setPowerProfile(profile, function(power_ok, detail)
      if power_ok then
        noctalia.notify("DINX Performance", `Profile {profile} applied`)
      else
        noctalia.notify("DINX Performance", `Profile {profile} applied; power profile sync failed: {detail}`)
      end
      render()
    end)
  end)
end

function update()
  local profile = noctalia.state.get("profile")
  gaming = profile == "gaming"
  render()
end

function onClick()
  apply(gaming and "normal" or "gaming")
end

noctalia.state.watch("profile", function(value)
  gaming = value == "gaming"
  render()
end)

update()
