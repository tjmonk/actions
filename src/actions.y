%{
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

/*==============================================================================
        Includes
==============================================================================*/

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <stdbool.h>
#include <limits.h>
#include <signal.h>
#include <syslog.h>
#include <varserver/varserver.h>
#include <varaction/varaction.h>
#include "actiontypes.h"
#include "timer.h"
#include "lineno.h"

/*==============================================================================
       Definitions
==============================================================================*/

#define YYSTYPE void *

#ifdef YYDEBUG
  yydebug = 1;
#endif

extern char *yytext;

/* input file for lex */
extern FILE *yyin;

/* output file */
static FILE *fp;

/* function declarations */

void yyerror( char *msg );

extern Actions *pActions;

int yylex(void);

/* error flag */
static bool errorFlag = false;

/*==============================================================================
       Function definitions
==============================================================================*/

static void *OnInit( void *declarations, void *statements );
static void *OnCalc( bool init,
                     void *signals,
                     void *declarations,
                     void *statements );
static void *OnChange( bool init,
                       void *signals,
                       void *declarations,
                       void *statements );
static void *Every( bool init,
                    void *interval,
                    void *timespan,
                    void *declaration_list,
                    void *statement_list );

static int RequestCalcSignals( Signal *pSignal );
static int RequestModifiedSignals( Signal *pSignal );
static void *NewSignal( void *variable );

%}

%token ACTIONS
%token NAME
%token DESCRIPTION
%token EVERY
%token ON
%token CHANGE
%token CALC
%token INIT
%token MS
%token SECONDS
%token MINUTES
%token HOURS
%token DAYS
%token WEEKS
%token IF
%token ELSE
%token AND
%token OR
%token NOT
%token COLON
%token COMMA
%token SEMICOLON
%token ASSIGN
%token EQUALS
%token NOTEQUALS
%token AND_EQUALS
%token OR_EQUALS
%token XOR_EQUALS
%token DIV_EQUALS
%token TIMES_EQUALS
%token PLUS_EQUALS
%token MINUS_EQUALS
%token GT
%token LT
%token GTE
%token LTE
%token LPAREN
%token RPAREN
%token LBRACE
%token RBRACE
%token LBRACKET
%token RBRACKET
%token ADD
%token SUB
%token MUL
%token DIV
%token ID
%token DQUOTE
%token CHARSTR
%token NUM
%token FLOATNUM
%token SCRIPT
%token FLOAT
%token INT
%token SHORT
%token STRING
%token BAND
%token BOR
%token XOR
%token INC
%token DEC
%token LSHIFT
%token RSHIFT
%token LOCALVAR
%token SYSVAR
%token TOSTRING

%nonassoc "then"
%nonassoc ELSE

%%
actions : ACTIONS LBRACE name description action_list RBRACE
			 {
                if ( pActions != NULL )
                {
                    pActions->name = $3;
                    pActions->description = $4;
                    pActions->pActionList = $5;
                }
                $$ = pActions;
             }
             ;

name: NAME COLON string
    {
        $$ = $3;
    }
    ;

description :  DESCRIPTION COLON string
            {
                $$ = $3;
            }
            ;

action_list
		: 	action action_list
			{
                Action *pAction = $1;
                if ( pAction != NULL )
                {
                    pAction->pNext = $2;
                }
                $$ = pAction;
			}

        | 	{ $$ = NULL; }
        ;

action
        :   ON INIT LBRACE declaration_list statement_list RBRACE
            {
                $$ = OnInit( $4, $5 );
            }
        |   ON CALC signal_list LBRACE declaration_list statement_list RBRACE
            {
                $$ = OnCalc( false, $3, $5, $6 );
            }
        |   ON CALC INIT signal_list LBRACE declaration_list statement_list RBRACE
            {
                $$ = OnCalc( true, $4, $6, $7 );
            }
        |   ON INIT CALC signal_list LBRACE declaration_list statement_list RBRACE
            {
                $$ = OnCalc( true, $4, $6, $7 );
            }
        |   ON CHANGE signal_list LBRACE declaration_list statement_list RBRACE
            {
                $$ = OnChange( false, $3, $5, $6 );
            }
        |   ON CHANGE INIT signal_list LBRACE declaration_list statement_list RBRACE
            {
                $$ = OnChange( true, $4, $6, $7 );
            }
        |   ON INIT CHANGE signal_list LBRACE declaration_list statement_list RBRACE
            {
                $$ = OnChange( true, $4, $6, $7 );
            }
        |   EVERY number timespan LBRACE declaration_list statement_list RBRACE
            {
                $$ = Every( false, $2, $3, $5, $6 );
            }
        |   INIT EVERY number timespan LBRACE declaration_list statement_list RBRACE
            {
                $$ = Every( false, $3, $4, $6, $7 );
            }
        |   EVERY INIT number timespan LBRACE declaration_list statement_list RBRACE
            {
                $$ = Every( false, $3, $4, $6, $7 );
            }
        ;

