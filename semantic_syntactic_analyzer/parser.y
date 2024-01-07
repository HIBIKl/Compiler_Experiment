%{
/* ��������ͷ�ļ� */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "header.h"
#define YYSTYPE node

codelist* list; // һЩ��Ҫ������ʵ��
char* prog_name;
extern int yylineno;
extern char* yytext;
extern int yylex();    
extern int iserror = 0;
%}

/* ���� token ������ʹ��, ͬʱҲ������ lex ��ʹ�� */
%token AND ARR BEG BOOL CALL CASE CHR CONST DIM DO ELSE END BOOLFALSE FOR IF INPUT INT NOT OF OR OUTPUT PROCEDURE PROGRAM READ REAL REPEAT SET STOP THEN TO BOOLTRUE UNTIL VAR WHILE WRITE RELOP
%token LB RB RCOMMENT LCOMMENT COMMA DOT TDOT COLON ASSIGN SEMI LT LE NE EQ RT RE LC RC
%token INTEGER id TRUECHAR FALSECHAR TRUECOMMENT FALSECOMMENT ILLEGALCHR

/* %left ��ʾ����, %right ��ʾ�ҽ�� */
/* ����г��Ķ��������ߵ����ȼ� */
%left ADD SUB
%left MUL DIV 

%left AND
%left OR
%left NOT
%left '+' '-'
%left '*' '/'
%right '='
%right ASSIGN
%nonassoc WITHOUT_ELSE

%start program

%%

// ---------------------------1 ������--------------------------------------
// 1.1 <����> �� program <��ʶ��> ; | program
program : PROGRAM program_name SEMI program
        
            | VAR var_definition program
            {
                // printf("\033[36m[info]\033[0m Variable Declaration: of type integer.\n"); // ֻ����ʾ���Ժ�Ҫɾ��
            }
            | BEG statement
            {
                // printf("\033[36m[info]\033[0m BEGIN\n"); // ֻ����ʾ���Ժ�Ҫɾ��
            }
            ;

program_name : id {
    prog_name = $1.lexeme;
    // printf("(%d) (program,%s,-,-)\n", quad_ruple_count, $1.lexeme); // ���õ����
                  }
                  ;
                  
var_definition : id COMMA var_definition
                | id COLON INT SEMI var_definition
                {
                    // printf("\033[36m[info]\033[0m FINISH VAR\n"); // ֻ����ʾ���Ժ�Ҫɾ��
                }
                | {}
                ;
// --------------------------------------------------------------------------


// ---------------------------2 ��䶨��--------------------------------------
// <���> �� <��ֵ��>��<if��>��<while��>��<repeat��>��<���Ͼ�>
statement : IF expression THEN M statement 
            {
                backpatch(list, $2.truelist, $4.instr);
                $$.nextlist = merge($2.falselist, $5.nextlist); 
            }

            |IF expression THEN M statement ELSE N M statement
            {
                backpatch(list, $2.truelist, $4.instr);    
                backpatch(list, $2.falselist, $8.instr);
                $5.nextlist = merge($5.nextlist, $7.nextlist);    
                $$.nextlist = merge($5.nextlist, $9.nextlist);
            }
            |WHILE M expression DO M statement
            {
                backpatch(list, $6.nextlist, $2.instr);    
                backpatch(list, $3.truelist, $5.instr);
                $$.nextlist = $3.falselist; 
                gen_goto(list, $2.instr);
            }

            |REPEAT M statement UNTIL M expression M statement
            {
                backpatch(list,$3.nextlist, $5.instr);
                backpatch(list, $6.falselist, $2.instr);
                backpatch(list, $6.truelist, $7.instr);
            }

            |calc_expression ASSIGN expression
            {
                copyaddr(&$1, $1.lexeme); 
                gen_assignment(list, $1, $3);
            }

            |L
            {
                $$.nextlist = $1.nextlist;
            }
            |{}
            ;

L   :   L SEMI M statement
        {
            backpatch(list, $1.nextlist, $3.instr);
            $$.nextlist = $4.nextlist;
        }
        |L END DOT M
        {
            backpatch(list,$1.nextlist,$4.instr);
            // printf("\033[36m[info]\033[0m FINISH PROGRAM\n"); // ֻ����ʾ���Ժ�Ҫɾ��
            YYACCEPT; // ����
        }
        |statement
        {
            $$.nextlist = $1.nextlist;
        }
        ;

