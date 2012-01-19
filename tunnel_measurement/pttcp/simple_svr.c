/***********************************************************************
 * 
 * $Id: simple_svr.c,v 2.0 2000/05/03 20:26:34 rmm1002 Exp $
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
extern double  scalar;
extern int     maxfd;
extern int     verbose;

/*********************************************************************
 * open connections and send requested amt of data; estimate b/w
 */
void
simple_server(int num_ports, int base_rx_port)
{
    int datafd, maxlfd;
    unsigned long diffus;
    struct timeval last, diff, now ={ 0L, 0L };
    int opened=0, closed=0, cnt=0; 
    fd_set fds_listeners, fds_active, fds_finished;

    int rc;

    FD_ZERO(&fds_listeners);
    FD_ZERO(&fds_active);
    FD_ZERO(&fds_finished);

    /* listeners on num_ports */
    if((maxlfd = create_listeners(&fds_listeners, num_ports, base_rx_port)) < 0)
    {
	exit(-1);
    }

    datafd = maxlfd+1;

    while(1)
    {
	/* grab any new incoming connections */
	rc = accept_incoming(maxlfd, &fds_listeners, &fds_active);
	if(rc > 0)
	{
	    opened += rc;
	}
	/*  select on the data FD's */
	rc = send_data(&fds_active, &fds_finished);
	if(rc > 0)
	{
	    closed += rc;
	}
	cnt++; 
	
	gettimeofday(&now, (struct timezone *)0);
	
	tvsub(&diff, &now, &last);
	diffus = diff.tv_sec*1e6 + diff.tv_usec;
	
	if(diffus > SAMPLE_PERIOD)
	{
	    int i, totb=0, prog=0;
	    double mbs, tmbs=0.0;

	    fprintf(stderr, "\nBandwidth:\n");

	    for(i=datafd; i <= maxfd; i++)
	    {
		if(state[i].tx_sent_cpt) 
		{
		    prog++;
		}
		totb += state[i].tx_sent_cpt;
		mbs   = (double)(8.0*state[i].tx_sent_cpt) / (double)diffus;
		tmbs += mbs;
	      
		if(state[i].open) 
		{
		    fprintf(stderr,"%c%.4f ",'+', mbs);
		}
		else
		{
		    if(verbose)
		    {
			fprintf(stderr,"%c%.4f ",'-', mbs);
		    }
		}

		state[i].tx_sent_cpt = 0;
	    }

	    fprintf(stderr, 
		    "\n\t %d streams active, %d made progress: "
		    "tot = %d, tot Mb/s = %.2f\n"
		    "\t opened %d, closed %d descriptors (loop count %d)\n\n",
		    FD_POP(maxfd, &fds_active), prog, 
		    totb, tmbs/scalar, 
		    opened, closed, cnt);
	    
	    opened = closed = cnt = 0;
	    last = now; 
	}
    } /* end of while 1 */
}