timespan : MS { $$ = (void *)TIMESCALE_eMILLISECONDS; }
         | SECONDS { $$ = (void *)TIMESCALE_eSECONDS; }
         | MINUTES { $$ = (void *)TIMESCALE_eMINUTES; }
         | HOURS { $$ = (void *)TIMESCALE_eHOURS; }
         | DAYS { $$ = (void *)TIMESCALE_eDAYS; }
         | WEEKS { $$ = (void *)TIMESCALE_eWEEKS; }
         ;

signal_list : signal COMMA signal_list
        {
            Signal *pSignal = (Signal *)$1;
            if ( pSignal != NULL )
            {
                pSignal->pNext = $3;
            }

            $$ = $1;
        }
        |   signal
        {
            $$ = $1;
        }
        |
        {
            $$ = NULL;
        }
        ;

signal : identifier
        {
            $$ = NewSignal( $1 );
        }
       ;

statement_list : statement statement_list
        {
            Statement *pStatement = (Statement *)$1;
            if ( pStatement != NULL )
            {
                pStatement->pNext = $2;
            }
            $$ = $1;
        }
        | { $$ = NULL; }
        ;

statement : expression SEMICOLON
            {
               Statement *pStatement = (Statement *)calloc( 1, sizeof( Statement ) );
               if ( pStatement != NULL )
               {
                   pStatement->pVariable = $1;
               }

               $$ = (void *)pStatement;
            }
          | selection_statement
            {
               Statement *pStatement = (Statement *)calloc( 1, sizeof( Statement ) );
               if ( pStatement != NULL )
               {
                   pStatement->pVariable = $1;
               }

               $$ = (void *)pStatement;
            }
          | script
            {
               Statement *pStatement = (Statement *)calloc( 1, sizeof( Statement ) );
               if ( pStatement != NULL )
               {
                   pStatement->script = (char *)$1;
               }

               $$ = (void *)pStatement;
            }
          | SEMICOLON
            {
            }
          ;

declaration_list : declaration SEMICOLON declaration_list
                   {
                        Variable *pVariable = (Variable *)$1;
                        if ( pVariable != NULL )
                        {
                            pVariable->pNext = $3;
                        }

                        $$ = $1;

                        /* set up the local variable declarations */
                        SetDeclarations( pVariable );
                    }
                 | { $$ = NULL; }

declaration : type_specifier decl_id
            {
                $$ = CreateDeclaration( (uintptr_t)$1, $2 );
            }
            ;

type_specifier : FLOAT { $$ = (void *)VA_FLOAT; }
               | INT { $$ = (void *)VA_INT; }
               | SHORT { $$ = (void *)VA_SHORT; }
               | STRING { $$ = (void *)VA_STRING; }
               ;

selection_statement
		:	IF LPAREN expression RPAREN compound_statement   %prec "then"
			{ $$ = CreateVariable(VA_IF,$3, CreateVariable(VA_ELSE,$5,NULL)); }

		|	IF LPAREN expression RPAREN compound_statement ELSE compound_statement
			{ $$ = CreateVariable(VA_IF,$3, CreateVariable(VA_ELSE,$5,$7)); }
		;

compound_statement: LBRACE statement_list RBRACE
            { $$ = $2; }
        ;

expression: assignment_expression
        {
            $$ = $1;
        }
        ;

