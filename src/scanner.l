%{

(* Copyright 2012-2014 Chong Cheung. All rights reserved.
 * Use of this source code is governed by a BSD-style license
 * that can be found in the LICENSE file.
 * Compile: plex scanner.l
 * 			fpc scanner.pas
 *)

%}

%{

{$I indent_stack.pas}

function upper(str : String) : String;
var i : integer;
begin
	for i := 1 to length(str) do
		str[i] := upCase(str[i]);
	upper := str
end;

function fix_char_len(str : String; num:integer) : String;
begin
	while length(str) < num do
		str := str + ' ';
	fix_char_len := str
end;

procedure has_token_notext(str : String);
begin
	if(debuginfo) then
		writeln(showfilename,'(',(yylineno-line_ignore):4,',',(yycolno-yyleng):2,') Info Token=',fix_char_len(upper(str),15));
	if (str <> 'INDENT') and (str <> 'DEDENT') then
		pre_token := upper(str);
end;

procedure has_token(str : String); overload;
begin
	yylval := yytext;
	if(debuginfo) then
		writeln(showfilename,'(',(yylineno-line_ignore):4,',',(yycolno-yyleng):2,') Info Token=',fix_char_len(upper(str),15),' Text=`',yytext,'`');
	if (str <> 'INDENT') and (str <> 'DEDENT') then
		pre_token := upper(str);
end;

procedure has_token; overload;
begin
	has_token(yytext);
end;

procedure comment_eof;
begin
	writeln('unexpected EOF inside comment at line ', yylineno);
end;

procedure change_state_for_ast(state:integer);
begin
	case state of
		state_none,
		state_program,
		state_interface,
		state_class: begin
				if ast_state_list.count <> 0 then
				begin
					if (ast_state_list.last =state_program) or
					(ast_state_list.last =state_interface) or
					(ast_state_list.last =state_class) then 
					begin
						icode_add(TEnd.Create);
						icode_finish();
					end;
				end;
			end;
		state_constructor: ;
		state_function: ;
		state_procedure: ;
		state_event: ;
		state_state: ;
		state_if:;
		state_else:;
		state_for:;
		state_while:;
	end;
	icode_tmplist.add(TNodeList.Create);
	case state of
		state_program,
		state_interface,
		state_class: begin
				if ast_state_list.count = 0 then
				begin
					if (state =state_program) then
						icode_add(TProgram.Create(''))
					else if (state =state_interface) then
						icode_add(TInterface.Create(''))
					else if (state =state_class) then
						icode_add(TClass.Create('','',''));
					icode_add(TBegin.Create);
				end;
			end;
	end;
	ast_state_list.add(state);
end;

procedure change_state(state:integer);
begin
	state_list.add(state);
	if (state = state_constructor) or 
		(state = state_function) or 
		(state = state_procedure) or 
		(state = state_state) or 
		(state = state_event) then
		line_no_for_method_define := (yylineno-line_ignore);
	case state of
		state_program: object_symtab.add(TObjectSymTable.Create('',t_program));
		state_interface: object_symtab.add(TObjectSymTable.Create('',t_interface));
		state_class: object_symtab.add(TObjectSymTable.Create('',t_class));
		state_constructor: object_symtab.last.methods.add(TMethodSymTable.Create('',t_constructor));
		state_function: object_symtab.last.methods.add(TMethodSymTable.Create('',t_function));
		state_procedure: object_symtab.last.methods.add(TMethodSymTable.Create('',t_procedure));
		state_event: object_symtab.last.methods.add(TMethodSymTable.Create('',t_event));
		state_state: object_symtab.last.methods.add(TMethodSymTable.Create('',t_state));
	end;
	change_state_for_ast(state);
end;

%}

%%

and								begin has_token;return(tkAND); end;

array							begin has_token;return(tkARRAY); end;

await 							begin has_token;return(tkAWAIT); end;

boolean							begin has_token('TBOOLEAN');return(tkTBOOLEAN); end;

break							begin has_token;return(tkBREAK); end;

call    						begin has_token;return(tkCALL); end;

case							begin has_token;return(tkCASE); end;

class							begin change_state(state_class);has_token('TCLASS');return(tkTCLASS);end;

constructor						begin change_state(state_constructor);has_token;return(tkCONSTRUCTOR); end;

continue						begin has_token;return(tkCONTINUE); end;

downto							begin has_token;return(tkDOWNTO); end;

else							begin change_state(state_else);has_token;return(tkELSE); end;

event							begin change_state(state_event);has_token;return(tkEVENT); end;

extends							begin has_token;return(tkEXTENDS); end;

false							begin has_token;return(tkFALSE); end;	

from							begin has_token;return(tkFROM); end;

free_object						begin has_token;return(tkFREEOBJECT); end;

for								begin change_state(state_for);has_token;return(tkFOR); end;

function						begin change_state(state_function);has_token;return(tkFUNCTION); end;

