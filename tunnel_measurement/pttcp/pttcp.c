/*********************************************************************
 *
 * $Id: pttcp.c,v 2.2 2000/08/09 13:16:08 rmm1002 Exp $
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

#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <signal.h>
#include <sys/time.h> /* struct timeval */
#include <getopt.h>
#include <unistd.h>


#include "trc.h"
#include "pttcp.h"
#include "pttcp_util.h"
#include "surge_clt.h"

/*********************************************************************
 * Global variables 
 */
char        *prog_name;
state_t      state[ __FD_SETSIZE ];
fd_set       fds_zero;

int          maxfd     = 0;
pttcp_t      mode      = unset;
unsigned int base_port = 5001;
unsigned int num_ports = 32;
double       scalar    = 1.0;
int          verbose   = 0;

const struct timeval tsmallerpause = { 0,    1 }; /* 1us */
const struct timeval tpause        = { 0, 1000 }; /* 1ms */
const struct timeval tzero         = { 0,    0 }; 

extern char *optarg;
extern int optind, opterr, optopt;

extern distn interpage;  /* distn. function for interpage time    */
extern distn objperpage; /* distn. function for objects per page  */
extern distn interobj;   /* distn. function for inter-object time */
extern distn objsize;    /* distn. function for bytes per object  */

static const struct option long_options[] =
{
    { "interpage",  1, 0, 1001 },
    { "objperpage", 1, 0, 1002 },
    { "interobj",   1, 0, 1003 },
    { "objsize",    1, 0, 1004 },

    /* END OF ARRAY MARKER */
    { 0,            0, 0,    0 }
};

/*********************************************************************
 * handle ^C (SIGINT) 
 */
void 
shut_sockets(int signum)
{
    int i;

    if(signum == SIGALRM) 
    {
	if(verbose) 
	{
	    fprintf(stderr,"timesup\n");
      	}
    }
    if(verbose) 
    {
	printf("Shutdown called\n");
    }
    for(i=0; i <= maxfd; i++)
    {
	if(state[i].open)
	{
	    fprintf(stderr, "%d ",i);
	    close(i);
	}
    }
    fprintf(stderr, "\n");
    exit(0);
}

void
usage(char *name)
{
    fprintf(stderr,
	    "Syntax error: usage is one of\n"
	    "[svr] %s -s \n"
	    "[clt] %s -c <server> [-n <conns>] [-b <bytes>]\n"
	    "[rxr] %s -r\n"
	    "[txr] %s -t <receiver> [-n <conns>] [-b <bytes>]\n"
	    "[surge_clt] %s -S <server> [-n <conns>]\n"
	    "            [--<objsize|interobj|objperpage|interpage>\n"
	    "             <constant <value>|exponent <mean>|pareto <mean> <shape>>]\n"
	    "\n"
	    "Commands valid for all generators\n"
	    "    [-D <scaling> (of timers)]\n"
	    "    [-T <runtime>]\n"
	    "    [-B <port base>]\n"
	    "    [-N <number of ports>]\n"
	    "    [-R <random number seed>]\n",
	    name, name, name, name, name);
    exit(1);
}

