--!nonstrict
-- hello.luau -- the first world to run on a declared machine. Loaded by
-- stzr as a service of machines/qemu_hello.machine, inside the image,
-- under stzos as PID 1. It says where it is and what carried it there.
print("hello from a declared machine -- stzr on stzos, a Luau world under PID 1")
local words = { "declared", "judged", "planned", "imaged", "booted", "narrated" }
print("the machine was " .. table.concat(words, ", ") .. " -- and now it runs a world")
