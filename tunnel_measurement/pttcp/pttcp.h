/***********************************************************************
 * 
 * $Id: pttcp.h,v 2.0 2000/05/03 20:26:34 rmm1002 Exp $
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

#ifndef _pttcp_h_
#define _pttcp_h_

#define __FD_SETSIZE 1024

typedef struct {
    struct sockaddr_in sinme;
    struct sockaddr_in sinhim;

    int open;

    u_int32_t      tx_target;   /* used by tx side                    */

    u_int32_t      tx_pkts;
    u_int32_t      tx_sent;
    u_int32_t      tx_sent_cpt; /* bytes rx'd since checkpoint        */
    struct timeval tx_start;    /* send_data(): just as start sending */
    struct timeval tx_stop;     /* send_data(): when all is sent      */

    u_int32_t      rx_pkts;
    u_int32_t      rx_rcvd;     /* used by rx side                    */
    u_int32_t      rx_rcvd_cpt; /* bytes rx'd since checkpoint        */
    struct timeval rx_start;    /* sink_data(): when first bits rcvd  */
    struct timeval rx_stop;     /* sink_data(): when no bits rcvd     */

    /* state for handling more complex traffic generators             */
    int            client_id;

    int            object_count;
    struct timeval next_start_time;    /* time until next wake up */
} state_t;

typedef enum {
    unset = -1, rx = 0, tx, svr, simple_clt, cts_clt, surge_clt
} pttcp_t;

/*********************************************************************
 * important constants 
 */
#define BUF_SIZE      1448
#define SAMPLE_PERIOD 5e6 /* in microsecs */

/*********************************************************************
 * function prototypes
 */

void surge_client(int n, char *host, int num_ports, int base_rx_port);

void continuous_client(int n, int bytes, char *host, int num_ports, int
base_rx_port);

void simple_tx(int n, int bytes, char *host, int num_ports, int
base_rx_port);

void simple_rx(int num_ports, int base_rx_port);

void simple_client(int n, int bytes, char *host, int num_ports, int
base_rx_port);

void simple_server(int num_ports, int base_rx_port);

int sink_data(fd_set *fds_active, fd_set *fds_finished);
void send_request(fd_set *fds_new, fd_set *fds_active);
int create_listeners(fd_set *fds_listeners, int num_ports, 
                     int base_rx_port);

int accept_incoming(int maxlfd, fd_set *fds_listeners, 
                    fd_set *fds_active);






#endif /* _pttcp_h_ */
