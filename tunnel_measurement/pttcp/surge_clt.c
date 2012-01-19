/***********************************************************************
 * 
 * $Id: surge_clt.c,v 2.1 2000/08/09 13:15:41 rmm1002 Exp $
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

/*********************************************************************

surge client communicates with the server mode of pttcp

The objective is to partially replicate the behaviour of the SURGE
web-server tester of

P. Barford and M.E. Crovella, "Generating representative wb workloads
for network and server performance evaluation", In Proceedings of
Performance '98/ ACM Sigmetrics '98 pages 151-160, 1998

as used in 

Feldman A., et.al, "Dynamics of IP Traffic: A study of the role of
variability and the impact of control", SIGCOMM'99, pp 301-313.

This client is easiest thought of as a four stage Marokv chain.

the four stages are

-- interpage: time between consequtive pages downloaded in one session

-- objperpage: number of objects within a web page; all such objects
	are retrieved from the server before waiting for another page.

-- interobj: time between retriving each object on a single page.

-- objsize: size of an object in >BYTES<

each option above takes a distribution and the distribution
arguments....

constant <constant>
exponent <mean>
pareto   <mean> <shape>

allowing you to specify a moderatly complex Markox chain with
differing distributions and differing probabilities for each transtion
stage.

The sessions, once running are assumed to contain an `infinite' number
of pages, (or until the runtime is complete.)

Currently it does not calculate inter-session time or
pages-per-session, as these are considered the responsibility of a
test-rig (and can be set as the run_time, etc.)

When a session is opened the first object of the page is transmitted;
there is no random starting points displacing multiple connections in
one surge client.

5 examples were used in the Feldman paper, these and their respective
parameter sets are given below.

Pareto 1 :
-- interpage pareto 50 2 \
-- objperpage pareto 4 1.2 \
-- interobj pareto 0.5 1.5 \
-- objsize pareto 12000 1.2

Pareto 2 :
-- interpage pareto 10 2 \
-- objperpage pareto 3 1.5 \
-- interobj pareto 0.5 1.5 \
-- objsize pareto 12000 1.2

Exp 1    :
-- interpage pareto 25 2 \
-- objperpage constant 1 \
-- interobj constant 0 \
-- objsize exponent 12000 

Exp 2    :
-- interpage exponent 10 \
-- objperpage constant 1 \
-- interobj constant 0 \
-- objsize exponent 12000

Constant :
-- interpage constant 10 \
-- objperpage constant 1 \
-- interobj constant 0 \
-- objsize constant 1e6

used without additional options, the "Constant" type is the default.

***********************************************************************/

#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/time.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <math.h>
#include <string.h>
#include <unistd.h>


#include "trc.h"
#include "pttcp.h"
#include "pttcp_util.h"
#include "surge_clt.h"

extern state_t state[__FD_SETSIZE];
extern double  scalar;
extern int     maxfd;
extern int     verbose;
extern fd_set  fds_zero;

static int     G_os;

static const char *Distn_Function_Type[Distn_Function_nTypes] = {
    "constant",
    "exponent",
    "pareto"
};

distn interpage;  /* distn. function for interpage time    */
distn objperpage; /* distn. function for objects per page  */
distn interobj;   /* distn. function for inter-object time */
distn objsize;    /* distn. function for bytes per object  */

#define interpage_distn()  interpage.function(&interpage)
#define objperpage_distn() objperpage.function(&objperpage)
#define interobj_distn()   interobj.function(&interobj)
#define objsize_distn()    (((G_os = objsize.function(&objsize)) < 1) ? 1 : G_os)

/*********************************************************************
 * routines used by surge_clt things 
 */
double 
constant(distn *d)
{
    return (d->mean);
}

double
expon(distn *d)
{
    double r=(double) drand48();
    double val= -log(r) * d->mean;
    return (val);
}

double paretoon(distn *d)
{
    double r = (double) drand48();
    /* a variation of this I use in my cell generator, however here we
     * use the `by the book' ns function.
     *
     * scale * (1.0/pow(uniform(), 1.0/shape))
     *
     * double val = ((1/mean) * (shape - 1)/shape) * ( 1 / pow(r,(1/shape)));
     */

    double val = (d->mean * (1.0/pow(r, 1.0/d->shape)));
    return (val);
}

