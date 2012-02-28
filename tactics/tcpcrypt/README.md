Get the source from: 

    git clone git://github.com/sorbo/tcpcrypt.git

In order to compile on Ubuntu, you need the following dependencies

    sudo apt-get install libnfnetlink-dev libnetfilter-queue-dev libcap-dev

To compile

    cd tcpcrypt/user
    ./configure
    make

To run

    cd tcpcrypt/user
    sudo ./launch_tcpcryptd.sh

To verify that it is running:
In one window:

    sudo tcpdump -X -s0 host tcpcrypt.org

In another window:

    curl tcpcrypt.org

Inspect that the output is indeed encrypted.

Remember:
When running iperf or whatever mechanism to test TCPCrypt, make sure it does
evaluate TCP and not UDP :)


How tcpcrypt works
==================

Tcpcrypt abstracts away authentication, allowing any mechanism to be used, whether PKI, passwords, or something else (i.e. might be less complex than SSL, VPN, etc.) and is suppsoedly up to 25x times faster than SSL, although weaker by default. It relies on public key encryption protocol to exchange shared secrets, but the keys are short-lived and get refreshed periodically.

To establish shared session keys, tcpcrypt requires one host to encrypt a secret value with the second host's public key.  The second host must subsequently use its private key to decrypt this value.

Tcpcrypt maintains the confidentiality of data transmitted in TCP segments against a passive eavesdropper.
Tcpcrypt is designed to require relatively low overhead, particularly at servers.

Since tcpcrypt "requires no configuration and has a mechanism for probing support that can fall back to TCP gracefully", the details of how the key exchange protocol works are given below out if interest and possible reuse in other scenarios.

Important aside:
_Which role a host plays can have performance implications, because for some public key algorithms encryption is much faster than decryption.  For instance, on a machine at the time of writing, encryption with a 2,048-bit RSA-3 key costs 82 microseconds, while decryption costs 10 milliseconds._


tcpcrypt key exchange protocol
------------------------------

Every machine C has a short-lived public encryption key, K_C, which gets refreshed periodically and SHOULD NOT ever be written to persistent storage.

When a host C connects to S, the two engage in the following protocol:

    C -> S:  HELLO
    S -> C:  PKCONF, pub-cipher-list
    C -> S:  INIT1, sym-cipher-list, N_C, K_C
    S -> C:  INIT2, sym-cipher, ENC (K_C, N_S)
    
Here:

* pub-cipher-list is a list of public key ciphers and key lengths acceptable to the server
* sym-cipher-list specifies the symmetric cipher suites acceptable to the client
* N_C is a nonce chosen at random by C
* K_C is C's public encryption key, which MUST match one of the entries in pub-cipher-list
* sym-cipher is the symmetric cipher suite chosen by the server from sym-cipher-list.
* N_S is a "pre-session seed" chosen at random by S.


The two sides then compute a series of "session secrets" and corresponding Session IDs as follows:

    param := { pub-cipher-list, sym-cipher-list, sym-cipher }
    ss[0] := CPRF (N_S, { K_C, param, N_C })
    ss[i] := CPRF (ss[i-1], TAG_NEXTK)
    SID[i] := CPRF (ss[i], TAG_SESSID)

Here CPRF is _collision-resistant pseudo-random function_.

The value ss[0] is used to generate all key material for the current connection.  SID[0] is the session ID for the current connection.

tcpcrypt hooks
--------------

After opening a TCP socket, the following new options should be available from the getsockopt:

* TCP_CRYPT_SESSID -> should return the session ID or error if no tcpcrypt.
* TCP_CRYPT_SUPPORT -> returns 1 if the remote application is tcpcrypt-aware.


A more complete of options for getsockopt/setsockopt follows:

The getsockopt call should have new options for IPPROTO_TCP:

* TCP_CRYPT_SESSID -> should return the session ID or error if no tcpcrypt.
* TCP_CRYPT_PUBKEY -> should return (mine, pubkey), where pubkey is the public key used to establish the session (K_C), and mine says whether the key belongs to this host or the remote peer.
* TCP_CRYPT_CONF -> returns encryption algorithms used for the current session.
* TCP_CRYPT_SUPPORT -> returns 1 if the remote application is tcpcrypt-aware.


The setsockopt call should have:

* TCP_CRYPT_CACHE_FLUSH -> setting wipes cached session keys. Useful if application-level authentication discovers a man in the middle attack, to prevent the next connection from using NEXTK.

The following options should be readable and writable with getsockopt and setsockopt:

* TCP_CRYPT_ENABLE -> one bit, enables or disables tcpcrypt extension on an unconnected (listening or new) socket.
* TCP_CRYPT_SECURST -> one bit, means ignore unauthenticated RST packets for this connection when set to 1.
* TCP_CRYPT_CMODE_{DEFAULT,NEVER,ALWAYS}[_NK] -> As described in the RFC
* TCP_CRYPT_PKCONF -> set of allowed public key algorithms and CPRFs this host advertises in CRYPT PKCONF suboptions.
* TCP_CRYPT_CCONF -> set of allowed symmetric ciphers and message authentication codes this host advertises in CRYPT INIT1 segments.
* TCP_CRYPT_SCONF -> order of preference of symmetric ciphers. 
* TCP_CRYPT_SUPPORT -> set to 1 if the application is tcpcrypt-aware. set to 2 if the application requires the remote application to be tcpcrypt-aware.