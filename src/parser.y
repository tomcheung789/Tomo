
%{
(* Copyright 2012-2014 Chong Cheung. All rights reserved.
 * Use of this source code is governed by a BSD-style license
 * that can be found in the LICENSE file.
 * Compile: pyacc parser.y
 * 			fpc parser.pas
 *)
%}

%{

{$MODE OBJFPC} 

uses 
{$IFDEF UNIX}
cthreads,
{$ENDIF}
LexLib, YaccLib, Symtab, AST, CodeGenerator, Classes, 
SysUtils, fgl, strutils, Process, Crt;

type YYSType = String;

const
	state_none = 0;
	state_program = 1;
	state_interface = 2;
	state_class = 3;
	state_constructor = 4;
	state_function = 5;
	state_procedure = 6;
	state_event = 7;
	state_state = 8;

	state_if = 10;
	state_else = 11;
	state_for = 12;
	state_while = 13;

	str_tab = '---';

var 
	filename : String;
	showfilename : String; //remove .i
	pas_filename : String; // not auto append .pas
	c  : char;
	line_ignore : integer;
	pre_token : String;
	debuginfo : Boolean;

	//symbol table var
	object_symtab:TObjectSymList;
	state_list:TIntegerList;
	line_no_for_method_define:integer;

	//AST
	ast_state_list:TIntegerList;
	ast_lv:integer;

	temp_count:integer;
	temp_node:TNode;
	
	//icode
	icode_uses:TUsesList;
	icode:TNodeList;
	icode_tmpinfo:TNodeList;
	icode_tmplist:TNodeListList;
	icode_module:string = '';
	icode_program:string = '';
	//codegen
	code_gen : TCodeGen;


procedure yyerror(msg : string);
begin
	textcolor(lightRed);
	writeln(showfilename, '(', (yylineno-line_ignore), ',' ,(yycolno-yyleng),') ', msg, ' at or before `', yytext, '`.');
	halt;
end;

procedure program_init;
begin
	line_ignore:=0;
	pre_token:='';
	object_symtab := TObjectSymList.Create;
	icode_uses := TUsesList.Create;
	icode := TNodeList.Create;
	icode_tmpinfo := TNodeList.Create;
	icode_tmplist := TNodeListList.Create;
	state_list := TIntegerList.Create;
	ast_state_list := TIntegerList.Create;
	ast_lv:=0;
	code_gen := TCodeGen.Create;
	debuginfo := false;
end;

procedure compile_with_fpc;
var
	fpc: TProcess;
  	outputstr: TStringList;
  	i : integer;
begin
	outputstr := TStringList.Create;
	fpc:= TProcess.Create(nil);
	fpc.Executable := 'fpc';
   	fpc.Parameters.Add(pas_filename + '.pas'); 
   	if (icode_program <> '') then begin
   		{$IFDEF Windows}
   		fpc.Parameters.Add('-o' + pas_filename + '.exe'); 
   		{$ELSE}
   		fpc.Parameters.Add('-o' + pas_filename + '.tomo'); 
   		{$ENDIF}
   		
   	end;
   	fpc.Parameters.Add('-Fu' + ExtractFilePath(ParamStr(0)) + 'modules/'); 
    if	(debuginfo) then
    	fpc.Parameters.Add('-gl'); 
   	//fpc.Parameters.Add('-o' + copy(showfilename,0,Length(showfilename)-2)); 
   	//fpc.Parameters.Add('-dUseCThreads');
	fpc.Options := fpc.Options + [poWaitOnExit, poUsePipes];
 	fpc.Execute;
 	outputstr.LoadFromStream(fpc.Output);
 	for i := 2 to outputstr.Count -1  do 
		writeln('FPC: ' + outputstr[i]);
 	outputstr.Free;
 	fpc.Free;
end;

procedure Split(Delimiter: Char; Str: string; ListOfStrings: TStrings) ;
begin
   ListOfStrings.Clear;
   ListOfStrings.Delimiter := Delimiter;
   ListOfStrings.DelimitedText := Str;
end;

//start symtab function

procedure add_to_symbol_table(name,dtype:string);
var lineno:integer;
	OutPutList: TStringList;
	i:integer;
begin
	lineno := yylineno-line_ignore;
	OutPutList := TStringList.Create;
	Split(',', name, OutPutList);
	case state_list.last of
		state_program,state_interface,state_class:
			begin
				for i:=0 to OutPutList.Count-1 do
				begin
					if object_symtab.last.object_syms.look_up(OutPutList[i])
					then object_symtab.last.object_syms.append_lineno(OutPutList[i],lineno)
					else object_symtab.last.object_syms.add_item(OutPutList[i],dtype,lineno);
				end;
			end;
		state_constructor,state_function,state_procedure,state_event,state_state:
			begin
				for i:=0 to OutPutList.Count-1 do
				begin
					if object_symtab.last.methods.last.look_up(OutPutList[i])
					then object_symtab.last.methods.last.append_lineno(OutPutList[i],lineno)
					else object_symtab.last.methods.last.add_item(OutPutList[i],dtype,lineno);
				end;
			end;
	end;
	OutPutList.Free;
end;

procedure replace_name(name:string);
var lineno:integer;
	dtype:string;
	i:integer;
begin
	lineno := yylineno-line_ignore;
	case state_list.last of
		state_constructor: dtype:=t_constructor;
		state_function: dtype:=t_function;
		state_procedure: dtype:=t_procedure;
		state_event: dtype:=t_event;
		state_state: dtype:=t_state;
	end;
	case state_list.last of
		state_program,state_interface,state_class: 
			begin
				for i:=object_symtab.Count-1 downto 0 do
				begin
					if length(object_symtab[i].object_syms.name) = 0 then
					begin object_symtab[i].object_syms.name := name;
						break;
					end;
				end;
			end;
		state_constructor,state_function,state_procedure,state_event,state_state: 
			begin
				object_symtab.last.methods.last.name := name;
				//add to its parent
				if object_symtab.last.object_syms.look_up(name)
				then object_symtab.last.object_syms.append_lineno(name,lineno)
				else object_symtab.last.object_syms.add_item(name,dtype,line_no_for_method_define);
			end;
	end;
end;

procedure symbol_access(name:string);
var lineno:integer;
begin
	lineno := yylineno-line_ignore;
	case state_list.last of
		state_program,state_interface,state_class:
			begin
				if object_symtab.last.object_syms.look_up(name)
				then object_symtab.last.object_syms.append_lineno(name,lineno)
				else object_symtab.last.object_syms.add_item(name,t_none,lineno);
			end;
		state_constructor,state_function,state_procedure,state_event,state_state:
			begin
				if object_symtab.last.methods.last.look_up(name)
				then object_symtab.last.methods.last.append_lineno(name,lineno)
				else if object_symtab.last.object_syms.look_up(name)
					then object_symtab.last.object_syms.append_lineno(name,lineno)
					else object_symtab.last.methods.last.add_item(name,t_none,lineno);
			end;
	end;
end;

procedure remove_last_state;
begin
	if state_list.Count > 0 then state_list.Delete(state_list.Count -1);
end;

//AST

procedure icode_add(node:TNode);
begin
	icode_tmplist.last.add(node);
end;

procedure icode_addtohead(node:TNode);
begin
	icode_tmplist.last.insert(0,node);
end;

procedure icode_finish();
begin
	if icode_tmplist.Count >= 2 then
	begin
		while(icode_tmplist.last.Count <> 0) do
			icode_tmplist[icode_tmplist.Count-2].add(icode_tmplist.last.Extract(icode_tmplist.last.First));
		icode_tmplist.delete(icode_tmplist.Count-1);
	end
	else
	begin
		while(icode_tmplist.last.Count <> 0) do
			icode.add(icode_tmplist.last.Extract(icode_tmplist.last.First));
		icode_tmplist.delete(icode_tmplist.Count-1);
	end;
	if ast_state_list.Count > 0 then ast_state_list.Delete(ast_state_list.Count -1);
end;

procedure icode_program_setinfo(n:String);
begin
	icode_tmpinfo.add(TProgram.Create(n));
	icode_program := n;
end;

procedure icode_class_setinfo(n,e,i:String);
begin
	icode_tmpinfo.add(TClass.Create(n,e,i));
end;

procedure icode_interface_setinfo(n:String);
begin
	icode_tmpinfo.add(TInterface.Create(n));
end;

procedure icode_use_module(n:string);
var
	OutPutList: TStringList;
	i:integer;
begin
	OutPutList := TStringList.Create;
	Split(',', n, OutPutList);
	for i := 0 to OutPutList.Count-1 do begin
		if (icode_uses.IndexOf(OutPutList[i]) = -1) then begin
			icode_uses.add(OutPutList[i]);
		end;
	end;
end;

%}