int 
main(int argc, char **argv)
{
    int rc, c, n = 1, bytes = 512*1025;
    char dhost[256];
    double run_time = -1;

    interpage.mean      = 0;
    interpage.function  = constant;
    objperpage.mean     = 1;
    objperpage.function = constant;
    interobj.mean       = 0;
    interobj.function   = constant;
    objsize.mean        = 1e6;
    objsize.function    = constant;

    while((c = getopt_long(argc, argv, "S:vR:B:N:D:T:rt:sc:n:b:",
			   long_options, NULL)) != -1) 
    {
	switch(c) 
	{
	    case 'v':
		verbose++;
		break;

	    case 1001:
		rc = parse_distn(&interpage, &optind, argv, argc);
		if(rc<0) 
		{
		    usage(argv[0]);
		}
		break;

	    case 1002:
		rc = parse_distn(&objperpage, &optind, argv, argc);
		if(rc<0) 
		{
		    usage(argv[0]);
		}
		break;

	    case 1003:
		rc = parse_distn(&interobj, &optind, argv, argc);
		if(rc<0) 
		{
		    usage(argv[0]);
		}
		break;

	    case 1004:
		rc = parse_distn(&objsize, &optind, argv, argc);
		if(rc<0) 
		{
		    usage(argv[0]);
		}
		break;

	    case 'R':
	    {
		unsigned short seed_16v[3];
		unsigned long  full_seed;
		int            rc;
	    
		rc = sscanf(optarg,"%ld",&full_seed);
            
		if(rc != 1) 
		{
		    usage(argv[0]);
		}
                        
		seed_16v[0] = (short)(0xffffl & full_seed);
		seed_16v[1] = (short)((~0xffffl & full_seed) >> 16);
		seed_16v[2] = (short)((~0xffl & full_seed) >> 8); /* XXX */
		(void)seed48(seed_16v);
		break;
	    }

	    case 'r':          /* receiver */
		if(mode == unset)
		{
		    mode = rx;
		}
		else
		{
		    usage(argv[0]);
		}
		break;
      
	    case 't':          /* transmitter */
		if(mode == unset)
		{
		    mode = tx;
		}
		else
		{
		    usage(argv[0]);
		}

		strncpy(dhost, optarg, 255);
		break;

	    case 's':          /* server */
		if(mode == unset)
		{
		    mode = svr;
		}
		else
		{
		    usage(argv[0]);
		}
		break;

	    case 'c':          /* client */
		if(mode == unset)
		{
		    mode = cts_clt;
		}
		else
		{
		    usage(argv[0]);
		}

		strncpy(dhost, optarg, 255);
		break;

	    case 'S':          /* surge client */
		if(mode == unset)
		{
			
		    mode = surge_clt;
		}
		else
		{
		    usage(argv[0]);
		}
		strncpy(dhost, optarg, 255);
		break;

	    case 'n':          /* number of concurrent connections */
		n = getint(optarg);
		break;

	    case 'b':          /* number of bytes in each connection */
		bytes = getint(optarg);
		break;

	    case 'B':
		base_port = getint(optarg);
		break;

	    case 'N':
		num_ports = getint(optarg);
		break;

	    case 'D':          /* scaling */
		scalar = getdouble(optarg);
		fprintf(stderr, "using a scalar of %g\n", scalar);
		break;

	    case 'T':          /* run time */
		run_time = getdouble(optarg);
		break;

	    default:
		usage(argv[0]);
	}
    }

    /* SIGPIPE caused by RST connection; ignore and deal with errno
     * from initial write */
    signal(SIGPIPE, SIG_IGN); 
    signal(SIGINT,  shut_sockets);
    signal(SIGALRM, shut_sockets);

    if(run_time >= 0) 
    {
	struct itimerval run_time_timerval;
	int rc;
	
	run_time = run_time * scalar;
	
	run_time_timerval.it_interval.tv_sec  = 0;
	run_time_timerval.it_interval.tv_usec = 0;
	
	run_time_timerval.it_value.tv_sec = (int) run_time;
	run_time_timerval.it_value.tv_usec = 
	    (int) ((run_time - (double)run_time_timerval.it_value.tv_sec) * 1e6 );

	if(verbose) 
	{
	    fprintf(stderr,"run time %d.%06d\n",
		    (int)run_time_timerval.it_interval.tv_sec,
		    (int)run_time_timerval.it_interval.tv_usec);
	}
	
	
	rc = setitimer(ITIMER_REAL, &run_time_timerval,NULL);
	if(rc != 0) 
	{
	    perror("setitimer");
	    exit(-1);
	}
    }

    switch(mode)    
    {
	case rx:
	    simple_rx(num_ports, base_port);
	    break;

	case tx:
	    simple_tx(n, bytes, dhost, num_ports, base_port);
	    break;

	case svr:
	    simple_server(num_ports, base_port);
	    break;

	case simple_clt:
	    simple_client(n, bytes, dhost, num_ports, base_port);
	    break;

	case cts_clt:
	    continuous_client(n, bytes, dhost, num_ports, base_port);
	    break;

	case surge_clt:
	    surge_client(n, dhost, num_ports, base_port);
	    break;
	    
	case unset:
	default:
	    usage(argv[0]);
    }
    return 0;
}

