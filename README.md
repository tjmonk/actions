# actions
Action scripting engine

## Overview

The Actions scripting engine provides a mechanism to tie action scripts
to changes in VarServer variables, or to periodically run logic on
VarServer variables, or to run logic when a client requests the
value of a VarServer variables.

The scripting language is loosely based on C, and is compiled into a
binary tree of variable actions.  The actions supported are provided by the
libvaraction library.

Multiple instances of the actions engine can be run, each with its own
action script to create a collection of event driven logic with VarServer
variables as inputs and outputs.

## Prerequisites:

The actions scripting engine requires the following components:

- varserver : variable server ( https://github.com/tjmonk/varserver )
- libvaraction : actions library ( https://github.com/tjmonk/libvaraction )

## Building

```
$ ./build.sh
```
---
## Actions Scripting Language Overview

The action script is a c-like scripting language which is
parsed at run-time to build binary trees of varaction nodes
which can be executed when different events occur.

The action scripting engine is event driven, and takes no
actions unless events occur.  Thus it doesn't execute
continuously like a regular C program.

Supported events include, timer events, variable change events,
and variable value requests.

### Actions Container

Each script must contain an actions container of the form:

```
actions {
    name: "<name string>"
    description: "<description string>"

    < action list >
}
```

The actions directive can contain a list of action triggers.

Three types of action triggers are supported:

- timer events
- variable CALC requests
- variable MODIFIED notifications

### Timer Events

The actions scripting engine supports periodic actions based
on an internal timer.  A timer event declaration looks like this:

```

every <integer> <timeunit> {
    < code block >
}
```

Supported time units are:

- ms
- seconds
- minutes
- hours
- days
- weeks

A simple action to increment a VarServer variable every 1 second would
look like this:

```
every 1 seconds {
    /sys/test/b++;
}
```

Like C, statements within a code block are separated by semicolons.

The complete action script (increment.act) to increment the /sys/test/b
variable every second would look like this:

```
# increment /sys/test/b once per second
actions {
    every 1 seconds {
        /sys/test/b++;
    }
}
```

The script can be run by passing it to the actions engine as a command line
argument.

For example:

```
$ actions increment.act
```

### Variable Change Events

Actions can be triggered when a variable changes value.

For example we could create a metric to count the number of times
the variable /sys/test/a has changed as follows:

```
on change /sys/test/a {
    /metrics/changecount/a++;
}
```

### Variable Calc Requests

An event action can be invoked when a client requests the value of a
variable.  The example below increments /sys/test/i every time its
value is requested

```
on calc /sys/test/i {
    /sys/test/i++;
}

```

An action script can contain multiple event triggers.  So the
examples we have seen so far can be combined into a single
action script as follows:

```
# Actions script containing multiple triggers
actions {
    name: "Example1"
    description: "Composite action script"

    # increment /sys/test/b every second
    every 1 seconds {
        /sys/test/b++;
    }

    # count the number of times /sys/test/a is changed
    on change /sys/test/a {
        /metrics/changecount/a++;
    }

    # update /sys/test/i every time it is requested
    on calc /sys/test/i {
        /sys/test/i++;
    }
}

```

### Trigger lists

In the case of the on change and on calc triggers, a trigger list
consisting of one or more variable names is supported.  In the
case where more than one variable is specified, the variable names
are separated by commas.

eg.

```
on change /sys/test/a, /sys/test/b {
    # do something
}
```
### Conditional Execution

Like C, action scripts can have conditional execution in the form of
if-then and if-then-else statements.  If conditions can be simple or
compound conditionals just like in C.

For example,

```
on change /sys/test/a, /sys/test/b
if ( /sys/test/a > 10 && /sys/test/b > 10 ) {
    # do something
} else {
    # do something else
}
```

### Script execution

The actions engine can execute inline shell scripts that are contained within
three backticks.

Shell script snippets can occur anywhere an executable statement can occur.

For example:

```
# Track system uptime
actions {
    name: "Uptime"
    description: "System Uptime Tracker"

    # calculate system uptime every 10 seconds
    every 10 seconds {
        if ( /sys/uptime/enable > 0 ) {
            ```
            #!/bin/sh

            uptime >> /tmp/uptime.txt
            ```

            /metrics/uptime/count++;
        }
    }
}
```

### Local Variables

The action script supports local variable declarations.  Currently the following
variable types are supported:

- string ( array of NUL terminated characters )
- float ( IEEE754 floating point )
- short (16-bits )
- int ( 32-bits )

Local variables can contain intermediate calculations for use in conditionals,
or before they are written out to VarServer variables.

Like C, Local variables may be specified at the top of a statement block:

```
{
    float x;
    int y;
    short z;
    string str;
}
```

Local variables can be assigned from constants, VarServer variables, and
expressions.

For example, the following are all valid:

```
{
    x = 1.25;
    y = -32;
    z = 0xFF00;
    str = "This is a test";
}
```

Note that currently signed values are contained in unsigned storage
locations and mapped to unsigned VarServer variables.  This may change
in future as more types are introduced to align with the full set
of VarServer data types.

### Type conversion

Assigning values to variables of different types, or creating expressions
with values of different types requires type conversion.  Like in C,
type conversion is performed by prefixing the source variable with the type of
the target variable in parenthesis.

String conversion is an exception.  When converting to a string, you often
will want to specify an optional string format specifier.

The following example shows some type conversion.

```
# Measure analog voltages
actions {
    name: "AIN"
    description: "Measure Analog Inputs"

    on change /HW/ADS7830/A1
    {
        float v;
        int counts;
        string out;
        float vref;

        # set reference voltage
        vref = 3.3;

        # get analog input counts from ADS7830 channel A1
        counts = /HW/ADS7830/A1;

        # convert the counts into volts
        v = ((float)counts / 4096.0 ) * vref;

        # generate the output message
        out = "Ch 1: " + (string "%0.2f")v;

        # write the output
        /sys/test/c = out;
    }
}

```

### Expressions

Complex expressions can be created just like in C.
For example,

```
{
    short mask;

    mask = ( 0x0F << 4 ) | ( 1u << 3 ) | ( 1u << 2 ) | (1u << 1 );
}

```

## Run the examples

To run the examples you will need to create the necessary VarServer
variables.

Note that the examples are not really designed to be run together due to
potential interactions between the variables, so run them one at a time.

Create the necessary variables as follows:

```
$ mkvar -t uint16 -n /sys/test/a
$ mkvar -t uint32 -n /sys/test/b
$ mkvar -t uint16 -n /sys/test/i
$ mkvar -t str -n /sys/test/c
$ mkvar -t uint32 -n /sys/test/limit
$ mkvar -t uint16 -n /sys/uptime/enable
$ mkvar -t uint32 -n /metrics/uptime/count
$ mkvar -t uint32 -n /metrics/a/count
$ mkvar -t uint16 -n /HW/ADS7830/A1
```

### Run example 1

```
$ actions test/example1.act &
```

### Run example 2

```
$ actions test/example2.act &
```

### Run example 3

```
$ actions test/example3.act &
```

### Run example 4

```
$ actions test/example4.act &
```

---
## Action Script Language Specification

Refer to the language specification below for a full description of the action
script language.

```
actions : ACTIONS LBRACE name description action_list RBRACE
             ;

name: NAME COLON string
    ;

description :  DESCRIPTION COLON string
            ;

action_list
		: 	action action_list
        ;

action
        :   ON CALC signal_list LBRACE declaration_list statement_list RBRACE
        |   ON CHANGE signal_list LBRACE declaration_list statement_list RBRACE
        |   EVERY number timespan LBRACE declaration_list statement_list RBRACE
        ;

timespan : MS
         | SECONDS
         | MINUTES
         | HOURS
         | DAYS
         | WEEKS
         ;

signal_list : signal COMMA signal_list
        |   signal
        ;

signal : identifier
       ;

statement_list : statement statement_list

statement : expression SEMICOLON
          | selection_statement
          | script
          | SEMICOLON
          ;

declaration_list : declaration SEMICOLON declaration_list
            ;

declaration : type_specifier decl_id
            ;

type_specifier : FLOAT
               | INT
               | SHORT
               | STRING
               ;

selection_statement
		:	IF LPAREN expression RPAREN compound_statement   %prec "then"
		|	IF LPAREN expression RPAREN compound_statement ELSE compound_statement
		;

compound_statement: LBRACE statement_list RBRACE
        ;

expression: assignment_expression
        ;

assignment_expression
        :   logical_OR_expression
        |   identifier assignment_operator assignment_expression
        ;

assignment_operator
        : ASSIGN
        | TIMES_EQUALS
        | DIV_EQUALS
        | PLUS_EQUALS
        | MINUS_EQUALS
        | AND_EQUALS
        | OR_EQUALS
        | XOR_EQUALS
        ;

logical_OR_expression
        :   logical_AND_expression
        |   logical_OR_expression OR logical_AND_expression
        ;

logical_AND_expression
        : inclusive_OR_expression
        | logical_AND_expression AND inclusive_OR_expression
        ;

inclusive_OR_expression
        :   exclusive_OR_expression
        |   inclusive_OR_expression BOR exclusive_OR_expression
        ;

exclusive_OR_expression
        : AND_expression
        | exclusive_OR_expression XOR AND_expression
        ;

AND_expression
        :   equality_expression
        |   AND_expression BAND equality_expression
        ;

equality_expression
        :   relational_expression
        |   equality_expression EQUALS relational_expression
        |   equality_expression NOTEQUALS relational_expression
        ;

relational_expression
        :   shift_expression
        |   relational_expression LT shift_expression
        |   relational_expression GT shift_expression
        |   relational_expression LTE shift_expression
        |   relational_expression GTE shift_expression
        ;

shift_expression
        :   additive_expression
        |   shift_expression LSHIFT additive_expression
        |   shift_expression RSHIFT additive_expression
        ;

additive_expression
        :   multiplicative_expression
        |   additive_expression ADD multiplicative_expression
        |   additive_expression SUB multiplicative_expression
        ;

multiplicative_expression
        :   unary_expression
        |   multiplicative_expression MUL unary_expression
        |   multiplicative_expression DIV unary_expression
        ;

unary_expression
        :   typecast_expression
        |   INC identifier
        |   DEC identifier
        |   NOT unary_expression
        ;

typecast_expression
        : postfix_expression
        | float_cast number
        | float_cast identifier
        | int_cast floatnum
        | int_cast identifier
        | short_cast number
        | short_cast floatnum
        | short_cast identifier
        | string_cast identifier
        | LPAREN STRING string RPAREN identifier
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
        |   identifier INC
        |   identifier DEC
        ;

primary_expression
        ;

script : SCRIPT
       ;

string : CHARSTR
       ;

number : NUM
    ;

floatnum : FLOATNUM
         ;

identifier : ID
   ;

decl_id : ID
   ;
```





