/*==============================================================================
MIT License

Copyright (c) 2023 Trevor Monk

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
==============================================================================*/

/*!
 * @defgroup timer timer
 * @brief Timer functions
 * @{
 */

/*============================================================================*/
/*!
@file timer.c

    Dynamic Timer Management

    The timer component provides functions for manipulating timers.

    - create repeating tick timer

*/
/*============================================================================*/

/*==============================================================================
        Includes
==============================================================================*/

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>
#include <errno.h>
#include <syslog.h>
#include <signal.h>
#include <time.h>
#include "timer.h"

/*==============================================================================
       Function declarations
==============================================================================*/

/*==============================================================================
       Definitions
==============================================================================*/

/*! Maximum number of timers allowed */
#define MAX_TIMERS ( 255 )

/*==============================================================================
       File Scoped Variables
==============================================================================*/

/*! list of timer identifiers */
static timer_t timers[MAX_TIMERS] = {0};

/*! id of the next timer to create */
static int id = 0;

/*==============================================================================
       Function definitions
==============================================================================*/

/*============================================================================*/
/*  CreateTick                                                                */
/*!
    Create a tick timer

    The CreateTick creates a timer which will fire repeatedly
    at a specified interval

@param[in]
    num
        repeat interval of the tick in units of timescale

@param[in]
    ts
        time scale of the repeat interval.
        One of:

@retval id of the timer that was created
@retval -1 if no timer could be created

==============================================================================*/
int CreateTick( int num, Timescale ts )
{
    struct sigevent te;
    struct itimerspec its;
    time_t secs = 0;
    long msecs = 0;
    timer_t *timerID;
    int result = -1;

    /* get the next timerid */
    if ( (id + 1) < MAX_TIMERS )
    {
        /* get the next timer identifier */
        id++;

        switch ( ts )
        {
            case TIMESCALE_eMILLISECONDS:
                secs = num / 1000;
                msecs = num % 1000;
                break;

            case TIMESCALE_eSECONDS:
                secs = num;
                break;

            case TIMESCALE_eMINUTES:
                secs = num * 60;
                break;

            case TIMESCALE_eHOURS:
                secs = num * 3600;
                break;

            case TIMESCALE_eDAYS:
                secs = num * 86400;
                break;

            case TIMESCALE_eWEEKS:
                secs = num * 86400 * 7;
                break;

            default:
                break;
        }

        if ( ( secs != 0 ) || ( msecs != 0 ) )
        {
            timerID = &timers[id];

            /* Set and enable alarm */
            te.sigev_notify = SIGEV_SIGNAL;
            te.sigev_signo = TIMER_NOTIFICATION;
            te.sigev_value.sival_int = id;
            timer_create(CLOCK_REALTIME, &te, timerID);

            its.it_interval.tv_sec = secs;
            its.it_interval.tv_nsec = msecs * 1000000L;
            its.it_value.tv_sec = secs;
            its.it_value.tv_nsec = msecs * 1000000L;
            timer_settime(*timerID, 0, &its, NULL);

            result = id;
        }
    }

    return result;
}

