/*-*- Mode: C; c-basic-offset: 8; indent-tabs-mode: nil -*-*/

/***
  This file is part of nss-myhostname.

  Copyright 2008-2011 Lennart Poettering

  nss-myhostname is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public License
  as published by the Free Software Foundation; either version 2.1 of
  the License, or (at your option) any later version.

  nss-myhostname is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with nss-myhostname; If not, see
  <http://www.gnu.org/licenses/>.
***/

#include <sys/socket.h>
#include <sys/un.h>
#include <asm/types.h>
#include <inttypes.h>
#include <linux/netlink.h>
#include <linux/rtnetlink.h>
#include <string.h>
#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <inttypes.h>
#include <stdlib.h>
#include <stdio.h>

#include <unbound.h>

#include "ifconf.h"

int ifconf_acquire_addresses(const char *name, 
        struct address **_list, unsigned *_n_list) {

        struct {
                struct nlmsghdr hdr;
                struct rtgenmsg gen;
        } req;
        struct rtgenmsg *gen;
        int fd, r, on = 1;
        uint32_t seq = 4711;
        struct address *list = NULL;
        unsigned n_list = 0;
        struct ub_ctx* ctx;
        struct ub_result* result;
        int retval, i;

        //fprintf(stderr, "ifconf_acquire_addresses\n");

        /*  create context */
        ctx = ub_ctx_create();
        if(!ctx) {
            printf("error: could not create unbound context\n");
            retval = -1;
            goto finish;
        }

        //ub_ctx_debuglevel(ctx, 10);

        /*  read /etc/resolv.conf for DNS proxy settings (from DHCP) */
        if( (retval=ub_ctx_resolvconf(ctx, "/etc/resolv.conf")) != 0) {
            fprintf(stderr, "error reading resolv.conf: %s. errno says: %s\n", 
                    ub_strerror(retval), strerror(errno));
            //retval = errno;
            //goto finish;
        }

        /*  read /etc/hosts for locally supplied host addresses */
        if( (retval=ub_ctx_hosts(ctx, "/etc/hosts")) != 0) {
            fprintf(stderr, "error reading hosts: %s. errno says: %s\n", 
                    ub_strerror(retval), strerror(errno));
            //retval = errno;
            //goto finish;
        }
        /*  query for webserver */
        retval = ub_resolve(ctx, name, 
                1 /*  TYPE A (IPv4 address) */, 
                1 /*  CLASS IN (internet) */, &result);
        if(retval != 0) {
            fprintf(stderr, "error resolving: %s. errno says: %s\n", 
                    ub_strerror(retval), strerror(errno));
            retval = -ENOENT;
            goto finish;
        }

        if(!result->havedata) {
           //fprintf(stderr, "no response found\n"); 
            retval = -ENOENT;
            goto finish;
        }


        while(result->data[n_list]) {
            list = realloc(list, (n_list+1) * sizeof(struct address));
            if (!list) {
                retval = -ENOMEM;
                goto finish;
            }
                 struct in_addr in;
            in.s_addr = *(uint32_t *)result->data[n_list];
            fprintf(stderr, "found ip %s\n", inet_ntoa(in));
            list[n_list].family = AF_INET;
            list[n_list].scope = 1; //ifaddrmsg->ifa_scope;
            memcpy(list[n_list].address, result->data[n_list], 4);
            list[n_list].ifindex = 1; //ifaddrmsg->ifa_index;

            n_list++;
        }
        r= n_list;
        goto finish;
finish:
        close(fd);

        ub_resolve_free(result);
        ub_ctx_delete(ctx);

        if (r < 0)
            free(list);
        else {
            qsort(list, n_list, sizeof(struct address), address_compare);

            *_list = list;
            *_n_list = n_list;
        }
        //fprintf(stderr, "returned %d addr\n", n_list);

        return r;
}