assignment_expression
        :   logical_OR_expression
        {
            $$ = $1;
        }
        |   identifier assignment_operator assignment_expression
        {
            Variable *pVariable = (Variable *)$1;
            if ( pVariable != NULL )
            {
                pVariable->lvalue = true;
                pVariable->assigned = true;
            }

            $$ = CreateVariable( (uintptr_t)$2, $1, $3 );
        }
        ;

assignment_operator
        : ASSIGN
        { $$ = (void *)VA_ASSIGN; }
        | TIMES_EQUALS
        { $$ = (void *)VA_TIMES_EQUALS; }
        | DIV_EQUALS
        { $$ = (void *)VA_DIV_EQUALS; }
        | PLUS_EQUALS
        { $$ = (void *)VA_PLUS_EQUALS; }
        | MINUS_EQUALS
        { $$ = (void *)VA_MINUS_EQUALS; }
        | AND_EQUALS
        { $$ = (void *)VA_AND_EQUALS; }
        | OR_EQUALS
        { $$ = (void *)VA_OR_EQUALS; }
        | XOR_EQUALS
        { $$ = (void *)VA_XOR_EQUALS; }
        ;

logical_OR_expression
        :   logical_AND_expression
        {
            $$ = $1;
        }
        |   logical_OR_expression OR logical_AND_expression
        {
            $$ = CreateVariable( VA_OR, $1, $3 );
        }
        ;

logical_AND_expression
        : inclusive_OR_expression
        {
            $$ = $1;
        }
        | logical_AND_expression AND inclusive_OR_expression
        {
            $$ = CreateVariable( VA_AND, $1, $3 );
        }
        ;

inclusive_OR_expression
        :   exclusive_OR_expression
        {
            $$ = $1;
        }
        |   inclusive_OR_expression BOR exclusive_OR_expression
        {
            $$ = CreateVariable( VA_BOR, $1, $3 );
        }
        ;

exclusive_OR_expression
        : AND_expression
        {
            $$ = $1;
        }
        | exclusive_OR_expression XOR AND_expression
        {
            $$ = CreateVariable( VA_XOR, $1, $3 );
        }
        ;

AND_expression
        :   equality_expression
        {
            $$ = $1;
        }
        |   AND_expression BAND equality_expression
        {
            $$ = CreateVariable( VA_BAND, $1, $3 );
        }
        ;

equality_expression
        :   relational_expression
        {
            $$ = $1;
        }
        |   equality_expression EQUALS relational_expression
        {
            $$ = CreateVariable( VA_EQUALS, $1, $3 );
        }
        |   equality_expression NOTEQUALS relational_expression
        {
            $$ = CreateVariable( VA_NOTEQUALS, $1, $3 );
        }
        ;

relational_expression
        :   shift_expression
        {
            $$ = $1;
        }
        |   relational_expression LT shift_expression
        {
            $$ = CreateVariable( VA_LT, $1, $3 );
        }
        |   relational_expression GT shift_expression
        {
            $$ = CreateVariable( VA_GT, $1, $3 );
        }
        |   relational_expression LTE shift_expression
        {
            $$ = CreateVariable( VA_LTE, $1, $3 );
        }
        |   relational_expression GTE shift_expression
        {
            $$ = CreateVariable( VA_GTE, $1, $3 );
        }
        ;

shift_expression
        :   additive_expression
        {
            $$ = $1;
        }
        |   shift_expression LSHIFT additive_expression
        {
            $$ = CreateVariable( VA_LSHIFT, $1, $3 );
        }
        |   shift_expression RSHIFT additive_expression
        {
            $$ = CreateVariable( VA_RSHIFT, $1, $3 );
        }
        ;

additive_expression
        :   multiplicative_expression
        {
            $$ = $1;
        }
        |   additive_expression ADD multiplicative_expression
        {
            $$ = CreateVariable( VA_ADD, $1, $3 );
        }
        |   additive_expression SUB multiplicative_expression
        {
            $$ = CreateVariable( VA_SUB, $1, $3 );
        }
        ;

multiplicative_expression
        :   unary_expression
        {
            $$ = $1;
        }
        |   multiplicative_expression MUL unary_expression
        {
            $$ = CreateVariable( VA_MUL, $1, $3 );
        }
        |   multiplicative_expression DIV unary_expression
        {
            $$ = CreateVariable( VA_DIV, $1, $3 );
        }
        ;