%start nonindent_define_statement

%token tkMODULE tkUSES
%token tkTBOOLEAN tkTREAL tkTINTEGER tkTSTRING tkTCLASS tkTINTERFACE tkTPROGRAM
%token tkAND tkARRAY tkCASE tkCONSTRUCTOR tkELSE tkEVENT tkEXTENDS tkFROM tkFOR tkFUNCTION
%token tkIF tkIMPLEMENTS tkIN tkRETURN tkNIL tkNOT tkOF tkOR tkOVERLOAD tkOVERRIDE tkPROCEDURE tkSTATE tkTHEN tkTO tkDOWNTO tkWHILE tkWHEN tkCALL
%token tkBREAK tkCONTINUE tkRAISE tkAWAIT
%token tkWRITELN tkWRITE tkNEW tkREADLN tkREAD tkSLEEP tkRUN tkSUPER tkFREEOBJECT tkSETSTATE
%token tkASSIGNMENT tkSTRING
%token tkIDENTIFIER 
%token tkCOLON tkSCOLON tkCOMMA tkDOT tkREAL tkINTEGER 
%token tkEQUAL tkNOTEQUAL tkGE tkGT tkLE tkLT
%token tkMINUS tkPLUS tkSLASH tkSTAR tkPERCENT
%token tkLBRAC tkRBRAC tkLPAREN tkRPAREN
%token tkTRUE tkFALSE
%token tkINDENT tkDEDENT
%token tkNEWLINE
%token tkILLEGAL

