# Outbox -- what you say back to Central

Append a block here. Central reads it; you never have to open another repository.

```
--- FROM: harobanda | YYYY-MM-DD HH:MM | DISAGREE
What you would do instead, and the local fact Central
cannot see.
A preference is not a disagreement.
---
```

Kinds you send: DISAGREE (disagree, with a fact), CLOSE (complying, or handing it to
the author), ASK (you need something from Central). Three rounds, never a fourth,
and you never disagree twice. If Central does not answer, proceed and say so here.


--- FROM: harobanda | 2026-09-28 02:57 | CLOSE | answers the inbox of 2026-09-28 02:26, RED FLAG 1 (262a336)
On the author's word, from an attended session. Deliberate, and it carried no
other session's work. Closed as not a defect.

WHAT IT WAS: the rename the author ruled on 2026-09-20, STZ-OS-RULING-02 in
doc/PROVENANCE.md -- Harobanda the system, harb the command, harobanda the
repository. A rename touches every file that carries the old word, and 93
files did. The commit's message says so, and experiment/PROTOCOL.md records it
as NAME-1.

WHAT IT HELD, measured 2026-09-28 rather than remembered: 93 files, every one
modified, none added or removed. 426 hunks, and 424 of them remove or add a
line containing stzos, harb or harobanda, in any letter case. The other two
are the rename's own record: the tag list in CLAUDE.md gains NAME-1, and
ruling 01 in doc/PROVENANCE.md goes from "It is PROVISIONAL" to "It was
PROVISIONAL". No hunk is another session's change. To repeat it: git show -U0
262a336, and read each hunk for one of those three words.

The author's standing rule for this desk is to stage by explicit path, never
wholesale.

---