// RELOP Ϊ���ֱ��
// "<"|"<="|">"|">="|"!="|"=" 
expression   :   expression AND M expression    
        {   
            backpatch(list, $1.truelist, $3.instr);
            $$.truelist = $4.truelist; 
            $$.falselist = merge($1.falselist, $4.falselist); 
        }
        |expression OR M expression
        {
            backpatch(list, $1.falselist, $3.instr);
            $$.falselist = $4.falselist; 
            $$.truelist = merge($1.truelist, $4.truelist); 
        }
        |NOT expression
        {
            $$.truelist = $2.falselist;
            $$.falselist = $2.truelist;
        }

        |calc_expression RELOP calc_expression
        {   
            $$.truelist = new_instrlist(nextinstr(list));
            $$.falselist = new_instrlist(nextinstr(list)+1);
            gen_if(list, $1, $2.oper, $3);
            gen_goto_blank(list); 
        }
                
        |calc_expression
        {
            copyaddr_fromnode(&$$, $1);
        }
        ;
// һЩ��������

calc_expression :   INTEGER 
                {
                    copyaddr(&$$, $1.lexeme);
                }

                |calc_expression ADD calc_expression 
                {
                    new_temp(&$$, get_temp_index(list));
                    gen_3addr(list, $$, $1, " +", $3);
                }

                |calc_expression SUB calc_expression 
                {
                    new_temp(&$$, get_temp_index(list));
                    gen_3addr(list, $$, $1, " -", $3);
                }
                |calc_expression MUL calc_expression 
                {
                    new_temp(&$$, get_temp_index(list)); 
                    gen_3addr(list, $$, $1, " *", $3);
                }

                |calc_expression DIV calc_expression 
                {
                    new_temp(&$$, get_temp_index(list)); 
                    gen_3addr(list, $$, $1, " /", $3);
                }
                |id 
                {
                    copyaddr(&$$, $1.lexeme);
                }
                ;
M   :   { $$.instr = nextinstr(list); }
        ;

N   :   {
            $$.nextlist = new_instrlist(nextinstr(list));
            gen_goto_blank(list);
        }
        ;

%%

char* removeNewline(char *str) {
    size_t length = strlen(str);

    if (length > 0) {
        // Check if the last character is a newline character
        if (str[length - 1] == '\n') {
            // Replace the newline character with a null terminator
            str[length - 1] = '\0';
        }
    } else {
        // If the string is empty, set it to NULL
        free(str);
        str = strdup("null");
    }

    return str;
}

void printTitleAndDesigners() {
    // �ǳ�cool�ı���
    printf("\033[35m   _____ ______  _______  __    ______     ___    _   _____    ____  _______   __________ \n");
    printf("  / ___//  _/  |/  / __ \\/ /   / ____/    /   |  / | / /   |  / /\\ \\/ /__  /  / ____/ __ \\ \n");
    printf("  \\__ \\ / // /|_/ / /_/ / /   / __/      / /| | /  |/ / /| | / /  \\  /  / /  / __/ / /_/ /\n");
    printf(" ___/ // // /  / / ____/ /___/ /___     / ___ |/ /|  / ___ |/ /___/ /  / /__/ /___/ _, _/ \n");
    printf("/____/___/_/  /_/_/   /_____/_____/    /_/  |_/_/ |_/_/  |_/_____/_/  /____/_____/_/ |_|  v1.0.0\n");
    printf("������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������\033[0m\n");
    // ������Ա��ʾ
    printf("��������������������������������������������������\n");
    printf("��ANALYZER MADE BY:      ��\n");
    printf("��������������     ��������������������������\n");
    printf("��������������     ��������������������������\n");
    printf("��������������     ��������������������������\n");
    printf("��������������������������������������������������\n");
}

int main() {
    char input_name[100];
    extern FILE *yyin;
    list = newcodelist();
    printTitleAndDesigners();


    printf("\033[36m[info]\033[0m Text your program name here:\n");

    // ��ȡԴ�ļ�
    if (scanf("%99s", input_name) != 1) {
        fprintf(stderr, "\033[31m[error]\033[0m Process terminated.\n");
        return 1;  // ctrl+c�ر��˳���
    }
    FILE* input_file = freopen(input_name, "rt+", stdin);
    if (input_file == NULL) {
        fprintf(stderr, "\033[31m[error]\033[0m No such file: %s\n", input_name);
        return 2;  // �����˲����ڵ��ļ���
    }

    // ������ʼ
    printf("\033[36m[info]\033[0m START ANALYZING.\n");
    yyparse();

    // ��Ϣ���
    if(iserror == 1)
        printf("\033[31m[error]\033[0m Process terminated.\n");
    else {
        print(list, prog_name);
        printf("\033[32m[info]\033[0m ANALYZE SUCCESSFULLY.\n");
    }

    return 0;
}

// Linux ��ע�͵��������
int yyerror(char *msg) {
    // ���������Ϣ�������ʹ����token
    fprintf(stderr, "\033[31m[%s]\033[0m at line %d. Unexpected character: %s\n",msg, yylineno, removeNewline(yytext)); 
    iserror = 1;
    return 0;
}
// Linux ��ע�͵��������
int yywrap(){
    return 1;
}