%nonassoc tkEQUAL tkNOTEQUAL tkGE tkGT tkLE tkLT tkIN
%left tkOR tkAND
%left tkPLUS tkMINUS
%left tkSTAR tkSLASH tkPERCENT

%%

module_define : tkMODULE identifier tkNEWLINE nonindent_define_statement  {icode_module:=$2;}
	| tkMODULE identifier tkNEWLINE		{icode_module:=$2;}
	;
	
uses_statement : tkUSES identifier_list tkNEWLINE nonindent_define_statement  {icode_use_module($2);}
	| tkUSES identifier_list tkNEWLINE   {icode_use_module($2);}
	;

program_define : tkTPROGRAM identifier program_suite_not_end 									
		{ replace_name($2);icode_program_setinfo($2);remove_last_state;}
	| tkTPROGRAM identifier program_suite
		{ replace_name($2);icode_program_setinfo($2);remove_last_state;}
	;

class_define : tkTCLASS identifier class_suite 											
		{ replace_name($2);icode_class_setinfo($2,'','');remove_last_state; }
	| tkTCLASS identifier tkEXTENDS identifier class_suite 								
		{ replace_name($2);icode_class_setinfo($2,$4,'');remove_last_state; }
	| tkTCLASS identifier tkEXTENDS identifier tkIMPLEMENTS implement_list class_suite 	
		{ replace_name($2);icode_class_setinfo($2,$4,$6);remove_last_state; }
	| tkTCLASS identifier tkIMPLEMENTS implement_list class_suite 						
		{ replace_name($2);icode_class_setinfo($2,'',$4);remove_last_state; }
	;

implement_list : implement_list comma identifier 		{$$ := $1 + $2 + $3}
    | identifier
    ;

interface_define : tkTINTERFACE identifier interface_suite 									
		{ replace_name($2); icode_interface_setinfo($2);remove_last_state; }
	;

constructor_define : tkCONSTRUCTOR parameter suite 			
		{ icode_addtohead(TBegin.Create);
		icode_addtohead(TParameter.Create($2));
		icode_addtohead(TConstructor.Create(''));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state; }
	| tkCONSTRUCTOR polymorphism__operator parameter suite 	
		{ icode_addtohead(TBegin.Create);
		icode_addtohead(TParameter.Create($3));
		icode_addtohead(TConstructor.Create($2));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state; }
	;

no_body_constructor_define : tkCONSTRUCTOR parameter tkSCOLON tkNEWLINE 			
		{ icode_addtohead(TBegin.Create);
		icode_addtohead(TParameter.Create($2));
		icode_addtohead(TConstructor.Create(''));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state; }
	| tkCONSTRUCTOR polymorphism__operator parameter tkSCOLON tkNEWLINE 	
		{ icode_addtohead(TBegin.Create);
		icode_addtohead(TParameter.Create($3));
		icode_addtohead(TConstructor.Create($2));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state; }
	;

