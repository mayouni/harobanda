# app.ring -- the smallest application the cloud's first server world serves.
#
# One service and one database: enough for the machine to prove what it
# promises a server (a port, a store that survives the power, a readiness
# that is measured) and nothing it would have to invent. The real
# application is RestoLean's Commons, and it is that desk's to hand over;
# this file stands in for it the way the Luau worlds stand in for the box's
# (SRV-1), and says so.
#
# :announce = 0 refuses the family handshake, a UDP broadcast that has no
# place on a machine whose reach is declared. :workers is explicit so that
# the count a transcript quotes does not depend on how many CPUs the
# emulator was given.
#
# The database is RELATIVE on purpose: RingServ puts a relative database in the
# directory `--data` names and keeps an absolute one where it was written, so the
# machine says where the server's directory is (STATE, and the --data of the pack's
# RUN) and this file says only what the database is called. The server runs as an
# identity of its own (OWN-1), and that directory is the one place it can write.
#
# No table is declared, on purpose. RingServ waits 2000 ms for a worker to come up
# and then refuses to serve, and a table created at startup took longer than that
# under the emulator -- measured, as root and as the identity alike -- so the
# database file exists only once something writes to it, and a boot of this machine
# does not show it. That the server keeps its database in that directory as an
# unprivileged user was measured outside the machine instead (experiment/PROTOCOL.md,
# OWN-1).

RingServ([
    :port = 8210,
    :announce = 0,
    :workers = 2,
    :database = "ringserv.db",
    :services = [
        :hello = [
            :greet = func oReq {
                return Reply(:ok, [ :message = "Ahlan from a declared machine" ])
            }
        ]
    ]
])