unary_expression
        :   typecast_expression
        {
            $$ = $1;
        }
        |   INC identifier
        {
            CheckUseBeforeAssign($2);
            $$ = CreateVariable( VA_INC, NULL, $2 );
        }
        |   DEC identifier
        {
            CheckUseBeforeAssign($2);
            $$ = CreateVariable( VA_DEC, NULL, $2 );
        }
        |   NOT unary_expression
        {
            $$ = CreateVariable( VA_NOT, $2, NULL );
        }
        ;

typecast_expression
        : postfix_expression
        {
            $$ = $1;
        }
        | float_cast number
        {
            $$ = CreateVariable(VA_TOFLOAT, $2, NULL );
        }
        | float_cast identifier
        {
            CheckUseBeforeAssign($2);
            $$ = CreateVariable( VA_TOFLOAT, $2, NULL );
        }
        | int_cast floatnum
        {
            $$ = CreateVariable( VA_TOINT, $2, NULL );
        }
        | int_cast identifier
        {
            CheckUseBeforeAssign($2);
            $$ = CreateVariable( VA_TOINT, $2, NULL );
        }
        | short_cast number
        {
            CheckUseBeforeAssign($2);
            $$ = CreateVariable( VA_TOSHORT, $2, NULL );
        }
        | short_cast floatnum
        {
            CheckUseBeforeAssign($2);
            $$ = CreateVariable( VA_TOSHORT, $2, NULL );
        }
        | short_cast identifier
        {
            CheckUseBeforeAssign($2);
            $$ = CreateVariable( VA_TOSHORT, $2, NULL );
        }
        | string_cast identifier
        {
            CheckUseBeforeAssign($2);
            $$ = CreateVariable( VA_TOSTRING, $2, NULL );
        }
        | LPAREN STRING string RPAREN identifier
        {
            CheckUseBeforeAssign($5);
            $$ = CreateVariable( VA_TOSTRING, $5, $3 );
        }
        ;

float_cast:	LPAREN FLOAT RPAREN
		;

int_cast : LPAREN INT RPAREN
		;

short_cast : LPAREN SHORT RPAREN
           ;

string_cast : LPAREN STRING RPAREN
            ;

postfix_expression
        :   primary_expression
        {
            $$ = $1;
        }
        |   identifier INC
        {
            CheckUseBeforeAssign($1);
            $$ = CreateVariable( VA_INC, $1, NULL );
        }
        |   identifier DEC
        {
            CheckUseBeforeAssign($1);
            $$ = CreateVariable( VA_DEC, $1, NULL );
        }
        ;

primary_expression
        :   identifier
            {
                CheckUseBeforeAssign($1);
                $$ = $1;
            }
        |   LPAREN expression RPAREN
            {
                $$ = $2;
            }
        |   floatnum
            {
                $$ = $1;
            }
        |   number
            {
                $$ = $1;
            }
        |   string
            {
                $$ = $1;
            }
        ;

script : SCRIPT
       {
          $$ = strdup( yytext );
       }
       ;

string : CHARSTR
        {
            $$ = NewString( yytext );
        }
       ;

number : NUM
    {
       $$ = NewNumber( yytext );
    }
    ;

floatnum : FLOATNUM
         {
            $$ = NewFloat( yytext );
         }
         ;

identifier : ID
   {
        $$ = NewIdentifier( pActions->hVarServer, yytext, false );
   }
   ;

decl_id : ID
   {
        $$ = NewIdentifier( pActions->hVarServer, yytext, true );
   }
   ;

%%
#include <stdio.h>

/*============================================================================*/
/*  yyerror                                                                   */
/*!
    Handle parser error

	This procedure displays an error message with the line number on
	which the error occurred.

@param[in]
    err
        the error message to be displayed

@return none

==============================================================================*/
void yyerror( char *err )
{
    printf("%s at line %d\n",err, getlineno() + 1);
    errorFlag = true;
}