parameter : tkLPAREN parameter_list tkRPAREN			{$$:=$2}
	| tkLPAREN tkRPAREN 								{$$:=''}
	;

parameter_list : parameter_list comma variable_define	{$$ := $1 + ';' + $3}
	| variable_define
    ;

function_define : tkFUNCTION identifier parameter type_specifier suite 				
		{ replace_name($2);
		icode_addtohead(TBegin.Create);
		icode_addtohead(TParameter.Create($3));
		icode_addtohead(TFunction.Create($2,'',$4));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state; }
	| tkFUNCTION polymorphism__operator identifier parameter type_specifier suite 	
		{ replace_name($3);
		icode_addtohead(TBegin.Create);
		icode_addtohead(TParameter.Create($4));
		icode_addtohead(TFunction.Create($3,$2,$5));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state; }
	| tkFUNCTION identifier parameter type_specifier tkSCOLON tkNEWLINE				
		{ replace_name($2);
		icode_addtohead(TBegin.Create);
		icode_addtohead(TParameter.Create($3));
		icode_addtohead(TFunction.Create($2,'',$4));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state; }
	| tkFUNCTION polymorphism__operator identifier parameter type_specifier tkSCOLON tkNEWLINE	
		{ replace_name($3);
		icode_addtohead(TBegin.Create);
		icode_addtohead(TParameter.Create($4));
		icode_addtohead(TFunction.Create($3,$2,$5));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state; }
	;

interface_function_define : tkFUNCTION identifier parameter type_specifier tkSCOLON tkNEWLINE				
		{ replace_name($2);
		icode_addtohead(TBegin.Create);
		icode_addtohead(TParameter.Create($3));
		icode_addtohead(TFunction.Create($2,'',$4));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state; }
	| tkFUNCTION tkOVERLOAD identifier parameter type_specifier tkSCOLON tkNEWLINE	
		{ replace_name($3);
		icode_addtohead(TBegin.Create);
		icode_addtohead(TParameter.Create($4));
		icode_addtohead(TFunction.Create($3,$2,$5));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state; }
	;

procedure_define : tkPROCEDURE identifier parameter suite 			
		{ replace_name($2);
		icode_addtohead(TBegin.Create);
		icode_addtohead(TParameter.Create($3));
		icode_addtohead(TProc.Create($2,''));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state; }
	| tkPROCEDURE polymorphism__operator identifier parameter suite 
		{ replace_name($3);
		icode_addtohead(TBegin.Create);
		icode_addtohead(TParameter.Create($4));
		icode_addtohead(TProc.Create($3,$2));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state;}
	| tkPROCEDURE identifier parameter tkSCOLON tkNEWLINE 			
		{ replace_name($2);
		icode_addtohead(TBegin.Create);
		icode_addtohead(TParameter.Create($3));
		icode_addtohead(TProc.Create($2,''));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state; }
	| tkPROCEDURE polymorphism__operator identifier parameter tkSCOLON tkNEWLINE 
		{ replace_name($3);
		icode_addtohead(TBegin.Create);
		icode_addtohead(TParameter.Create($4));
		icode_addtohead(TProc.Create($3,$2));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state;}
	;

interface_procedure_define : tkPROCEDURE identifier parameter tkSCOLON tkNEWLINE 			
		{ replace_name($2);
		icode_addtohead(TBegin.Create);
		icode_addtohead(TParameter.Create($3));
		icode_addtohead(TProc.Create($2,''));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state; }
	| tkPROCEDURE tkOVERLOAD identifier parameter tkSCOLON tkNEWLINE 
		{ replace_name($3);
		icode_addtohead(TBegin.Create);
		icode_addtohead(TParameter.Create($4));
		icode_addtohead(TProc.Create($3,$2));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state;}
	;

event_define : tkEVENT identifier parameter event_suite 
				{ replace_name($2);
				icode_addtohead(TBegin.Create);
				icode_addtohead(TParameter.Create($3));
				icode_addtohead(TEvent.Create($2));
				icode_add(TEnd.Create);icode_finish();
				remove_last_state; }
	;

