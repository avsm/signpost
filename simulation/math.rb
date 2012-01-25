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
# NS records, the extra load on the root and intermediate name servers is
# independent of the number of signpost DNS requests made.
# For this reason I am not modeling the increase of requests as seen by the
# root or name servers.
# 
# On the other hand, all signpost requests will pass through local resolvers
# that either recursively resolve the requests, or proxy them to another
# resolver. It is therefore interesting to see the increase in DNS requests
# that occurr as results of different quantities and configurations of signpost
# deployments.
#
# --------------------------------------------------------------------------
# Simplifying assumptions:
#
# - Assumption 1: The number of devices per user is the same system wide.
#   Justification: As long as the number of devices is an upper bound, this
#     provides a safe over estimation.
#
# - Assumption 2: The number of devices behind each resolver (or proxy) is the same.
#   Justification: The increase in traffic is proportional to the number of
#     devices behind a resolver, but since resolvers also have processing capacity
#     proportional to the number of devices they are supposed to front, they will
#     see the same proportional increase in traffic, which should not cause
#     problems, assuming the remaining infrastructure can handle it.
#
# - Assumption 3: All a users signposts are spread behind different resolvers.
#   Justfication: We are considering the case where all signposts synchronize
#     directly with one of the publicly accessible signposts, and not at the edge
#     amongst each other. This is a worst case scenario in terms of the
#     amount of traffic, providing an upper bound. Since all communication
#     happens with a public signpost, the placement of individual signposts
#     becomes irrelevant.
#
# - Assumption 4: All users have friends they communicate with, and communicate
#     with each one in different amounts. We use the simplifying assumption
#     that all signposts on average receive the same amount of requests from
#     foreign signposts.
#   Justification: Since all the signposts are spread out evenly behind different 
#     resolvers, and all signposts speak to different friends at the same time, 
#     the amount of traffic a signpost receives from foreign domains averages
#     out. 
#
# - Assumption 5: A signpost request costs four times as much as a regular DNS
#     request.
#   Justification: TCPDumps from requests made of typical signpost DNS requests
#     sent over iodine, show that a single request regularly produce 3 iodine DNS
#     requests. Using 4 is a safe overestimation.
#     A typical signpost request in this case is a request using the signpost
#     DNS extensions of including amongst other a TXT record with the addresses
#     of the requester as well as KEY material and TSIG records.
#   Implication:
#     sp_dns_cost_multiple = 4
#
# - Assumption 6: Iodine tunnels have a fixed overhead of 1 packet per signpost
#     device per 4 seconds.
#   Justification: Empirical measurments verify this.
#   Implication:
#     packets_per_second_for_iodine_maintenance = 1/4
#
# - Assumption 7: One signpost request causes requests of equal size to be
#     generated to each of the other signpost devices in the domain to sync
#     state.
#   Justification: This is a safe overestimation, as given the same data, all
#     signposts can calculate the same changes and maintain the same state.
#   Implication:
#     ratio_sync_to_request = 1
#
# - Assumption 8: There is an even load generated across the board, that is
#     irrespective of which signpost domain or device the traffic is generated
#     from.
#   Justification: We are assuming all signposts create the same amount of DNS
#     traffic. This might not be true, but by setting the amount of traffic
#     generated sufficiently high, this is a safe overestimation.
#
# - Assumption 9: Instead of looking at individual signpost domains requests and
#     replies, we can generalise across all signpost domains, and just use the
#     fraction of signpost enabled devices that are at the edge.
#   Justification: By the assumption above that all signpost devices generate
#     an even load, we have that the magnitude of the load is irrespective of
#     which signpost domain the requester is in. This is because all devices,
#     irrespective of domain generate this average amount of traffic, which
#     also implies that all devices, irrespective of domain, will receive the
#     same amount of incoming sync traffic.
#
# - Assumption 10: One signpost contacting a singpost in another domain causes
#     a state broadcast in both signpost domains. More specifically the
#     increase in synchronisation traffic is by a factor of two.
#   Justification: setting up a tunnel to a foreign signpost causes tunnels
#     to be set up in both signpost domains. Hence a broadcast or sync of
#     state will also occurr in both domains. Since the material synchronized
#     in both domains is of the same nature, the order of magnitude of the 
#     traffic overhead is the same in both domains. Hence the factor of two.
#
# - Assumption 11: We can safily ignore the factor of two in increase of sync
#     overhead generated by requests to external signpost domains.
#   Justification: From Assumption 8 we know that each signpost device
#     generates the same amount of outwards traffic. From Assumption 4 we know
#     that the amount of external traffic a signpost receives also is
#     irrespective of the individual signpost. This allows us to swallop up the
#     increased cost of synchronisation for foreign requests in the constant
#     that relates the cost of a signpost request to the cost involved in
#     syncing said request.
#   Implication: existance of variable ratio_sync_to_request
#
# - Assumption 12: It doesn't matter how many signposts an individual user has.
#     The only thing that matters is what percentage of devices are signposts.
#   Justification: Since we are making the simplifying assumptions that all
#     a users devices are between different resolvers (Assumption 3), and also
#     that the traffic generated in a sense is irrespective of the users device
#     (Assumption 8), the number of signposts each individual user has does not
#     matter. On the other hand, the percentage of signposts system wide
#     matters, as it determines the fraction of extra traffic that is
#     generated.
#