if								begin change_state(state_if);has_token;return(tkIF); end;

implements						begin has_token;return(tkIMPLEMENTS); end;

in								begin has_token;return(tkIN); end;

integer							begin has_token('TINTEGER');return(tkTINTEGER); end;

interface						begin change_state(state_interface);has_token('TINTERFACE');return(tkTINTERFACE); end;

real							begin has_token('TREAL');return(tkTREAL); end;

return							begin has_token;return(tkRETURN); end;

raise							begin has_token;return(tkRAISE); end;

module							begin has_token;return(tkMODULE); end;

new								begin has_token;return(tkNEW); end;

nil								begin has_token;return(tkNIL); end;

not								begin has_token;return(tkNOT); end;

of								begin has_token;return(tkOF); end;

or								begin has_token;return(tkOR); end;

overload						begin has_token;return(tkOVERLOAD); end;

override						begin has_token;return(tkOVERRIDE); end;

procedure						begin change_state(state_procedure);has_token;return(tkPROCEDURE); end;

program							begin change_state(state_program);has_token('TPROGRAM');return(tkTPROGRAM); end;

readln							begin has_token;return(tkREADLN); end;

read 							begin has_token;return(tkREAD); end;

run 							begin has_token;return(tkRUN); end;

set_state 						begin has_token;return(tkSETSTATE); end;

super 							begin has_token;return(tkSUPER); end;

sleep							begin has_token;return(tkSLEEP); end;

state							begin change_state(state_state);has_token('TSTATE');return(tkSTATE); end;

string							begin has_token('TSTRING');return(tkTSTRING); end;

then							begin has_token;return(tkTHEN); end;

to								begin has_token;return(tkTO); end;

true							begin has_token;return(tkTRUE); end;

uses							begin has_token;return(tkUSES); end;

when							begin has_token;return(tkWHEN); end;

while							begin change_state(state_while);has_token;return(tkWHILE); end;

writeln							begin has_token;return(tkWRITELN); end;

write							begin has_token;return(tkWRITE); end;

[a-zA-Z]([a-zA-Z0-9_])*			begin has_token('IDENTIFIER');return(tkIDENTIFIER); end;

"{"								begin
									repeat
										c := get_char;
										yytext := yytext + c;
										case c of
											'}' : begin 
													exit; 
												end;
											#13,#10 : begin
													line_ignore:=line_ignore+1;
												end;
											#0 : begin
													comment_eof;
													exit;
												end;
										end;
									until false
								end;

"//"							begin
									repeat
										c := get_char;
										case c of
											#13, #10 : begin
													unget_char(c);
													exit; 
												end;
											#0 : begin 
													exit; 
												end;
										else
											yytext := yytext + c;
										end;
									until false
								end;

":="							begin has_token('ASSIGNMENT');return(tkASSIGNMENT); end;
'([^'])*'					begin has_token('STRING');return(tkSTRING); end;
":"								begin has_token('COLON');return(tkCOLON); end;
","								begin has_token('COMMA');return(tkCOMMA); end;
[0-9]+"."[0-9]+					begin has_token('REAL');return(tkREAL); end;
[0-9]+							begin has_token('INTEGER');return(tkINTEGER); end;
"."								begin has_token('DOT');return(tkDOT); end;
"="								begin has_token('EQUAL');return(tkEQUAL); end;
"<>"							begin has_token('NOTEQUAL');return(tkNOTEQUAL); end;
">="							begin has_token('GE');return(tkGE); end;
">"								begin has_token('GT');return(tkGT); end;
"<="							begin has_token('LE');return(tkLE); end;
"<"								begin has_token('LT');return(tkLT); end;
"-"								begin has_token('MINUS');return(tkMINUS); end;
"+"								begin has_token('PLUS');return(tkPLUS); end;
"/"								begin has_token('SLASH');return(tkSLASH); end;
"*"								begin has_token('STAR');return(tkSTAR); end;
"%"								begin has_token('PERCENT');return(tkPERCENT); end;
"["								begin has_token('LBRAC');return(tkLBRAC); end;
"]"								begin has_token('RBRAC');return(tkRBRAC); end;
"("								begin has_token('LPAREN');return(tkLPAREN); end;
")"								begin has_token('RPAREN');return(tkRPAREN); end;
";"								begin has_token('SCOLON');return(tkSCOLON); end;

(\ {4}|\t)						;

[ ]								;

"~IN"\n							begin
									has_token_notext('INDENT');line_ignore:=line_ignore+1;return(tkINDENT);
								end;

"~DE"\n							begin
									has_token_notext('DEDENT');line_ignore:=line_ignore+1;return(tkDEDENT);
								end;

[\n]							begin
									if pre_token <> 'NEWLINE' then
									begin
										has_token_notext('NEWLINE');return(tkNEWLINE);
									end;
								end;

.								begin has_token('ILLEGAL');return(tkILLEGAL); end;

%%