/*********************************************************************
 * create listening sockets on [base_rx_port, base_rx_port+num_ports] 
 */
int 
create_listeners(fd_set *fds_listeners, int num_ports, int base_rx_port)
{
    int i, fd, maxfd=0;
    int on = 1;   /*  1 = non blocking  */

    for(i=0; i<num_ports; i++)
    {
	if((fd = socket(AF_INET, SOCK_STREAM, 0)) < 0)
	{
	    perror("socket");
	    return -1;
	}

	state[fd].open = 1;

	bzero((char *)&state[fd].sinme, sizeof(state[fd].sinme));
	state[fd].sinme.sin_port =  htons(base_rx_port+i);
      
#if 0
	/* 6 = TCP */
	if(setsockopt(fd, 6, SO_REUSEADDR, &on, sizeof(int)) < 0)
	{
	    perror("SO_REUSEADDR");
	    return -1;	  
	}
#endif

	if(bind(fd, &state[fd].sinme, sizeof(state[fd].sinme)) < 0)
	{
	    perror("bind");
	    return -1;
	}
	if(ioctl(fd, FIONBIO, (char*)&on) < 0) 
	{
	    perror("FIONBIO");
	    return -1;
	}
	if(listen(fd, 16) < 0)
	{
	    perror("listen");
	    return -1;
	}
      
	FD_SET(fd, fds_listeners);

	if(fd > maxfd) 
	{
	    maxfd = fd;
	}
    }
    return maxfd;
}

/*********************************************************************
 * accept incoming socket requests, catching any exceptions
 */
int
accept_incoming(int maxlfd, fd_set *fds_listeners, fd_set *fds_active)
{
    int s, rc, fd, new_fd, count=0;
    fd_set fds_tmp1, fds_tmp2;
    struct timeval tmp_timeout;
    int on = 1;   /* 1 = non blocking */

    tmp_timeout = tzero;
			 
    fds_tmp1 = *fds_listeners;
    fds_tmp2 = *fds_listeners;

    /* zero timeout */
    rc = select(maxlfd+1, &fds_tmp1, &fds_zero, &fds_tmp2, &tmp_timeout);
  
    for(s=0; (rc>0) && (fd = FD_FFSandC(s, maxlfd, &fds_tmp2)); s = fd+1)
    {
	fprintf(stderr, "listen: got an exception on fd %d !!\n", fd);
	exit(-1);
    }
    
    /* accept any new requests */
    for(s=0; (rc>0) && (fd = FD_FFSandC(s, maxlfd, &fds_tmp1)); s = fd+1)
    {
	struct sockaddr_in frominet;
	int fromlen;

	fromlen = sizeof(frominet);      
	if((new_fd = accept(fd, &frominet, &fromlen)) < 0)
	{
	    perror("accept");
	    return -1;
	}
	else
	{
	    if(verbose)
	    {
		fprintf(stderr, "[ accept new_fd %d from fd %d ]\n", new_fd, fd);
	    }
	    if(new_fd > maxfd) 
	    {
		maxfd = new_fd;
	    }
	    if(ioctl(new_fd, FIONBIO, (char*)&on) < 0) 
	    {
		perror("FIONBIO");
		return -1;
	    }
	  
	    state[new_fd].sinme     = state[fd].sinme;
	    state[new_fd].sinhim    = frominet;

	    state[new_fd].rx_rcvd   = 0;
	    state[new_fd].rx_pkts   = 0;

	    state[new_fd].tx_sent   = 0;
	    state[new_fd].tx_target = 0;
	    state[new_fd].tx_pkts   = 0;

	    state[new_fd].open    = 1;

	    if(mode == rx)
	    {
		gettimeofday(&state[new_fd].rx_start, (struct timezone *)0);
	    }

	    FD_SET(new_fd, fds_active);
	    count++;
	}	 
    }  
    return count;
}

/*********************************************************************
 * catch exceptions (=> drop socket) and suck data from those with
 * data waiting 
 */
