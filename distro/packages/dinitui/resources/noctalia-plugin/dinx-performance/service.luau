--!nonstrict
-- Poll the DinitUI state file through its read-only status command so the
-- quick toggle and panel also follow changes made outside Noctalia.

noctalia.setUpdateInterval(3000)

function update()
  noctalia.runAsync({ "dinitui", "--profile-status" }, function(result)
    if result.exitCode ~= 0 then return end
    local value = string.match(result.stdout, "profile=([%w%._-]+)")
    if value ~= nil then noctalia.state.set("profile", value) end
  end)
end
