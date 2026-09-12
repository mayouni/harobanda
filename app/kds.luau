--!nonstrict
-- kds.luau -- the kitchen display world, as the Makeen box carries it in
-- the emulator court. A stand-in for the RestoLean KDS: it says where it
-- runs and reads the machine that declared it.
print("kds: the kitchen display world is up on the Makeen box (aarch64, stzr under PID 1)")
local ok, src = pcall(readfile, "/etc/machine")
if ok then
    local n = 0
    for _ in src:gmatch("DEFINE ") do n += 1 end
    print(("kds: read /etc/machine -- %d declarations rode in the image"):format(n))
else
    print("kds: /etc/machine unreadable -- " .. tostring(src))
end