def gen_load(options)
  # Devices per router
  dpr = options[:dpr] || 10

  # Devices per user
  dpu = options[:dpu] || 2

  # Fraction of all clients that are signposts
  fsp = options[:fsp] || 0.2

  # Fraction of a users signpost that is in the cloud
  fspc = options[:fspc] || 0.8

  # How much more a signpost request
  # costs compared to a normal DNS request, i.e. how many DNS packets are sent
  # over iodine per request a signpost makes. Such a request will include keys
  # and TSIGs etc.
  sp_dns_cost_multiple = 4

  # How much signpost traffic there is compared to DNS traffic
  amount_of_signpost_traffic = options[:amount_of_signpost_traffic] || 0.3

  # Load of DNS, i.e. how many requests per second per device.
  # Is divided out, so should't matter. Unfortunately due to floating point
  # rounding errors it does slightly change the final outcome.
  dns_load = 1_000_000

  # Amount of data that has to be sync'ed per signpost device compared to the
  # amount of data sent out in a signpost request.
  ratio_sync_to_request = options[:ratio_sync_to_request] || 1

  # Packets sent per second to maintain an iodine tunnel
  packets_per_second_for_iodine_maintenance = 1.0/4

  #-------------------------------------------------------------

  # The number of signposts.
  num_sp = dpr * fsp

  # Signposts at edge
  # Number of devices at the router, minus the ones that are in the cloud.
  # TODO: FOR FUTURE
  #   We should be considering percentage of machines that are signposts.
  #   That results in the following equations:
  #
  #     num_sp = (edge_not_sp + sp_edge + sp_cloud) * fsp
  #     edge_not_sp = dpr - sp_edge
  #     sp_cloud = num_sp * frCloud
  #     sp_edge = num_sp - sp_cloud
  #
  #   Solving is an exercise for the reader.
  #
  sp_edge = dpr - (dpu * fspc)

  # Overhead caused by iodine is one packet every 4 seconds per signpost device
  # at the edge
  iodine_overhead = packets_per_second_for_iodine_maintenance * sp_edge

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

  # The overhead generated by signpost communication. It has two parts:
  # Internal communication: A device has contacted another device in the same
  #     signpost domain to propagate some state, for example that it has moved
  #     and is now addressable using a different address. This information then
  #     has to be propagated to all other signposts in the same domain.
  # External communication: A device contacts a different signpost domain to
  #     have it setup a tunnel between the domains. This causes traffic to be
  #     generated in both signpost domains. In both cases all signposts in both
  #     domains are informed about new tunnels having/being set up, and other
  #     related information.
  # The external communication is greater by a factor of two, since it is
  # involving the devices in both signpost domains.
  # But since we have no clear idea of the relationship between internal and
  # external traffic, we leave it out.
  # IS THIS SOUND?
  sync_overhead = signpost_requests_cost * sp_edge * ratio_sync_to_request

  # The load when signpost systems are in use
  resolver_signpost_load = resolver_base_load +
                           iodine_overhead +
                           signpost_requests_cost +
                           sync_overhead

  extra_load = resolver_signpost_load.to_f / resolver_base_load

  return extra_load
end

options = {
  :dpr => 100, # Devices per resolver
  :dpu => 2, # Devices per user
  :fspc => 0.8, # Fraction of a users signposts that are in the cloud
  :amount_of_signpost_traffic => 3, # How many times the normal DNS load is generated by singposts
  :ratio_sync_to_request => 1 # How much more heavy a sync message is compared to a signpost request
}

# We want data for three scenarios,
# start:        every user has two signpost devices
# intermediate: every user has 10 signpost devices
# domination:   every user has 100 signpost devices
File.open("sim.csv", "w") do |f|
  
  num_signposts = [2] + (5..100).step(5).to_a
  f.puts "perc_in_cloud\t#{(num_signposts.map {|l| "perc_sp_#{l}"}).join("\t")}"

  # We now want to see what happens as more and more of the signposts
  # move from the cloud and to the edge
  100.downto(1).each do |percent|
    options[:fspc] = percent / 100.0

    f.print "#{percent}\t"

    num_signposts.each do |num|
      options[:dpu] = num
      extra_load = gen_load options
      f.print "#{extra_load}\t"

    end
    f.print "\n"

  end
end
