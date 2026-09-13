--!nonstrict
-- modest.luau -- a world that stays inside its ceiling.
--
-- Its machine grants it 64 MiB and half a core. It takes 8 MiB, says so,
-- and ends. Nothing in the transcript mentions the budget afterwards,
-- and that silence is the point: a ceiling that holds is a ceiling
-- nobody hears about (BDG-1).

print("modest: this world was granted 64 MiB and half a core")

local hold = {}
for i = 1, 8 do
    -- a fresh mebibyte each time: a repeated string would be one object
    table.insert(hold, string.rep("m", 1024 * 1024) .. tostring(i))
end

print(("modest: %d MiB held, well inside the ceiling -- the kernel never had to intervene"):format(#hold))
