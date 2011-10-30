#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <assert.h>
#include <netdb.h>
#include <sys/socket.h>
#include <nss.h>
#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>

typedef struct {
        uint32_t address;
} ipv4_address_t;

typedef struct {
        uint8_t address[16];
} ipv6_address_t;

enum nss_status _nss_signpost_gethostbyname2_r(
        const char *name,
        int af,
        struct hostent * result,
        char *buffer,
        size_t buflen,
        int *errnop,
        int *h_errnop) {

    enum nss_status status = NSS_STATUS_UNAVAIL;

    int i, addr_count = 1;
    size_t address_length, l, idx, astart;
    uint32_t ip = ntohl(inet_addr("1.2.3.4"));

//    if (af == AF_UNSPEC)
//#ifdef NSS_IPV6_ONLY
//        af = AF_INET6;
//#else
    af = AF_INET;
//#endif

//#ifdef NSS_IPV4_ONLY
//    if (af != AF_INET)
//#elif NSS_IPV6_ONLY
//        if (af != AF_INET6)
//#else
//            if (af != AF_INET && af != AF_INET6)
//#endif
//            {
 //               *errnop = EINVAL;
//                *h_errnop = NO_RECOVERY;
//
//                goto finish;
//            }

    address_length = af == AF_INET ? sizeof(ipv4_address_t) : sizeof(ipv6_address_t);

    if (buflen <
            sizeof(char*)+    /*  alias names */
            strlen(name)+1)  {   /*  official name */

        *errnop = ERANGE;
        *h_errnop = NO_RECOVERY;
        status = NSS_STATUS_TRYAGAIN;

        goto finish;
    }

    /* Alias names */
    *((char**) buffer) = NULL;
    result->h_aliases = (char**) buffer;
    idx = sizeof(char*);

    /* Official name */
    strcpy(buffer+idx, name); 
    result->h_name = buffer+idx;
    idx += strlen(name)+1;

    result->h_addrtype = af;
    result->h_length = address_length;

/*  /* Check if there's enough space for the addresses 
    if (buflen < idx+u.data_len+sizeof(char*)*(u.count+1)) {
        *errnop = ERANGE;
        *h_errnop = NO_RECOVERY;
        status = NSS_STATUS_TRYAGAIN;
        goto finish;
    }
*/
    /* Addresses */
    astart = idx;
    l = addr_count*address_length;
    memcpy(buffer+astart, &ip, l);
    //l = u.count*address_length;
    //memcpy(buffer+astart, &u.data, l);
    /* address_length is a multiple of 32bits, so idx is still aligned
     * correctly */
    idx += l;

    /* Address array address_lenght is always a multiple of 32bits */
    for (i = 0; i < addr_count; i++)
        ((char**) (buffer+idx))[i] = buffer+astart+address_length*i;
    ((char**) (buffer+idx))[i] = NULL;
    result->h_addr_list = (char**) (buffer+idx);
    status = NSS_STATUS_SUCCESS;
finish:
    return status;

}

enum nss_status _nss_signpost_gethostbyname_r (
        const char *name,
        struct hostent *result,
        char *buffer,
        size_t buflen,
        int *errnop,
        int *h_errnop) {
    return _nss_mdns_gethostbyname2_r(
            name,
            AF_UNSPEC,
            result,
            buffer,
            buflen,
            errnop,
            h_errnop);


}

enum nss_status _nss_signpost_gethostbyaddr_r(
        const void* addr,
        int len,
        int af,
        struct hostent *result,
        char *buffer,
        size_t buflen,
        int *errnop,
        int *h_errnop) {

    //struct userdata u;
    enum nss_status status = NSS_STATUS_UNAVAIL;
    return status;
}

