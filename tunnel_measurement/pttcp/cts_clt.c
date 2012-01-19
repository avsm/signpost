/***********************************************************************
 * 
 * $Id: cts_clt.c,v 2.0 2000/05/03 20:26:34 rmm1002 Exp $
 *
 */

/* (C) Cambridge University Computer Laboratory, 2000
 *     All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by the Systems Research
 *      Group at Cambridge University Computer Laboratory.
 * 4. Neither the name of the University nor of the Laboratory may be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/time.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <unistd.h>

#include "trc.h"
#include "pttcp.h"
#include "pttcp_util.h"

extern state_t state[__FD_SETSIZE];
extern fd_set  fds_zero;
extern double  scalar;
extern int     maxfd;
extern int     verbose;

/*********************************************************************
 * keep n connections open continuously; request `bytes' bytes each
 * time 
 */
void
continuous_client(int n, int bytes, char *host, int num_ports, int base_rx_port)
{
    int i;
    fd_set fds_new, fds_active, fds_finished;
    unsigned long ipaddr;
    double tmbs=0;

    ipaddr = host2ipaddr(host);

    FD_ZERO(&fds_new);
    FD_ZERO(&fds_active);
    FD_ZERO(&fds_finished);

    /* create all the TCP connections */
    for(i=0; i<n; i++)
    {
	int fd = create_tx_tcp(ipaddr, base_rx_port+(i%num_ports));
	struct timeval tp={ 0, 0 };

	if(fd < 0)
	{
	    printf("Unable to open connection!\n");
	    exit(-1);
	}
	if(fd > maxfd) 
	{
	    maxfd = fd;
	}

	state[fd].tx_target = bytes;
	state[fd].tx_sent   = 0;
	state[fd].tx_pkts   = 0;
	state[fd].rx_rcvd   = 0;
	FD_SET(fd, &fds_new);

	tp.tv_usec = rand()%10000;

	select(0, &fds_zero, &fds_zero, &fds_zero, &tp);
    }

    /* start sending */
    while(1)
    {
	int s, fd, rc;
	struct timeval tdiff;

	send_request(&fds_new, &fds_active);
	rc = sink_data(&fds_active, &fds_finished);

	/* close those that have finished */
	for(s=0; 
	    (rc>0) && (fd = FD_FFSandC(s, maxfd, &fds_finished));
	    s = fd+1)
	{
	    double mbs;
	    int new_fd;

	    tvsub(&tdiff, &state[fd].rx_stop, &state[fd].rx_start);
	  
	    mbs = (double)(8.0*state[fd].rx_rcvd) /
		(double)(tdiff.tv_sec*1.e6 + tdiff.tv_usec);

	    tmbs += mbs;

	    fprintf(stderr, 
		    "Finished with %d after %d bytes. %ld.%03lds = %.4f "
		    "Mb/s.\n", 
		    fd, state[fd].rx_rcvd, 
		    (long int)tdiff.tv_sec, (long int)tdiff.tv_usec/1000, 
		    mbs/scalar);

	    close(fd);
	    state[fd].open = 0;

	    FD_CLR(fd, &fds_finished);

	    /* use fd to dsitribute it over the listener pool */
	    new_fd = create_tx_tcp(ipaddr, base_rx_port+(fd%num_ports));

	    if(new_fd < 0)
	    {
		fprintf(stderr, "Unable to open connection!\n");
		continue;
	    }
	  
	    if(new_fd > maxfd) 
	    {
		maxfd = new_fd;
	    }
	  
	    state[new_fd].rx_rcvd = 0;
	    FD_SET(new_fd, &fds_new);
	} 
    }
}
