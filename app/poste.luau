--!nonstrict
-- poste.luau -- the counter world of the Makeen box, as a DAEMON.
--
-- It comes AFTER the kitchen display, and since 2026-09-13 that means
-- after the display SIGNALLED it is serving, not after it started: PID 1
-- holds this world until /run/kds.ready exists. So this file may assume
-- the display is up, and says so.
--
-- Like its sibling it says where it runs, signals that it is serving by
-- creating its declared path, and then stays alive. A real counter world
-- waits on orders; this one waits on the clock, because a stand-in must
-- not pretend to serve what it cannot serve.

print("poste: the counter world is up on the Makeen box, after kds")
print("poste: /data is the box's persistent partition, mounted by PID 1 before any world spoke")

print("poste: serving -- signalling /run/poste.ready")
writefile("/run/poste.ready", "poste\n")

while true do
    sleep(1000)
end
