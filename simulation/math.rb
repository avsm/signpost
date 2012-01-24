# Analysis of increase in DNS traffic as a result of deploying signposts in
# existing infrastructure.
#
# The following analysis makes a set of assumptions. I will state them below.
#
# --------------------------------------------------------------------------
# "The reason for the scalability of DNS are due less to the hierarchical
# design of its name space or good A-record caching than seems to be widely
# believed; rather the cacheabilit of NS records efficiently partition the name
# space and avoid overloading any single name server in the Internet"
# - DNS Performance and the Effectiveness of Caching [2002 IEEE]
#
# Signpost requests all happen within a domain. Because of the heavy caching of
# NS records, the extra load on the root and intermediate name servers, is
# greatly independent of the number of signpost DNS requests made.
# For this reason I am not modeling the increase of requests as seen by the
# root servers, or name servers up the chain.
# 
# All signpost requests will on the other hand pass through local resolvers
# that either recursively resolve the requests, or proxy them to another
# resolver. It is therefore interesting to see the increase in DNS requests
# that occurr as results of different quantities and configurations of signpost
# deployments.
#
# --------------------------------------------------------------------------
# Simplifying assumptions:
#
# - Assumption: The number of devices per user is the same system wide.
#   Justification: As long as the number of devices is an upper bound, this
#   provides a safe over estimation.
#
# - Assumption: The number of devices behind each resolver (or proxy) is the same.
#   Justification: The increase in traffic is proportional to the number of
#   devices behind a resolver, but since resolvers also have processing capacity
#   proportional to the number of devices they are supposed to front, they will
#   see the same proportional increase in traffic, which should not cause
#   problems, assuming the remaining infrastructure can handle it.
#
# - Assumption: All a users signposts are spread behind different resolvers.
#   Justfication: We are considering the case where all signposts synchronize
#   directly with one of the publicly accessible signposts, and not at the edge
#   amongst each other. This is a worst case scenario in terms of the
#   amount of traffic, providing an upper bound. Since all communication
#   happens with a public signpost, the placement of individual signposts
#   becomes irrelevant.
#
# - Assumption: All users have friends they communicate with, and communicate
#   with each one in different amounts. Since all the signposts are spread
#   out evenly behind different resolvers, and all signposts speak to different friends
#   at the same time, the assumption is made that this averages out amongst the
#   resolvers.
#   Justification: ?
#
# - Assumption: A signpost request costs four times as much as a regular DNS
#   request.
#   Justification: TCPDumps from requests made of typical signpost DNS requests
#   sent over iodine, show that a single request regularly produce 3 iodine DNS
#   requests. Using 4 is a safe overestimation.
#
# - Assumption: Iodine tunnels have a fixed overhead of 1 packet per signpost
#   device per 4 seconds.
#   Justification: Empirical measurments verify this.
#
# - Assumption: One signpost request causes requests of equal size to be
#   generated to each of the other signpost devices in the domain to sync
#   state.
#   Justification: This is a safe overestimation, as given the same data, all
#   signposts can calculate the same changes and maintain the same state.
#
# - Assumption: One signpost contacting a singpost in another domain causes
#   a state broadcast in both signpost domains.
#   Justification: setting up a tunnel to a foreign signpost causes tunnels
#   ends to be set up in both signpost domains. Hence a broadcast or sync of
#   state will occurr. Setting this to be the same as the size of the message
#   is again a safe overestimation.
#


# Devices per router
dpr = 10

# Devices per user
dpu = 2

# Fraction of a users signpost that is in the cloud
fspc = 0.8

# How much more a signpost request
# costs compared to a normal DNS request, i.e. how many DNS packets are sent
# over iodine per request a signpost makes. Such a request will include keys
# and TSIGs etc.
sp_dns_cost_multiple = 4

# How much signpost traffic there is compared to DNS traffic
amount_of_signpost_traffic = 0.3

# Load of DNS, i.e. how many requests per second per device.
# Is divided out, so should't matter. Unfortunately due to floating point
# rounding errors it does slightly change the final outcome.
dns_load = 1_000_000

# Fraction of signpost communication that is internal, i.e. trying to establish
# routes to other internal signposts, vs communication that is against
# signposts in other domains, i.e. trying to establish a tunnel with a foreign
# signpost.
fraction_internal = 0.5

#-------------------------------------------------------------

# Signposts at edge
# Number of devices at the router, minus the ones that are in the cloud.
sp_edge = dpr - (dpr * fspc)

# Overhead caused by iodine is one packet every 4 seconds per signpost device
# at the edge
iodine_overhead = 1.0/4 * sp_edge

# The normal load of DNS traffic
# Each device at the resolver sends out dns_load packages per second.
resolver_base_load = dpr * dns_load

# The cost of one signpost request, compared to a normal DNS request
# This is the amount one signpost request costs compared to a DNS request,
# times the number of DNS messages being sent, times the fraction of this
# traffic that comes from signposts.
sp_request_cost = sp_dns_cost_multiple * dns_load * amount_of_signpost_traffic

# The extra signposts requests caused by signposts
# Requests from signposts. This is a combination of requests to own signposts
# about setting up internal tunnels or proxies, and requests to other signposts
# about setting up tunnels to external signpost domains.
signpost_requests_cost = sp_edge * sp_request_cost

# The cost of the request sent to internal signposts.
internal_sp_requests_cost = signpost_requests_cost * fraction_internal

# Overhead from the internal communication from requests by signposts within
# the same domain. Since each signpost request going out is broadcast back to
# all the other signposts in the same domain, we have an additional message
# being sent to all the signposts at the edge on average per signpost sent
# message.
internal_sp_req_sync_overhead = internal_sp_requests_cost * sp_edge

# The cost of sending messages to foreign signposts is the total cost of
# signpost requests, minus the cost of the messages that are for internal
# communication.
foreign_sp_req_sync_cost = signpost_requests_cost - internal_sp_requests_cost

# Overhead of communicating with external signposts. Communication with
# external signposts is extra costly, because it causes sync traffic both
# within my own signpost domain, but also within the signpost domain of the
# signpost being contacted. Hence sp_edge^2
foreign_sp_req_sync_overhead = foreign_sp_req_sync_cost * sp_edge * sp_edge

# Overhead caused by keeping signposts in sync
sync_overhead = internal_sp_req_sync_overhead +  # sync resulting from internal communication
                foreign_sp_req_sync_overhead     # sync resulting from foreign signposts contacting us

# The load when signpost systems are in use
resolver_signpost_load = resolver_base_load +
                         iodine_overhead +
                         signpost_requests_cost +
                         sync_overhead

extra_load = resolver_signpost_load.to_f / resolver_base_load

puts "Load increases by a factor of: #{extra_load}"
