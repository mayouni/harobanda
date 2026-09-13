--!nonstrict
-- kds.luau -- the kitchen display world of the Makeen box, as a DAEMON.
--
-- Until 2026-09-13 this was a stand-in that printed two lines and
-- exited, which made every box transcript a lie of shape: the real
-- kitchen display serves a service and never exits, and a box whose
-- worlds all end is a box PID 1 halts. The declaration now says what
-- the world is -- RESTART always, READY "/run/kds.ready" -- and this
-- file keeps that promise: it says where it runs, reads the machine
-- that declared it, signals that it is SERVING by creating its declared
-- path, and then stays alive.
--
-- The signal is the last thing written, on purpose: what comes AFTER
-- this world starts only when the path appears, and an A/B trial
-- commits only once every world has signalled. A path created before
-- the world was ready would be a promise made in advance.
--
-- The real world's loop waits on orders; this one waits on the clock,
-- because a stand-in must not pretend to serve what it cannot serve.

print("kds: the kitchen display world is up on the Makeen box (aarch64, stzr under PID 1)")

local ok, src = pcall(readfile, "/etc/machine")
if ok then
    local n = 0
    for _ in src:gmatch("DEFINE ") do n += 1 end
    print(("kds: read /etc/machine -- %d declarations rode in the image"):format(n))
else
    print("kds: /etc/machine unreadable -- " .. tostring(src))
end

print("kds: serving -- signalling /run/kds.ready")
writefile("/run/kds.ready", "kds\n")

-- the daemon's rest: a real init keeps this world alive for the life of
-- the machine; the court's own instrument ends the boot once the verdict
-- is in (stzos init --halt-on-verdict, on the emulator's line only)
-- ... and keeps saying it: the machine declares HEALTH 5, so PID 1
-- feeds the board's watchdog only while this path stays fresh, and a
-- trial commits only after one full window of it (HLT-1)
while true do
    sleep(1000)
    writefile("/run/kds.ready", "kds\n")
end
