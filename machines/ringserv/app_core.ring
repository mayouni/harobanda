# app_core.ring -- the application RingServ serves on the CORE link of the
# smallest cloud (FWD-1): the same one service and one database as app.ring,
# and a server that listens where another machine can ask it.
#
# RingServ binds the loopback unless it is told otherwise, and refuses to bind
# an address a network can reach without being told that TLS is somebody else's
# job (its docs/TLS.md): it speaks plain HTTP and expects a proxy in front. The
# estate's arrangement is the proxy on loopback, and the proxy of this cloud is
# rung 3's front, which is not built. Until it is, :behindproxy below is an
# ACKNOWLEDGEMENT and not a fact: RingServ cannot check that a proxy exists, and
# neither does anything here. What IS true, and is what the pinned boot shows, is
# the extent -- the server is reachable from the front link and nothing else,
# through a box that forwards between the two and filters nothing, over plain
# HTTP, between members of one cloud. No request from outside the cloud can reach
# it, because nothing outside the cloud is on either link.
#
# :announce = 0 refuses the family handshake, a UDP broadcast that has no place
# on a machine whose reach is declared. :workers is explicit so that the count a
# transcript quotes does not depend on how many CPUs the emulator was given.

RingServ([
    :port = 8210,
    :host = "0.0.0.0",
    :behindproxy = true,
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