state_define : tkSTATE identifier suite 			
		{ replace_name($2);
		icode_addtohead(TBegin.Create);
		icode_addtohead(TState.Create($2));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state; }
	| tkSTATE identifier tkSCOLON tkNEWLINE 
		{ replace_name($2);
		icode_addtohead(TBegin.Create);
		icode_addtohead(TState.Create($2));
		icode_add(TEnd.Create);icode_finish();
		remove_last_state; }
	;

statement_list : statement_list statement
	| statement
	;

statement: simple_statement
	| define_statement
	| compound_statement
	;

statement_without_define_list : statement_without_define_list statement_without_define
	| statement_without_define
	;

statement_without_define : simple_statement
	| compound_statement
	;

interface_statement_list : interface_statement_list interface_statement
	| interface_statement
	;

interface_statement : interface_function_define
	| interface_procedure_define
	;

event_statement_list : event_statement_list event_statement 
	| event_statement
	;

event_statement : trans_statement tkNEWLINE {icode_add(TLineEnd.Create);}
	;
simple_statement : small_statement tkNEWLINE {icode_add(TLineEnd.Create);}
	;

small_statement: variable_define_assign
	| variable_define 				{icode_add(TVariable.Create($1));}
	| write_statement
	| read_statement
	| sleep_statement
	| free_object_statement
	| set_state_statement
	| flow_statement
	| assignment_statement
	| super_statement
	| function_call 							{icode_add(TMethod.Create($1));}
	;

program_suite_not_end : program_suite nonindent_define_statement
	;

program_suite : tkNEWLINE tkINDENT statement_without_define_list tkDEDENT 							
	;

class_suite :
	tkNEWLINE tkINDENT statement_list tkDEDENT nonindent_define_statement 					
	| suite 	
	;

suite: tkNEWLINE tkINDENT statement_list tkDEDENT 	
	;

interface_suite :
	tkNEWLINE tkINDENT interface_statement_list tkDEDENT nonindent_define_statement  	
	| tkNEWLINE tkINDENT interface_statement_list tkDEDENT 							
	;

event_suite : tkNEWLINE tkINDENT event_statement_list tkDEDENT
	;
	
expression_statement_list : expression_statement_list comma expression_statement {$$ := $1 + $2 + $3}
	| expression_statement  
	;

expression_statement : expression 
	| expression relational_operator expression 	{$$ := $1 +' '+ $2 +' '+ $3}
	;

expression : term
	| expression tkPLUS term 						{$$ := $1 + $2 + $3}
	| expression tkMINUS term 						{$$ := $1 + $2 + $3}
	| expression tkOR term 							{$$ := $1 +' '+ $2 +' '+ $3}
	;

term : factor
	| term tkSTAR factor 							{$$ := $1 + $2 + $3}
	| term tkSLASH factor							{$$ := $1 + $2 + $3}
	| term tkPERCENT factor							{$$ := $1 + ' mod ' + $3}
	| term tkAND factor								{$$ := $1 +' '+ $2 +' '+ $3}
	;

factor : tkPLUS factor 								 {$$ := $1 + $2}
	| tkMINUS factor								{$$ := $1 + $2}
	| primary
	;

primary : variable_access
	| tkNIL
	| tkINTEGER
	| tkREAL
	| tkSTRING
	| tkTRUE
	| tkFALSE
    | function_call
    | tkNEW identifier method_parameter {$$ := $2 + '.Create' + $3}
    | tkLPAREN expression_statement tkRPAREN  {$$ := $1 + $2 + $3}
    | tkNOT primary {$$ := $1 + $2}
    ;

super_statement : tkSUPER method_parameter 										{icode_add(TMethod.Create('Inherited Create' + $2));}	
	| tkSUPER tkDOT function_call 												{icode_add(TMethod.Create('Inherited ' + $3));}
	;

write_statement : tkWRITELN tkLPAREN expression_statement_list tkRPAREN 				
	{icode_add(TDEFMethod.Create($1));icode_add(TExpression.Create('stdout,' + $3));icode_add(TLineEnd.Create);icode_add(TMethod.Create('flush(stdout)'));}
	| tkWRITE tkLPAREN expression_statement_list tkRPAREN							
	{icode_add(TDEFMethod.Create($1));icode_add(TExpression.Create('stdout,' + $3));icode_add(TLineEnd.Create);icode_add(TMethod.Create('flush(stdout)'));}
	;

