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
 * @defgroup engine engine
 * @brief Actions Engine functions
 * @{
 */

/*============================================================================*/
/*!
@file engine.c

    Dynamic Actions Processing Engine

    The Actions engine component provides functions
    for operating the Actions handler.

    The following handled:

    - wait for signals
    - evaluate Action execution rules
    - manage timers


*/
/*============================================================================*/

#ifndef ENGINE_H
#define ENGINE_H

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
#include "actiontypes.h"
#include "actions.tab.h"
#include "timer.h"
#include <varaction/varaction.h>

/*==============================================================================
       Function declarations
==============================================================================*/

static int waitSignal( int *signum, int *id );
static int HandleSignal( Actions *pActions, int signum, int id );
static int ProcessAction( Actions *pActions, Action *pAction );

/*==============================================================================
       Definitions
==============================================================================*/


/*==============================================================================
       Function definitions
==============================================================================*/

/*============================================================================*/
/*  RunActions                                                                */
/*!
    Run the Actions processor

    The RunActions function executes the actions in the program

@param[in]
    pActions
        Pointer to the Actions to execute

@retval EOK the actions completed normally
@retval EINVAL invalid arguments
@retval other actions error

==============================================================================*/
int RunActions( Actions *pActions )
{
    int result = EINVAL;
    int signum;
    int id;

    if ( pActions != NULL )
    {
        /* run the actions processor forever */
        while( true )
        {
            /* wait for a signal to occur */
            waitSignal( &signum, &id );

            if( pActions->verbose )
            {
                fprintf( stdout,
                         "Received signal %d id = %d\n",
                         signum,
                         id );
            }

            /* handle the received signal */
            result = HandleSignal( pActions, signum, id );
            if( pActions->verbose )
            {
                fprintf( stdout,
                         "signal %d %d: %s\n",
                         signum,
                         id,
                         strerror(result) );
            }
        }
    }

    return result;
}

/*============================================================================*/
/*  waitSignal                                                                */
/*!
    Wait for a signal from the system

    The waitSignal function waits for either a variable modified
    or timer expired signal from the system

@param[in,out]
    signum
        Pointer to a location to store the received signal

@param[in,out]
    id
        Pointer to a location to store the signal identifier

@retval 0 signal received successfully
@retval -1 an error occurred

==============================================================================*/
static int waitSignal( int *signum, int *id )
{
    sigset_t mask;
    siginfo_t info;
    int result = EINVAL;
    int sig;

    if( ( signum != NULL ) &&
        ( id != NULL ) )
    {
        /* create an empty signal set */
        sigemptyset( &mask );

        /* timer notification */
        sigaddset( &mask, TIMER_NOTIFICATION );

        /* modified notification */
        sigaddset( &mask, VAR_NOTIFICATION );

        /* calc notification */
        sigaddset( &mask, CALC_NOTIFICATION );

        /* apply signal mask */
        sigprocmask( SIG_BLOCK, &mask, NULL );

        /* wait for the signal */
        sig = sigwaitinfo( &mask, &info );

        /* return the signal information */
        *signum = sig;
        *id = info.si_value.sival_int;

        /* indicate success */
        result = EOK;
    }

    return result;
}

/*============================================================================*/
/*  HandleSignal                                                              */
/*!
    Handle a received signal

    The HandleSignal function drives action execution.
    It searches through the action processor's action list
    looking for where the received signal is used, if at all, and then
    evaluates the conditions around the signal.  If the conditions
    related to the received signal evaluate to true, then the
    appropriate action is executed.

@param[in]
    pActions
        pointer to the actions processor

@param[in]
    signum
        the type of signal received

@param[in]
    id
        the identifier of the signal

@retval EINVAL invalid argument
@retval EOK the signal was processed

==============================================================================*/
static int HandleSignal( Actions *pActions, int signum, int id )
{
    Action *pAction;
    int result = EINVAL;
    VAR_HANDLE hVar;
    bool found = false;
    Signal *pSignal = NULL;

    if ( pActions != NULL )
    {
        if ( ( signum == VAR_NOTIFICATION ) ||
             ( signum == CALC_NOTIFICATION ) )
        {
            result = ENOENT;

            /* point to the start of the actions list */
            pAction = pActions->pActionList;
            while ( pAction != NULL )
            {
                found = false;

                /* check for the type of signal we have received */
                if( pAction->signal == signum )
                {
                    /* get signals associated with the action */
                    pSignal = pAction->pSignals;
                    while( pSignal != NULL )
                    {
                        /* check the signal id (Variable handle) */
                        if ( pSignal->id == id )
                        {
                            /* indicate that the signal is associated with
                             * the current action */
                            found = true;
                        }

                        /* look for the next signal */
                        pSignal = pSignal->pNext;
                    }

                    if ( found )
                    {
                        /* perform action processing */
                        result = ProcessAction( pActions, pAction );
                    }
                }

                /* move on to the next action */
                pAction = pAction->pNext;
            }
        }
        else if ( signum == TIMER_NOTIFICATION )
        {
            result = ENOENT;

            /* point to the start of the actions list */
            pAction = pActions->pActionList;
            while ( pAction != NULL )
            {
                found = false;

                /* check for the type of signal we have received */
                if( pAction->signal == signum )
                {
                    if ( pAction->timerID == id )
                    {
                        /* perform action processing */
                        result = ProcessAction( pActions, pAction );
                        break;
                    }
                }

                /* move on to the next action */
                pAction = pAction->pNext;
            }
        }
    }

    return result;
}

/*============================================================================*/
/*  ProcessAction                                                             */
/*!
    Process an action

    The ProcessAction function performs all of the statements
    contained within the action.

@param[in]
    pActions
        pointer to the actions object

@param[in]
    pAction
        pointer to the action to be executed

@retval EINVAL invalid argument
@retval EOK the action was successfully processed

==============================================================================*/
static int ProcessAction( Actions *pActions, Action *pAction )
{
    int result = EINVAL;
    int rc;
    Statement *pStatement;

    if ( pAction != NULL )
    {
        result = EOK;
        pStatement = pAction->pStatements;
        while ( pStatement != NULL )
        {
            rc = ProcessStatement( pActions->hVarServer, pStatement );
            if ( rc != EOK )
            {
                result = rc;
            }

            pStatement = pStatement->pNext;
        }
    }

    return result;
}

#endif

/*! @}
 * end of engine group */