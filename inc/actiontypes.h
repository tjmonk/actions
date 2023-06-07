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

#ifndef ACTIONTYPES_H
#define ACTIONTYPES_H

/*==============================================================================
        Includes
==============================================================================*/

#include <varserver/varserver.h>
#include <varaction/varaction.h>

/*==============================================================================
        Public Definitions
==============================================================================*/

#ifndef EOK
/*! success response */
#define EOK 0
#endif

/*! variable change notification */
#define VAR_NOTIFICATION SIGRTMIN+6

/*! calculation notification */
#define CALC_NOTIFICATION SIGRTMIN+7

/*! local variable declaration */
typedef struct _declaration
{
    /*! variable name */
    char *name;

    /*! line number */
    int lineno;

    /*! variable value */
    VarObject obj;

    /*! pointer to the next variable */
    struct _declaration *pNext;
} Declaration;


/*! signal structure */
typedef struct _sigHandle
{
    /*! line number */
    int lineno;

    /*! signal identifier */
    int id;

    /*! pointer to the variable associated with this signal */
    Variable *pVariable;

    /*! pointer to the next variable */
    struct _sigHandle *pNext;
} Signal;

/*! list of actions */
typedef struct _action
{
    /*! pointer to the local variable declarations for the action */
    Variable *pDeclarations;

    /*! pointer to the system variable declarations for the action */
    Variable *pSysVars;

    /*! signal type associated with this action */
    int signal;

    /*! timer associated with this action (if any) */
    int timerID;

    /*! pointer to the signals we need to watch */
    Signal *pSignals;

    /*! pointer to the statements associated with this action */
    Statement *pStatements;

    /*! pointer to the next action */
    struct _action *pNext;
} Action;

/*! Actions object */
typedef struct _actions
{
    /*! handle to the variable server */
    VARSERVER_HANDLE hVarServer;

    /*! state machine definition file */
    char *filename;

    /*! name of this state machine */
    char *name;

    /*! description of this state machine */
    char *description;

    /*! verbose mode */
    bool verbose;

    /*! output state machine documentation */
    bool output;

    /*! pointer to the first state in a list of states */
    Action *pActionList;
} Actions;

#endif