int
parse_distn(distn *distribution, int *optind, char **argv, int argc)
{
    int rv=0,rc;
    int theType;

    (*optind)--;
    for(theType=0; theType < Distn_Function_nTypes; theType++) 
    {
        if(!strncmp(argv[*optind], Distn_Function_Type[theType], 255)) 
	    break;
    }
    switch(theType) 
    {
	case Distn_Function_Constant:
	{
	    if((argc - *optind) < 2) 
	    {
		fprintf(stderr,
			"%s: constant requries one argument\n", __FILE__);
	    	rv = -1;
		goto abort;
	    }

	    /* one additional argument for a constant generator, the
	     * constant itself (or `mean') */
	    distribution->function = constant;

	    (*optind)++;
	    rc = sscanf(argv[*optind], "%lg", &distribution->mean);
	    if(rc != 1) 
	    {
		fprintf(stderr,
			"%s: bad constant %s \n", 
			__FUNCTION__, argv[*optind]);
		goto abort;
	    }
	    break;
	}

	case Distn_Function_Exponent:
	{
	    /* one additional argument for a exponential generator the
	     * mean */
	    if((argc - *optind) < 2) 
	    {
		fprintf(stderr,
			"%s: exponent requries one argument (mean)\n",
			__FUNCTION__);
	    	rv = -1;
		goto abort;
	    }

	    distribution->function = expon;

	    (*optind)++;	
	    rc = sscanf(argv[*optind], "%lg", &distribution->mean);
	    if(rc != 1) 
	    {
		fprintf(stderr,
			"%s: bad constant %s \n",
			__FUNCTION__, argv[*optind]);
		goto abort;
	    }
	    break;
	}

	case Distn_Function_Pareto:
	{
	    if((argc - *optind) < 3) 
	    {
		fprintf(stderr,
			"%s: pareto requries two arguments (mean and shape)\n", 
			__FUNCTION__ );
	    	rv = -1;
		goto abort;
	    }

	    /* two additional arguments for a pareto generator the
	     * mean and the shape */
	    distribution->function = paretoon;

	    (*optind)++;
	    rc = sscanf(argv[*optind], "%lg", &distribution->mean);
	    if(rc != 1) 
	    {
		fprintf(stderr,
			"%s: bad mean %s \n",
			__FUNCTION__, argv[*optind]);
		goto abort;
	    }

	    (*optind)++;
	    rc = sscanf(argv[*optind], "%lg", &distribution->shape);
	    if(rc != 1) 
	    {
		fprintf(stderr,
			"%s: bad shape %s \n",
			__FUNCTION__, argv[*optind]);
		goto abort;
	    }
	    break;
	}

	default:
	    fprintf(stderr,
		    ": unknown distribution type %s\n",
		    argv[*optind]);
	    rv = -1;
    }

    (*optind)++;
 abort:
    return rv;
}

/*********************************************************************
 * surge client
 */
