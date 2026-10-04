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

RingServ([
    :port = 8210,
    :announce = 0,
    :workers = 2,
    :database = "/data/ringserv.db",
    :services = [
        :hello = [
            :greet = func oReq {
                return Reply(:ok, [ :message = "Ahlan from a declared machine" ])
            }
        ]
    ]
])