read_statement : tkREADLN tkLPAREN variable_access tkRPAREN						{icode_add(TDEFMethod.Create($1));icode_add(TExpression.Create($3));}
	| tkREAD tkLPAREN variable_access tkRPAREN									{icode_add(TDEFMethod.Create($1));icode_add(TExpression.Create($3));}
	;

sleep_statement : tkSLEEP tkLPAREN variable_access tkRPAREN						{icode_add(TDEFMethod.Create($1));icode_add(TExpression.Create($3));}
	| tkSLEEP tkLPAREN tkINTEGER tkRPAREN										{icode_add(TDEFMethod.Create($1));icode_add(TExpression.Create($3));}
	;
	
free_object_statement : tkFREEOBJECT tkLPAREN variable_access tkRPAREN  		{icode_add(TDEFMethod.Create('FreeAndNil'));icode_add(TExpression.Create($3));}
	;

set_state_statement : tkSETSTATE tkLPAREN identifier tkRPAREN					{icode_add(TCState.Create($3));}
	;

function_call : field_designator method_parameter 								{$$:= $1+$2; }
	| identifier method_parameter 												{$$:= $1+$2; symbol_access($1);}
	;

method_parameter : tkLPAREN actual_parameter_list tkRPAREN						{$$ := $1 + $2 + $3}
	| tkLPAREN tkRPAREN															{$$ := $1 + $2}
	;

actual_parameter_list : actual_parameter_list comma actual_parameter 			{$$ := $1 + $2 + $3}
	| actual_parameter
    ;

actual_parameter : expression_statement
	;

flow_statement : break_statement
	| continue_statement
	| run_statement
	| raise_statement
	| return_statement
	;

break_statement : tkBREAK								{icode_add(TFlow.Create($1));}
	;

continue_statement : tkCONTINUE							{icode_add(TFlow.Create($1));}
	;

run_statement : tkAWAIT tkRUN function_call						{icode_add(TRun.Create(true));icode_add(TExpression.Create($3));}
	| tkRUN function_call						{icode_add(TRun.Create(false));icode_add(TExpression.Create($2));}
	;

raise_call_list : raise_call_list comma function_call		{$$ := $1 + '|' + $3}
    | function_call											
    ;

raise_statement : tkAWAIT tkRAISE raise_call_list 				{ icode_add(TRaise.Create($3,true));}
	| tkRAISE raise_call_list 				{ icode_add(TRaise.Create($2,false));}
	;

return_statement : tkRETURN expression_statement		{icode_add(TReturn.Create);icode_add(TExpression.Create($2));}
	;

trans_statement : tkFROM identifier tkTO identifier tkCALL function_call tkCOMMA tkWHEN expression_statement
		{symbol_access($2);symbol_access($4);icode_add(TFromto.Create($2,$4));icode_add(TExpression.Create($9));icode_add(TMethod.Create($6));}
	| tkFROM identifier tkTO identifier tkCOMMA tkWHEN expression_statement 
		{symbol_access($2);symbol_access($4);icode_add(TFromto.Create($2,$4));icode_add(TExpression.Create($7));}
	| tkFROM identifier tkTO identifier tkCALL function_call
		{symbol_access($2);symbol_access($4);icode_add(TFromto.Create($2,$4));icode_add(TMethod.Create($6));}
	| tkFROM identifier tkTO identifier 									  {symbol_access($2);symbol_access($4);icode_add(TFromto.Create($2,$4));}
	;

assignment_statement : variable_access tkASSIGNMENT expression_statement 	{icode_add(TAssign.Create($1));icode_add(TExpression.Create($3));}
    ;

nonindent_define_statement : module_define
	| uses_statement
	| class_define
	| interface_define
	| program_define
	;

define_statement :constructor_define
	| function_define
	| procedure_define
	| state_define
	| event_define
	| no_body_constructor_define
	;

compound_statement : if_else_statement
	| if_statement
	| while_statement
	| forto_statement
	| fordownto_statement
	| forin_statement
	;

if_else_statement : if_statement tkELSE suite 
		{icode_addtohead(TBegin.Create);
		icode_addtohead(TElse.Create);
		icode_add(tEnd.Create);icode_finish();remove_last_state;}
	;

if_statement : tkIF expression_statement suite 							
		{icode_addtohead(TBegin.Create);
		icode_addtohead(TExpression.Create($2));
		icode_addtohead(TIf.Create);
		icode_add(tEnd.Create);icode_finish();remove_last_state;}
	;

