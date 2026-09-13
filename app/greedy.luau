--!nonstrict
-- greedy.luau -- a world that asks for more than it was granted.
--
-- Its machine grants it 32 MiB. It allocates a mebibyte at a time until
-- the kernel stops it: the memory controller kills this process inside
-- this world's own group, with a signal nothing can catch, and the world
-- beside it never feels a thing. PID 1 reaps it, applies the declared
-- restart policy, and after five tries says so and carries on.
--
-- The bound below is not the ceiling -- the kernel's is. It is this
-- file's own honesty: if the budget were NOT held, an unbounded loop
-- would eat the whole machine and the transcript would show a hang
-- instead of a finding. With the bound, a ceiling that failed to hold
-- says so in one line, and the court reads a fact either way (BDG-1).

print("greedy: this world was granted 32 MiB, and is about to ask for far more")

local hold = {}
while #hold < 512 do
    table.insert(hold, string.rep("g", 1024 * 1024) .. tostring(#hold))
end

print(("greedy: %d MiB held and nothing stopped it -- THE CEILING DID NOT HOLD"):format(#hold))
