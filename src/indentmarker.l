%{

(* Copyright 2012-2014 Chong Cheung. All rights reserved.
 * Use of this source code is governed by a BSD-style license
 * that can be found in the LICENSE file.
 * Inject INDENT DEDENT token marker
 * Compile: plex indentmarker.l
 * 			fpc indentmarker.pas
 *)

%}

%{

uses LexLib, YaccLib;
{$I indent_stack.pas}


var filename : String;
	c:char;
	linestr : String;
	read_indent : boolean = true;
	current_indent_level : integer = 0;
	current_stack_item : Tstack_item;
	pre_stack_item: Tstack_item;
	i:integer;


procedure push_line_indent;
begin
	pre_stack_item := current_stack_item;
	with current_stack_item do
	begin
		lineno := yylineno;
		token := 0;
		indent_level := current_indent_level;
	end;
	stack_push(current_stack_item);
end;

procedure pop_line_indent;
var have_pre, have_prepre : boolean;
begin
	current_stack_item := stack_pop;
	have_pre := not is_stack_empty;
	current_stack_item := stack_pop; //pre
	have_prepre := not is_stack_empty;
	pre_stack_item := stack_pop; //prepre
	if have_prepre then
		stack_push(pre_stack_item);
	if have_pre then
		stack_push(current_stack_item);
end;

function yywrap : Boolean;
begin
	while not is_stack_empty do
	begin
		writeln(yyoutput,'~DE');
		pop_line_indent;
	end;
	close(yyinput);
	close(yyoutput);
	yywrap := true;
end;

%}

%%

"{"								begin
									repeat
										c := get_char;
										yytext := yytext + c;
										case c of
											'}' : begin 
													write(yyoutput,linestr + yytext);
													exit; 
												end;
											#13,#10 : begin
												end;
											#0 : begin
													write(yyoutput,linestr + yytext);
													exit;
												end;
										end;
									until false;
								end;

(\ {4}|\t)						begin
									linestr := linestr + yytext;
									if read_indent then
										current_indent_level := current_indent_level + 1;
								end;

[\n]							begin
									if current_indent_level = current_stack_item.indent_level + 1 then
									begin
										writeln(yyoutput,'~IN');push_line_indent;

									end
									else
									if current_indent_level < current_stack_item.indent_level then
									begin
										for i:=current_indent_level to current_stack_item.indent_level-1 do
										begin
										writeln(yyoutput,'~DE');
										pop_line_indent;
										end;
									end;
									

									read_indent:=true;
									current_indent_level:=0;
									writeln(yyoutput,linestr);
									linestr := '';
								end;

.								begin 
									linestr := linestr + yytext;
									read_indent := false; 
								 end;

%%

begin
	//init
	init_stack;
	current_stack_item := stack_pop;
	with current_stack_item do
	begin
		lineno := 0;
		token := 0;
		indent_level := 0;
	end;

	filename := paramStr(1);
	if filename='' then
	begin
		write('input file: ');
		readln(filename);
	end;
	assign(yyinput, filename);
	reset(yyinput);
	assign(yyoutput, filename + '.i');
	rewrite(yyoutput);
	while yylex>0 do
	begin
	end;
end.