void
surge_client(int n, char *host, int num_ports, int base_rx_port)
{
    int i;
    fd_set fds_new, fds_active, fds_finished, ids_sleeping, ids_want_to_run;
    unsigned long ipaddr;    
    double tmbs=0;
    double time_us;

    struct timeval next_start_time = {0,0};
    struct timeval current_time;

    ipaddr = host2ipaddr(host);

    FD_ZERO(&fds_new);
    FD_ZERO(&fds_active);
    FD_ZERO(&fds_finished);
    FD_ZERO(&ids_sleeping);
    FD_ZERO(&ids_want_to_run);

    /* there is a bit of repitition of code here, the first for() is
       initialisation, the while() is the action loop */

    /* create all the TCP connections */
    for(i=0; i<n; i++)
    {
	int fd;
	struct timeval tp={ 0, 0 };

	fd = create_tx_tcp(ipaddr, base_rx_port+(i%num_ports));

	if(fd < 0)
	{
	    fprintf(stderr,"Unable to open connection!\n");
	    exit(-1);
	}

	if(fd > maxfd) 
	    maxfd = fd;


	state[fd].client_id=fd;

	state[fd].object_count=objperpage_distn();

	state[fd].tx_target = objsize_distn();
	state[fd].tx_sent   = 0;
	state[fd].tx_pkts   = 0;
	state[fd].rx_rcvd   = 0;
	FD_SET(fd, &fds_new);

	tp.tv_usec = (int)(drand48()*10000.0);

	select(0, &fds_zero, &fds_zero, &fds_zero, &tp);
    }

    /* start sending */
    while(1)
    {
	int s, fd, client_id, sink_data_rc, want_to_run_rc=0;
	struct timeval tdiff;

	send_request(&fds_new, &fds_active);
	sink_data_rc = sink_data(&fds_active, &fds_finished);

	/* close those that have finished */
	for(s=0; 
	    (sink_data_rc>0) && (fd = FD_FFSandC(s, maxfd, &fds_finished));
	    s = fd+1)
	{
	    double mbs;

	    tvsub(&tdiff, &state[fd].rx_stop, &state[fd].rx_start);
	  
	    mbs = (double)(8.0*state[fd].rx_rcvd) /
		(double)(tdiff.tv_sec*1.e6 + tdiff.tv_usec);

	    tmbs += mbs;

	    gettimeofday(&current_time,NULL);

	    if(verbose)
		fprintf(stderr,
			"%d.%06d Finished with %d after %d bytes. "
			"%ld.%03lds = %.4f Mb/s.\n", 
			(int)current_time.tv_sec,(int)current_time.tv_usec,
			fd, state[fd].rx_rcvd, 
			(long int)tdiff.tv_sec, (long int)tdiff.tv_usec/1000, 
			mbs/scalar);

	    close(fd);
	    state[fd].open = 0;


	    /* control loop for time keeping:
	     *
	     * this should embody the idea that if the object count
	     * is >1 insert an interobj sleep; if the object count is
	     * <1 recalc the object count and this sleep is an
	     * interpage sleep.
	     */

	    state[fd].object_count--;

	    if(state[fd].object_count > 0) {
		
		time_us = interobj_distn();
	    }else{
		time_us = interpage_distn();
		state[fd].object_count=objperpage_distn();
	    }


	    time_us *= scalar;
	    next_start_time.tv_sec = (int) time_us;
	    next_start_time.tv_usec = (int) 
		((time_us - (double)next_start_time.tv_sec) 
		 * 1e6 );
	    tvadd(&state[state[fd].client_id].next_start_time,&state[fd].rx_stop,
		  &next_start_time);

	    if(verbose)
		printf("(%d): time_us %d.%06d opp %d\n",__LINE__,
		       (int)next_start_time.tv_sec,
		       (int)next_start_time.tv_usec,
		       state[fd].object_count);
	    FD_CLR(fd, &fds_finished);
	    FD_SET(state[fd].client_id, &ids_sleeping);
	}



	for(s=0;(client_id = FD_FFS(s, maxfd, &ids_sleeping));
	    s = client_id+1)
	{
	
	    gettimeofday(&current_time,NULL);

	    if(tveqless(&state[client_id].next_start_time,&current_time)) {
		if(state[client_id].object_count > 0) {
		    FD_CLR(client_id, &ids_sleeping);
		    FD_SET(client_id, &ids_want_to_run);
		    want_to_run_rc++;
		}else{

		    /* this exception handles the empty page in which
		       case if the time expires we just wait another
		       interpage and calculate another value for the
		       objperpage */

		    time_us = interpage_distn();
		    state[fd].object_count=objperpage_distn();
		    time_us *= scalar;
		    next_start_time.tv_sec = (int) time_us;
		    next_start_time.tv_usec = (int) 
			((time_us - (double)next_start_time.tv_sec) 
			 * 1e6 );
		    tvadd(&state[state[fd].client_id].next_start_time,
			  &state[fd].rx_stop,
			  &next_start_time);
		}
	    }
	}

	if(verbose && want_to_run_rc>0) {
	    fprintf(stdout,"%d.%06d %d %d %d %d %d (%d)\n", 
		    (int)current_time.tv_sec,(int)current_time.tv_usec,
		    FD_POP(maxfd,&fds_new),
		    FD_POP(maxfd,&fds_active),
		    FD_POP(maxfd,&fds_finished),
		    FD_POP(maxfd,&ids_sleeping),
		    FD_POP(maxfd,&ids_want_to_run),
		    (FD_POP(maxfd,&fds_new)+
		     FD_POP(maxfd,&fds_active)+
		     FD_POP(maxfd,&fds_finished)+
		     FD_POP(maxfd,&ids_sleeping)+
		     FD_POP(maxfd,&ids_want_to_run)));
	}

	for(s=0; 
	    ((want_to_run_rc>0) && 
	     (client_id = FD_FFSandC(s, maxfd, &ids_want_to_run)));
	    s = client_id+1)
	{
	    int new_fd;

	    /* use fd to dsitribute it over the listener pool */
	    new_fd = create_tx_tcp(ipaddr, base_rx_port+(fd%num_ports));
	    state[new_fd].client_id=client_id;

	    if(new_fd < 0)
	    {
		fprintf(stderr,"Unable to open connection!\n");
		continue;
	    }
	    
	    if(new_fd > maxfd) 
		maxfd = new_fd;

	    state[new_fd].tx_target = objsize_distn();
	    state[new_fd].rx_rcvd = 0;
	    FD_SET(new_fd, &fds_new);
	}
    }
}