while_statement : tkWHILE expression_statement suite 			
		{icode_addtohead(TBegin.Create);
		icode_addtohead(TExpression.Create($2));
		icode_addtohead(TWhile.Create);
		icode_add(tEnd.Create);
		icode_finish();remove_last_state;}
	| tkWHILE expression_statement tkSCOLON tkNEWLINE 
		{icode_addtohead(TBegin.Create);
		icode_addtohead(TExpression.Create($2));
		icode_addtohead(TWhile.Create);
		icode_add(tEnd.Create);
		icode_finish();remove_last_state;}
	;

forto_statement : tkFOR variable_access tkASSIGNMENT expression_statement tkTO expression_statement suite         
		{icode_addtohead(TBegin.Create);
		icode_addtohead(TExpression.Create($6));
		icode_addtohead(TExpression.Create($2 + $3 + $4)); //do not use TAssign
		icode_addtohead(TForto.Create);
		icode_add(tEnd.Create);
		icode_finish();remove_last_state;}
	| tkFOR variable_access tkASSIGNMENT expression_statement tkTO expression_statement tkSCOLON tkNEWLINE
		{icode_addtohead(TBegin.Create);
		icode_addtohead(TExpression.Create($6));
		icode_addtohead(TExpression.Create($2 + $3 + $4)); //do not use TAssign
		icode_addtohead(TForto.Create);
		icode_add(tEnd.Create);
		icode_finish();remove_last_state;}
	;

fordownto_statement : tkFOR variable_access tkASSIGNMENT expression_statement tkDOWNTO expression_statement suite 
		{icode_addtohead(TBegin.Create);
		icode_addtohead(TExpression.Create($6));
		icode_addtohead(TExpression.Create($2 + $3 + $4)); //do not use TAssign
		icode_addtohead(TFordownto.Create);
		icode_add(tEnd.Create);
		icode_finish();remove_last_state;}
	| tkFOR variable_access tkASSIGNMENT expression_statement tkDOWNTO expression_statement tkSCOLON tkNEWLINE 
		{icode_addtohead(TBegin.Create);
		icode_addtohead(TExpression.Create($6));
		icode_addtohead(TExpression.Create($2 + $3 + $4)); //do not use TAssign
		icode_addtohead(TFordownto.Create);
		icode_add(tEnd.Create);
		icode_finish();remove_last_state;}
	;

forin_statement : tkFOR variable_access tkIN expression_statement suite 
		{icode_addtohead(TBegin.Create);
		icode_addtohead(TExpression.Create($4));
		icode_addtohead(TForin.Create($2));
		icode_add(tEnd.Create);
		icode_finish();remove_last_state;}
	| tkFOR variable_access tkIN expression_statement tkSCOLON tkNEWLINE 
		{icode_addtohead(TBegin.Create);
		icode_addtohead(TExpression.Create($4));
		icode_addtohead(TForin.Create($2));
		icode_add(tEnd.Create);
		icode_finish();remove_last_state;}
	;

variable_access : identifier { symbol_access($1); }
    | indexed_variable 
    | field_designator
    ;

indexed_variable : variable_access tkLBRAC index_expression_list tkRBRAC	{$$ := $1 + $2 + $3 + $4}
    ;

index_expression_list : index_expression_list comma index_expression 		{$$ := $1 + $2 + $3}
    | index_expression
    ;

index_expression : expression_statement 
	;

field_designator : variable_access tkDOT identifier 						{$$ := $1 + $2 + $3}
    ;

relational_operator : tkEQUAL
	| tkNOTEQUAL
	| tkGE
	| tkGT
	| tkLE
	| tkLT
	| tkIN
	;

polymorphism__operator : tkOVERLOAD
	| tkOVERRIDE
	;

type_specifier : tkTBOOLEAN
	| tkTREAL
	| tkTINTEGER
	| tkTSTRING
	| array_type
	| identifier
	;

index_type : tkINTEGER
	| identifier
	;

index_list : index_list comma index_type					{$$ := $1 + $2 + '1..' + $3}
    | index_type											{$$ := '0..' + IntToStr(StrToInt($1) -1)}
    ;

