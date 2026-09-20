--!nonstrict
-- judge_machine_stzu.luau -- the machine language, declared in stzu, judged
-- by stz's own meta-court. Run from D:\GitHub\stz (the stzr runner resolves
-- `@stz/` and readfile against its working directory):
--
--   zig-out\bin\stzr.exe ..\harb\experiment\judge_machine_stzu.luau
--
-- Nothing is forked: the judge is stz's face/stz/Stzu.luau as it stands.

local Stzu = require("@stz/Stzu")

local src = readfile("../harb/declarative/machine/machine.stzu")
local ok, L = pcall(Stzu.declare, src)
if not ok then
    print("machine.stzu -- REFUSED by stz's meta-court: " .. tostring(L))
    error("machine.stzu refused")
end

print(("machine.stzu -- language %s v%s, grammar %s, court %s, extension %s"):format(
    L.name, L.version, L.grammar, L.court, L.extension))
print(("  declarations %d, forms %d, expressions %d, refusals %d"):format(
    #L.declarations, #L.forms, #L.expressions, #L.refusals))
local verbs = {}
for _, d in L.declarations do
    table.insert(verbs, d.verb)
end
table.sort(verbs)
print("  verbs: " .. table.concat(verbs, ", "))

assert(L.name == "machine", "language name")
assert(#L.declarations == 7, "seven declarations: MACHINE SERVICE CAPABILITY MOUNT PIN NETWORK USER")
assert(#L.forms == 5, "five forms: word need dependency option server")
assert(#L.expressions == 0, "a machine declares; it computes nothing")
assert(#L.refusals == 3, "three refusal phrasings declared")
assert(table.concat(verbs, ",") == "CAPABILITY,MACHINE,MOUNT,NETWORK,PIN,SERVICE,USER", "the verb set")
print("machine.stzu -- accepted by stz's meta-court, shape as declared")
