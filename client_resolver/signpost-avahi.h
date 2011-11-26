/*
 * =====================================================================================
 *
 *       Filename:  signpost-avahi.h
 *
 *    Description:  A simple API to introduce local discovery functionality to the 
 *                  resolver in order to discover and propagate back to the signpost server
 *                  any signpost discovered services. 
 *
 *        Version:  1.0
 *        Created:  17/11/11 10:43:04
 *       Revision:  none
 *       Compiler:  gcc
 *
 *         Author:  YOUR NAME (crotsos), 
 *        Company:  CUCL
 *
 * =====================================================================================
 */
 
#ifndef SIGNPOST_AVAHI_H_

#define SIGNPOST_AVAHI_H_

#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <time.h>

#include <avahi-client/client.h>
#include <avahi-client/lookup.h>

#include <avahi-common/simple-watch.h>
#include <avahi-common/malloc.h>
#include <avahi-common/error.h>

int lookup_local_sps_server();

#endif