int 
sink_data(fd_set *fds_active, fd_set *fds_finished)
{
    int s, sel_rc, fd, fin = 0;
    fd_set fds_tmp1, fds_tmp2;
    struct timeval tmp_timeout;
    char buf[BUF_SIZE];

    tmp_timeout = tsmallerpause;

    fds_tmp1 = *fds_active;
    fds_tmp2 = *fds_active;

    /* 100ms timeout */
    sel_rc = select(maxfd+1, &fds_tmp1, &fds_zero, &fds_tmp2, &tmp_timeout);
   
    /* check for exceptions */
    for(s=0; (sel_rc>0) && (fd = FD_FFSandC(s, maxfd, &fds_tmp2)); s = fd+1)
    {
	/* this shouldn't happen... */
	fprintf(stderr, 
		"rx data: got EXCEPTION on fd %d after %d bytes (%d pkts)\n", 
		fd, state[fd].rx_rcvd, state[fd].rx_pkts);
	close(fd);
	state[fd].open = 0;
	FD_CLR(fd, fds_active);
    }

    /* read those that are ready */
    for(s=0; (sel_rc>0) && (fd = FD_FFSandC(s, maxfd, &fds_tmp1)); s = fd+1)
    {
	int recv_rc;

	while(1)
	{
	    recv_rc = recvfrom(fd, buf, sizeof(buf), 0, NULL, NULL);
	    if(recv_rc < 0)
	    {
		if(errno != EWOULDBLOCK)
		{
		    perror("Read");
		}
		break;
	    }
	    else if(recv_rc == 0)
	    {
		/* EOF => tx has just closed connection */
		gettimeofday(&state[fd].rx_stop, (struct timezone *)0);
		FD_SET(fd, fds_finished);
		FD_CLR(fd, fds_active);
		fin++;
		break;
	    }
	    else /* recv_rc > 0 */
	    {
		state[fd].rx_rcvd     += recv_rc;
		state[fd].rx_rcvd_cpt += recv_rc;
		state[fd].rx_pkts++;
	    }
	}	  	  
    }
    return fin;
}

/*********************************************************************
 * client request amt of data from server; marks connection new ->
 * active 
 */
void 
send_request(fd_set *fds_new, fd_set *fds_active)
{
    struct timeval tmp_timeout;
    int rc, fd, s;
    fd_set fds_tmp1, fds_tmp2;

    fds_tmp1 = fds_tmp2 = *fds_new;
    tmp_timeout = tzero;

    rc = select(maxfd+1, &fds_zero, &fds_tmp1, &fds_tmp2, &tmp_timeout);

    if(rc < 0)
    {	
	perror("select");
	exit(-1);
    }

    if(!rc)
	return;   /* nothing to do */

    /* check for exceptions first */
    for(s=0; (fd = FD_FFSandC(s, maxfd, &fds_tmp2)); s = fd+1)
    {
	printf("[ send request: got an exception on fd %d ]\n", fd);
    }
	
    if(s)
	exit(-1);

    /* check for fds ready to write */
    for(s=0; (fd = FD_FFSandC(s, maxfd, &fds_tmp1)); s = fd+1)
    {
	u_int32_t bytes = state[fd].tx_target;

	gettimeofday(&state[fd].rx_start, (struct timezone*)0);

	rc = write(fd, &bytes, sizeof(u_int32_t));
	if(rc != sizeof(u_int32_t))
	{
	    printf("[ send request: write on %d got %d ]\n", fd, rc);
	    if(rc < 0)
		perror("send request write");
	}

	FD_CLR(fd, fds_new);
	FD_SET(fd, fds_active);
    }
}

/*********************************************************************
 * svr: (server) (send_data) rx request -> 
 *                        (send_data) tx amt of data (miss FIN/ACK RTT)
 * tx : (send_simple_traffic) successful open conn. -> 
 *                        (send_data) tx amt of data (miss FIN/ACK RTT)
 *
 * clt: (continuous_client) (send_request) send rx request -> 
 *                        (sink_data) read EOF from sock.
 * rx : (rx_sink) (accept_incoming) accept connection ->
 *                        (sink_data) read EOF from sock.
 *********************************************************************
 */