/*============================================================================*/
/*  OnChange                                                                  */
/*!
    Create an OnChange action

    The OnChange function creates an OnChange Action

@param[in]
    init
        boolean flag indicating if the actions should run on initialization

@param[in]
    signals
        pointer to a list of signals to watch for

@param[in]
    declarations
        pointer to a list of variable declarations for this action

@param[in]
    statements
        pointer to the list of statements to execute for this action

@retval pointer to the Action that we created
@retval NULL if an error occurred

==============================================================================*/
static void *OnChange( bool init,
                       void *signals,
                       void *declarations,
                       void *statements )
{
    Signal *pSignal;
    int result;
    Action *pAction;

    pAction = (Action *)calloc( 1, sizeof( Action ) );
    if ( pAction != NULL )
    {
        pAction->init = init;
        pAction->pSignals = (Signal *)signals;
        pAction->pDeclarations = (Variable *)declarations;
        pAction->pStatements = (Statement *)statements;
        pAction->signal = VAR_NOTIFICATION;

        RequestModifiedSignals( pAction->pSignals );
    }

    /* clear the global declaration list */
    SetDeclarations( NULL );

    return (void *)pAction;
}

/*============================================================================*/
/*  OnInit                                                                    */
/*!
    Create an OnInit action

    The OnInit function creates an OnInit Action which will be processed
    on startup

@param[in]
    declarations
        pointer to a list of variable declarations for this action

@param[in]
    statements
        pointer to the list of statements to execute for this action

@retval pointer to the Action that we created
@retval NULL if an error occurred

==============================================================================*/
static void *OnInit( void *declarations, void *statements )
{
    Signal *pSignal;
    int result;
    Action *pAction;

    pAction = (Action *)calloc( 1, sizeof( Action ) );
    if ( pAction != NULL )
    {
        pAction->init = true;
        pAction->pSignals = NULL;
        pAction->signal = NO_NOTIFICATION;
        pAction->pDeclarations = (Variable *)declarations;
        pAction->pStatements = (Statement *)statements;
    }

    /* clear the global declaration list */
    SetDeclarations( NULL );

    return (void *)pAction;
}

/*============================================================================*/
/*  OnCalc                                                                    */
/*!
    Create an OnCalc action

    The OnCalc function creates an OnCalc Action

@param[in]
    init
        boolean flag indicating if the actions should run on initialization

@param[in]
    signals
        pointer to a list of signals to watch for

@param[in]
    declarations
        pointer to a list of variable declarations for this action

@param[in]
    statements
        pointer to the list of statements to execute for this action

@retval pointer to the Action that we created
@retval NULL if an error occurred

==============================================================================*/
static void *OnCalc( bool init,
                     void *signals,
                     void *declarations,
                     void *statements )
{
    Signal *pSignal;
    int result;
    Action *pAction;

    pAction = (Action *)calloc( 1, sizeof( Action ) );
    if ( pAction != NULL )
    {
        pAction->init = init;
        pAction->pSignals = (Signal *)signals;
        pAction->signal = CALC_NOTIFICATION;
        pAction->pDeclarations = (Variable *)declarations;
        pAction->pStatements = (Statement *)statements;

        RequestCalcSignals( pAction->pSignals );
    }

    /* clear the global declaration list */
    SetDeclarations( NULL );

    return (void *)pAction;
}

/*============================================================================*/
/*  Every                                                                     */
/*!
    Create a new actions group which runs on a schedule

    The Every function creates a new actions group which runs at the
    specified schedule

@param[in]
    init
        boolean flag indicating if the actions should run on initialization

@param[in]
    interval
        pointer to an interval variable

@param[in]
    timescale
        time scale enumerated value

@param[in]
    declaration_list
        pointer to a declaration list

@param[in]
    statement_list
        pointer to the list of statements to execute for this action

@retval pointer to the Action that we created
@retval NULL if an error occurred

==============================================================================*/
static void *Every( bool init,
                    void *interval,
                    void *timescale,
                    void *declaration_list,
                    void *statement_list )
{
    Action *pAction = NULL;
    Variable *pVariable = (Variable *)interval;
    Timescale ts = (Timescale)timescale;
    int num = 0;

    pAction = (Action *)calloc( 1, sizeof( Action ) );
    if ( pAction != NULL )
    {
        pAction->init = init;
        pAction->pDeclarations = declaration_list;
        pAction->pStatements = statement_list;
        pAction->signal = TIMER_NOTIFICATION;

        switch ( pVariable->obj.type )
        {
            case VARTYPE_UINT16:
                num = pVariable->obj.val.ui;
                break;

            case VARTYPE_UINT32:
                num = pVariable->obj.val.ul;
                break;

            default:
                num = 0;
                break;
        }

        if ( num != 0 )
        {
            pAction->timerID = CreateTick( num, ts );
        }

        if( pAction->timerID <= 0 )
        {
            yyerror("Failed to create timer");
        }
    }

    /* clear the global declaration list */
    SetDeclarations( NULL );

    return pAction;
}