array_type : tkARRAY tkLBRAC index_list tkRBRAC tkOF type_specifier {$$ := $1 + $2 + $3 + $4 +' '+ $5 +' '+ $6}
	| tkARRAY tkOF type_specifier 							{$$ := $1 +' '+ $2 +' '+ $3}
    ;

variable_define : identifier_list colon type_specifier 		{ $$:=$1 + $2 + $3; add_to_symbol_table($1,$3); }
    ;
variable_define_assign : identifier_list colon type_specifier tkEQUAL expression_statement 
	{add_to_symbol_table($1,$3);
    icode_add(TVariable.Create($1 + $2 + $3)); icode_add(TLineEnd.Create);
    icode_add(TAssign.Create($1));icode_add(TExpression.Create($5));}
	;

identifier_list : identifier_list comma identifier 			{$$ := $1 + $2 + $3}
    | identifier
    ;

identifier : tkIDENTIFIER
	;

colon : tkCOLON
	;

comma : tkCOMMA
	;
%%

{$I scanner.pas}

begin
	program_init;
	//param
	for temp_count := 1 to paramcount do begin
		if (paramStr(temp_count) = '-debuginfo') then begin
			debuginfo:= true;
		end;
	end;
	filename := paramStr(1);
	if filename='' then
	begin
		exit;
	end;
	if (ExtractFileExt(filename) <> '.t') then begin
		writeln('Source file name must end with .t');
		exit;
	end;
	textbackground(DarkGray);
	textcolor(lightgray);
	writeln('Tomo Compiler version 0.9 by Chong Cheung');
	writeln('Indentation processing ... ', filename);
	//call indentmarker to add token
	try
		SysUtils.ExecuteProcess(ExtractFilePath(ParamStr(0)) + 'indentmarker', filename, []);
	except 
		On E:EOSError  do begin
			textcolor(lightRed);
			writeln('Indentmarker not found.');
		end;
	end;

	filename:= filename+'.i';
	assign(yyinput, filename);
	reset(yyinput);

	//remove ".i"
	showfilename:= copy(filename,0,Length(filename)-2);

	writeln('Parsing ... ', showfilename);
	if yyparse=0 then writeln('');
	//do a close job
	
	change_state_for_ast(state_none);
	
	//merge info quick fix class / program name error on symtab
	while(icode_tmpinfo.Count <> 0) do
	begin
		temp_node := icode_tmpinfo.Extract(icode_tmpinfo.First);
		for temp_count := icode.Count -1 downto 0  do 
		begin
			if (icode[temp_count].node_type=temp_node.node_type) and
				(icode[temp_count].name = '') then
			begin
				icode[temp_count] := temp_node;
				break;
			end;
		end;
	end;
	
	if (debuginfo) then begin
		writeln();
		writeln('======== Symbol Table ========');
		writeln();
		for temp_count := 0 to object_symtab.Count -1  do 
			object_symtab[temp_count].print;
		writeln();
		writeln('======== Intermediate Code ========');
		writeln();
		
		//output
		for temp_count := 0 to icode.Count -1  do 
		begin
			case icode[temp_count].node_type of
				n_begin: begin
					write(DupeString(str_tab,ast_lv));
					writeln(icode[temp_count].to_string);
					ast_lv:= ast_lv+1;
				end;
				n_end: begin
					ast_lv :=ast_lv -1;
					write(DupeString(str_tab,ast_lv));
					writeln(icode[temp_count].to_string);
				end;
				else begin
					write(DupeString(str_tab,ast_lv));
					writeln(icode[temp_count].to_string);
				end;
			end;
		end;
		writeln();
	end;
	
	writeln('Compling ... ', showfilename);
	code_gen.gen_code(object_symtab, icode, icode_uses, icode_module);
	pas_filename := ExtractFileName(showfilename);
	if (pos('.', pas_filename) <> 0) then begin
		pas_filename := copy(pas_filename, 1 , pos('.', pas_filename) - 1);
	end;
	//
	//full path no .t and name no .t
	code_gen.write_to_file(ExtractFilePath(showfilename) + pas_filename, pas_filename);
	writeln();
	
	//fpc
	pas_filename := ExtractFilePath(showfilename) + pas_filename;
	compile_with_fpc();
	
	code_gen.Free;
	object_symtab.Free;
	icode_uses.Free;
	icode_tmplist.Free;
	icode_tmpinfo.Free;
	icode.Free;
	state_list.Free;
	ast_state_list.Free;
end.
