# Tactic Solver

The tactic solver knows a set of truths about the current state of the
world, and also has a set of tactics for generating new truths as needed.

Truths are evaluated lazily on request, but the results will be cached if
permitted (TTL > 0).

A truth can be any kind of value associated with a key. It could for example be a boolean
value indicating whether a port can be opened on a host machine or not, a list of
IP's, a public-key, or any other kind of data.

Each truth has the following set of information associated with it:

- The name of the truth (*resource*)
- The domain the truth is about (*domain*)
- The holder of the truth (which node believes the truth to hold) (currently not implemented) (*holder*)
- Information about the user requesting the truth (*user*)
- The name of the tactic that provided the truth (*source*)
- When the truth expires (*expires*)
- And the value of the truth itself (*value*)

Truths are expressed as: RESOURCE@DOMAIN[:PORT] (*what*)


# Examples

To make it more concrete, let us take a look at some examples. The following examples are
run on a tactic solver instance on node Alpha.


## Resolving name using DNS

We want to resolve domain name www.kle.io into its IP-addresses. 
The truth-resource we want to resolve could in this case be called **ip_for_domain** (*resource*). The
domain the truth is about is www.kle.io (*domain*). The truth can therefore be expressed
as **ip_for_domain@www.kle.io** (*what*).

Let us assume there is a tactic called DNS that provides this kind of truth. 
The truths returned by DNS would have **DNS** as their source (*source*).

Once the DNS-tactic has resolved the domain name into a DNS record, it returns the truth to the general pool of truths. The value of the truth (*value*) would be the IP-addresses of www.kle.io. The domain (*domain*) the truth is about would be www.kle.io. With the exception of services like content distribution networks, the result of a DNS requests do not depend on the user issueing the request. The information about the requesting user (*user*) would therefore be set to **ALL**, and the section about which node holds the truth (*holder*) would be set to **GLOBAL** to indicate that the truth holds on any signpost node. The truth would be set to expire (*expires*) with the same TTL as the DNS record.


## Checking if Alpha can connect to Beta on TCP port 5000

This would be a set of truths. One whether Alpha can make an outwards TCP
connection (tcp_out@Alpha:5000 (*what*)), and one whether it can connect to beta on port
5000 (tcp_in@Beta:5000 (*what*)). In both cases the truth is held by Alpha (*holder*). While other signposts nodes also see the truth, they know that while Alpha can connect to
Beta, the same might not be the case for themselves.

Again the information about which user is issuing this request (*user*) could in this case be set to **ALL** to indicate that it is irrespective of the requesting user.

The value (*value*) of the truths are in both cases boolean values, yes or no.


## Resolving MacbookA.kle.io in a separate signpost domain

MacbookA is a machine in a separate signpost domain of our own.
On node Alpha we try to resolve **ip_for_domain@macbooka.kle.io**. The regular DNS tactic fails, but we also have a signpost tactic which also provides **ip_for_domain**'s. It will in turn try to resolve **signpost_for_domain@macbooka.kle.io** which is resolved by another tactic. Once it knows which signpost is responsible for MacbookA, it will contact it
directly to get an IP address for the signpost.

In this case the user information contains information about the device trying
to connect to MacbookA. This allows the receiving signpost system to determine
if it should allow the resolution of the name or not.


## Resolving MacbookB.probsteide.com in own signpost domain for a remote user

A remote client (Client.remote.com) in a separate signpost domain tries to resolve MacbookB in our signpost domain. One of Client's signposts have issued an **ip_for_domain@macbookb.probsteide.com** (*what*) (*resource*: ip_for_domain, *user*: client.remote.com, *domain*: macbookb.probsteide.com) request using our signpost interface.

In order to determine if the client should be granted access to MacbookB, the signpost tactic might wish to kknow Client's public-key. It therefore asks for the truth of **pub-key@client.remote.com**, which is resolved by some other tactic, or returned immediately if already known.

Once it has the accessors public-key and can verify the Client's identity, it
might verify that **access_client.remote.com@macbookb.probsteide.com** is true.
If so it returns an IP that is connectible by the remote system, courtesy of
yet another tacitc.
