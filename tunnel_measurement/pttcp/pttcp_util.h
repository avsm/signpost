/***********************************************************************
 * 
 * $Id: pttcp_util.h,v 2.0 2000/05/03 20:26:34 rmm1002 Exp $
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

#ifndef _pttcp_util_h_
#define _pttcp_util_h_

#define MAX(a,b) (((a)>(b))?(a):(b))
#define MIN(a,b) (((a)<(b))?(a):(b))

#define ffs_long     ffs /* this will only work on 32 bit machines! */

void          fatal(char *, ...);
void          warning(char *, ...);
int           getint(char*);
double        getdouble(char*);
unsigned long host2ipaddr(const char*);
int           tveqless(struct timeval*, struct timeval*);
void          tvadd(struct timeval*, struct timeval*, struct timeval*);
void          tvsub(struct timeval*, struct timeval*, struct timeval*);
unsigned int  pop_count(unsigned int);
int           FD_POP(int, fd_set*);
int           FD_FFS(int, int, fd_set*);
int           FD_FFSandC(int, int, fd_set*);
int           create_tx_tcp(unsigned long, int);
int           send_data(fd_set*, fd_set*);

#endif /* _pttcp_util_h_ */
