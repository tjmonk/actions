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
 * @defgroup actions actions
 * @brief Event driven actions processor
 * @{
 */

/*============================================================================*/
/*!
@file actions.c

    Event Driven Actions Processor

    The Actions application creates and operates an event driven
    actions manager as defined by the actions configuration file
    provided as an argument to the application.

    The actions handling engine supports:

    - variable change (signal) based actions
    - timer based actions
    - varable calc request based actions
    - shell execution based on action triggers
    - conditional actions based on logical comparison operations

    The actions handler accepts a user defined actions definition file
    as an argument and builds the action handling logic dynamically.

    The action handler is event driven, and idle until external
    changes to variables cause actions to be executed.

    The actions definition is parsed using flex/bison

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
#include <limits.h>
#include <signal.h>
#include <syslog.h>
#include <errno.h>
#include <varserver/varserver.h>
#include "actiontypes.h"
#include "engine.h"

/*==============================================================================
       Function declarations
==============================================================================*/
static void usage( char *cmdname );
int yylex(void);
int yyparse(void);
static int ParseActions( char *filename );
static void SetupTerminationHandler( void );
static void TerminationHandler( int signum, siginfo_t *info, void *ptr );
static int ProcessOptions( int argC,
                           char *argV[],
                           Actions *pActions );

/*==============================================================================
       Definitions
==============================================================================*/
#ifndef EOK
#define EOK 0
#endif

/*==============================================================================
       File Scoped Variables
==============================================================================*/

/*! pointer to the Actions context */
Actions *pActions;

/*==============================================================================
       Function definitions
==============================================================================*/

/*============================================================================*/
/*  main                                                                      */
/*!
    Main entry point for the actions application

    @param[in]
        argc
            number of arguments on the command line
            (including the command itself)

    @param[in]
        argv
            array of pointers to the command line arguments

    @return 0

==============================================================================*/
int main(int argC, char *argV[])
{
    pActions = NULL;

    /* initialize the varactions library */
    InitVarAction();

    /* create the Actions instance */
    pActions = (Actions *)calloc(1, sizeof( Actions ) );
    if ( pActions != NULL )
    {
        /* get a handle to the variable server for transition events */
        pActions->hVarServer = VARSERVER_Open();
        if ( pActions->hVarServer != NULL )
        {
            /* Process Options */
            ProcessOptions( argC, argV, pActions );

            /* parse the Actions definition */
            if (ParseActions( pActions->filename ) == EOK )
            {
                /* run the actions */
                RunActions( pActions );
            }

            /* we should reach here only if the
             * actions handler self-terminates */

            /* close the variable server */
            VARSERVER_Close( pActions->hVarServer );
            pActions->hVarServer = NULL;


            if ( pActions->filename != NULL )
            {
                free( pActions->filename );
                pActions->filename = NULL;
            }
        }
    }

    return 0;
}

/*============================================================================*/
/*  ParseActions                                                              */
/*!
    Parse the actions from the actions definition file

    @param[in]
        filename
            pointer to the NUL terminated name of the actions
            definition file

    @retval EINVAL invalid arguments
    @retval EOK actions parsed successfully

==============================================================================*/
static int ParseActions( char *filename )
{
    int result = EINVAL;
    extern FILE *yyin;
    int tok;

    if ( filename != NULL )
    {
        /* open the actions definition file */
        yyin = fopen( filename, "r" );
        if ( yyin != NULL )
        {
            /* parse the actions file */
            if ( yyparse() == 0 )
            {
                result = EOK;
            }
        }
    }

    return result;
}

/*============================================================================*/
/*  usage                                                                     */
/*!
    Display the Actions usage

    The usage function dumps the application usage message
    to stderr.

    @param[in]
       cmdname
            pointer to the invoked command name

    @return none

==============================================================================*/
static void usage( char *cmdname )
{
    if( cmdname != NULL )
    {
        fprintf(stderr,
                "usage: %s [-v] [-h] [<filename>]\n"
                " [-h] : display this help\n"
                " [-v] : verbose output\n",
                cmdname );
    }
}

/*============================================================================*/
/*  ProcessOptions                                                            */
/*!
    Process the command line options

    The ProcessOptions function processes the command line options and
    populates the Actions object

    @param[in]
        argC
            number of arguments
            (including the command itself)

    @param[in]
        argv
            array of pointers to the command line arguments

    @param[in]
        pActions
            pointer to the Actions object

    @return 0

==============================================================================*/
static int ProcessOptions( int argC,
                           char *argV[],
                           Actions *pActions )
{
    int c;
    int result = EINVAL;
    const char *options = "hvoH:";

    if( ( pActions != NULL ) &&
        ( argV != NULL ) )
    {
        while( ( c = getopt( argC, argV, options ) ) != -1 )
        {
            switch( c )
            {
                case 'v':
                    pActions->verbose = true;
                    break;

                case 'o':
                    pActions->output = true;
                    break;

                case 'h':
                    usage( argV[0] );
                    break;

                default:
                    break;

            }
        }

        if ( optind < argC )
        {
            pActions->filename = strdup(argV[optind]);
        }
    }

    return 0;
}

/*============================================================================*/
/*  SetupTerminationHandler                                                   */
/*!
    Set up an abnormal termination handler

    The SetupTerminationHandler function registers a termination handler
    function with the kernel in case of an abnormal termination of this
    process.

==============================================================================*/
static void SetupTerminationHandler( void )
{
    static struct sigaction sigact;

    memset( &sigact, 0, sizeof(sigact) );

    sigact.sa_sigaction = TerminationHandler;
    sigact.sa_flags = SA_SIGINFO;

    sigaction( SIGTERM, &sigact, NULL );
    sigaction( SIGINT, &sigact, NULL );

}

/*============================================================================*/
/*  TerminationHandler                                                        */
/*!
    Abnormal termination handler

    The TerminationHandler function will be invoked in case of an abnormal
    termination of this process.  The termination handler closes
    the connection with the variable server and cleans up its VARFP shared
    memory.

@param[in]
    signum
        The signal which caused the abnormal termination (unused)

@param[in]
    info
        pointer to a siginfo_t object (unused)

@param[in]
    ptr
        signal context information (ucontext_t) (unused)

==============================================================================*/
static void TerminationHandler( int signum, siginfo_t *info, void *ptr )
{
    syslog( LOG_ERR, "Abnormal termination of actions\n" );

    if ( pActions != NULL )
    {
        if ( pActions->hVarServer != NULL )
        {
            VARSERVER_Close( pActions->hVarServer );
            pActions->hVarServer = NULL;
        }

        if( pActions->filename != NULL )
        {
            free( pActions->filename );
            pActions->filename = NULL;
        }

        free( pActions );
        pActions = NULL;
    }

    exit( 1 );
}

/*! @}
 * end of actions group */