/*============================================================================*/
/*  NewSignal                                                                 */
/*!
    Create a new variable signal

    The NewSignal function creates a new variable signal which can
    be used to trigger an action group

@param[in]
    id
        pointer to the signal identifier

@retval pointer to the Signal that we created
@retval NULL if an error occurred

==============================================================================*/
static void *NewSignal( void *variable )
{
    Signal *pSignal = NULL;
    Variable *pVariable = (Variable *)variable;

    if ( pVariable != NULL )
    {
        pSignal = (Signal *)calloc(1, sizeof(Signal) ) ;
        if ( pSignal != NULL )
        {
            pSignal->lineno = getlineno();
            pSignal->pVariable = pVariable;
            pSignal->id = pVariable->hVar;
        }
    }

    return (void *)pSignal;
}

/*============================================================================*/
/*  RequestCalcSignals                                                        */
/*!
    Request CALC notifications for all of the variables in the signals list

    The RequestCalcSignals function iterates through the specified signals
    list and requests a NOTIFY_CALC notification for all variables referenced
    in the signals list.

@param[in]
    pSignal
        pointer to the first signal in the signal list

@retval EOK the notifications were successfully requested
@retval EINVAL invalid arguments

==============================================================================*/
static int RequestCalcSignals( Signal *pSignal )
{
    int result = EOK;
    Variable *pVariable;
    VAR_HANDLE hVar;
    int rc;

    while( pSignal != NULL )
    {
        pVariable = pSignal->pVariable;
        if( ( pVariable != NULL ) &&
            ( pVariable->calcNotification == false ) )
        {
            /* get a handle to the variable */
            hVar = pVariable->hVar;
            if ( hVar != VAR_INVALID )
            {
                /* request a CALC notification */
                rc = VAR_Notify( pActions->hVarServer,
                                 hVar,
                                 NOTIFY_CALC );
                if ( rc == EOK )
                {
                    /* set flag to make sure we don't request this
                       variable again */
                    pVariable->calcNotification = true;
                }
                else
                {
                    result = rc;
                    fprintf( stderr,
                             "Cannot register calc notification for %s\n",
                             pVariable->id );
                }
            }
        }

        /* move to the next signal */
        pSignal = pSignal->pNext;
    }

    return result;
}

/*============================================================================*/
/*  RequestModifiedSignals                                                    */
/*!
    Request MODIFIED notifications for all of the variables in the signals list

    The RequestModifiedSignals function iterates through the specified signals
    list and requests a NOTIFY_MODIIED notification for all variables referenced
    in the signals list.

@param[in]
    pSignal
        pointer to the first signal in the signal list

@retval EOK the notifications were successfully requested
@retval EINVAL invalid arguments

==============================================================================*/
static int RequestModifiedSignals( Signal *pSignal )
{
    int result = EOK;
    Variable *pVariable;
    VAR_HANDLE hVar;
    int rc;

    while( pSignal != NULL )
    {
        pVariable = pSignal->pVariable;
        if( ( pVariable != NULL ) &&
            ( pVariable->modifiedNotification == false ) )
        {
            /* get a handle to the variable */
            hVar = pVariable->hVar;
            if ( hVar != VAR_INVALID )
            {
                /* request a MODIIED notification */
                rc = VAR_Notify( pActions->hVarServer,
                                     hVar,
                                     NOTIFY_MODIFIED );
                if ( rc == EOK )
                {
                    /* set flag to make sure we don't request this
                       variable again */
                    pVariable->modifiedNotification = true;
                }
                else
                {
                    result = rc;
                    fprintf( stderr,
                             "Cannot register change notification for %s\n",
                             pVariable->id );
                }
            }
        }

        /* move to the next signal */
        pSignal = pSignal->pNext;
    }

    return result;
}

