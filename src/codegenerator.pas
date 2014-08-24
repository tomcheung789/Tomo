{ Copyright 2012-2014 Chong Cheung. All rights reserved.
Use of this source code is governed by a BSD-style license
that can be found in the LICENSE file. }
unit CodeGenerator;

{$MODE OBJFPC} 

interface

uses
{$IFDEF UNIX}{$IFDEF UseCThreads}
cthreads,
{$ENDIF}{$ENDIF}
Classes, sysutils, fgl, Symtab, AST , strutils, Crt
{ you can add units after this };

const {kw = keyword in pascal, }
	kw_program = 'program';
	kw_unit = 'unit';
	kw_interface = 'interface';
	kw_class = 'class';
	kw_uses = 'uses';
	kw_const = 'const';
	kw_type = 'type';
	kw_var = 'var';
	kw_impl = 'implementation';
	kw_func = 'function';
	kw_proc = 'procedure';
	kw_constructor = 'constructor';

	kw_public = 'public';
	kw_begin = 'begin';
	kw_end = 'end';
	kw_assign = ':=';
	kw_if = 'if';
	kw_else = 'else';
	kw_then = 'then';
	kw_while = 'while';
	kw_for = 'for';
	kw_to = 'to';
	kw_downto = 'downto';
	kw_do = 'do';
	kw_in = 'in';
	kw_exit = 'exit';
	kw_try ='try';
	kw_finally = 'finally';


	str_tab = '    ';

	str_use_default = '{$IFDEF UNIX}' + Char(#10) +
		'cthreads,cmem' + Char(#10) +'{$ENDIF}';
	
	str_objfpc = '{$MODE OBJFPC}';
	//str_def_cs_name = 'tomo_sys_lock';
	str_sm_lock = 'tomo_machine_lock';
	str_sm_trans_lock = 'tomo_machine_trans_action_lock';
	str_def_sm_lock = ':Lock;';
	str_def_sm_lock_create = ':=Lock.Create();';
	{str_criticalsection = ':TCriticalSection;';
	str_criticalsection_create = ':=TCriticalSection.Create();';
	str_lock = '.Enter()';
	str_unlock = '.Leave()';}
	str_lock = '.lock()';
	str_unlock = '.unlock()';
	str_thread_type = 'tomo_sys_thread_define';
	str_thread_var = 'tomo_sys_thread_var';
	str_machine = 'tomo_machine';
	str_state = 'tomo_machine_state';
	str_event = 'tomo_machine_event';
type 
	TIntegerList = specialize TFPGList<integer>;
	
	TCodeGen = class(TObject)
		public
			ast_lv:integer;
			program_name : String;
			unit_name : String;
			const_area : TStringList;
			forward_type_area : TStringList;
			type_area : TStringList;
			thd_type_area : TStringList;
			var_area : TStringList;
			impl_area : TStringList;
			thd_impl_area : TStringList;
			main_area : TStringList;
			run_thd_id_num : integer;
			obj_tab_index : integer;
			uses_area:TUsesList;
			constructor Create();
			destructor Destroy; override;
			procedure perror(n:string);
			procedure add_uses(n:string);
			procedure gen_code(symtab:TObjectSymList; icode:TNodeList; icode_uses:TUsesList; icode_module:string);
			function gen_program(symtab:TObjectSymList; icode:TNodeList; idx:integer):integer;
			function gen_default_method_call(symtab:TObjectSymList; icode:TNodeList; idx:integer;var line_code:String):integer;
			function gen_assign(symtab:TObjectSymList; icode:TNodeList; idx:integer;var line_code:String):integer;
			function gen_interface(symtab:TObjectSymList; icode:TNodeList; idx:integer):integer;
			function gen_class(symtab:TObjectSymList; icode:TNodeList; idx:integer):integer;
			procedure gen_statemachine_lib(class_name:string;publicindex:integer;state_list:TStringList);
			procedure Split(Delimiter: Char; Str: string; ListOfStrings: TStrings) ;
			function gen_run(symtab:TObjectSymList; inode:TNode; area:string; lv:integer; await:boolean):string;
			function fix_event_raise_name(input:string):string;
			procedure write_to_file(file_name,name_only:String);
	end;

implementation

constructor TCodeGen.Create();
begin
  inherited Create;
	const_area := TStringList.Create;
	forward_type_area := TStringList.Create;
	type_area := TStringList.Create;
	thd_type_area := TStringList.Create;
	var_area := TStringList.Create;
	impl_area := TStringList.Create;
	thd_impl_area := TStringList.Create;
	main_area := TStringList.Create;
	uses_area:= TUsesList.Create;
	uses_area.add('Classes');
	uses_area.add('SysUtils');
	uses_area.add('SyncObjs');
	uses_area.add('fgl');
	uses_area.add('Variants');
	run_thd_id_num := 0;
	program_name := '';
	unit_name := '';
end;

destructor TCodeGen.Destroy;
begin
  inherited Destroy;
	const_area.Free;
	forward_type_area.Free;
	type_area.Free;
	thd_type_area.Free;
	var_area.Free;
	impl_area.Free;
	thd_impl_area.Free;
	main_area.Free;
	uses_area.Free;
end;

procedure TCodeGen.perror(n:string);
begin
	textcolor(lightRed);
	writeln(n);
	halt;
end;

procedure TCodeGen.add_uses(n:string);
begin
	if (uses_area.IndexOf(n) = -1) then begin
		uses_area.add(n);
	end;
end;

procedure TCodeGen.gen_code(symtab:TObjectSymList; icode:TNodeList; icode_uses:TUsesList; icode_module:string);
var
	i:integer;
begin
	unit_name := icode_module;
	//append uses area
	for i := 0 to icode_uses.Count-1 do begin
		add_uses(icode_uses[i]);
	end;
	i:=0;
	obj_tab_index := 0;
	repeat
		case icode[i].node_type of
			n_program: begin
				i := gen_program(symtab,icode,i);
				inc(obj_tab_index);
			end;
			n_interface: begin
				i := gen_interface(symtab,icode,i);
				inc(obj_tab_index);
			end;
			n_class: begin
				i := gen_class(symtab,icode,i);
				inc(obj_tab_index);
			end;
			n_begin: begin
			end;
			n_end: begin
			end;
			n_line_end: begin
			end;
			else begin
				perror('CodeGen Error:' + icode[i].to_string());
			end;
		end;
		inc(i);
	until (i > icode.Count -1);
end;

function TCodeGen.gen_program(symtab:TObjectSymList; icode:TNodeList; idx:integer):integer;
var
	i:integer;
	line_code:string;
	pre_node_type:string = '';
	tmp_stringlist:TStringList;
	temp_count:integer;
	label do_write, do_write_no_semicolon;
begin
	i := idx;
	repeat
		case icode[i].node_type of
			n_program: begin
				program_name := icode[i].name;
				//var_area.add(DupeString(str_tab,1) + str_def_cs_name + str_criticalsection); //default var
			end;
			n_begin: begin
				line_code := DupeString(str_tab,ast_lv) + kw_begin;
				main_area.add(line_code);
				// adding default cs create on start
				{if (ast_lv = 0) then begin
					main_area.add(DupeString(str_tab,1) + str_def_cs_name + str_criticalsection_create);
				end;}
				ast_lv:= ast_lv+1;
				line_code := '';
			end;
			n_end: begin
				ast_lv :=ast_lv -1;
				if (ast_lv=0) then  begin exit(i); end;
				// if next node is else then do not add semicolon
				line_code := DupeString(str_tab,ast_lv) + kw_end;
				if not (icode[i+1].node_type = n_else) then begin
					line_code := line_code + ';';
				end;
				main_area.add(line_code);
				line_code := '';
			end;
			n_variable: begin
				line_code := icode[i].name;
			end;
			n_assign: begin
				i := gen_assign(symtab,icode,i,line_code);
			end;
			n_method: begin
				line_code := icode[i].name;
			end;
			n_defmethod: begin
				i := gen_default_method_call(symtab,icode,i,line_code);
			end;
			n_if: begin //read one more node EXPRESSION
				line_code := kw_if;
				line_code := line_code + ' ' +icode[i+1].name + ' ' + kw_then;
				inc(i); //curr = EXPRESSION node
				goto do_write_no_semicolon;
			end;
			n_else: begin
				line_code := kw_else;
				goto do_write_no_semicolon;
			end;
			n_while: begin //read one more node EXPRESSION
				line_code := kw_while;
				line_code := line_code + ' ' +icode[i+1].name + ' ' + kw_do;
				inc(i); //curr = EXPRESSION node
				goto do_write_no_semicolon;
			end;
			n_forto: begin //read one more node assign one more node EXPRESSION 
				line_code := kw_for;
				line_code := line_code + ' ' +icode[i+1].name + ' ' + kw_to + ' ' + icode[i+2].name + ' ' + kw_do;
				inc(i,2); //curr = EXPRESSION node
				goto do_write_no_semicolon;
			end;
			n_fordownto: begin //read one more node assign one more node EXPRESSION 
				line_code := kw_for;
				line_code := line_code + ' ' +icode[i+1].name + ' ' + kw_downto + ' ' + icode[i+2].name + ' ' + kw_do;
				inc(i,2); //curr = EXPRESSION node
				goto do_write_no_semicolon;
			end;
			n_forin: begin//read one more node assign one more node EXPRESSION 
				line_code := kw_for;
				line_code := line_code + ' ' +TForin(icode[i])._var + ' ' + kw_in + ' ' + icode[i+1].name + ' ' + kw_do;
				inc(i); //curr = EXPRESSION node
				goto do_write_no_semicolon;
			end;
			n_flow: begin
				line_code := icode[i].name;
			end;
			{n_lock: begin
				line_code := str_def_cs_name + str_lock;
				main_area.add(DupeString(str_tab,ast_lv) + line_code + ';');
				line_code := kw_try;
				inc(i);
				goto do_write_no_semicolon;
			end;
			n_unlock: begin
				main_area.add(DupeString(str_tab,ast_lv) + kw_finally);
				line_code := str_def_cs_name + str_unlock;
				main_area.add(DupeString(str_tab,ast_lv) + line_code + ';');
				line_code := kw_end;
				inc(i);
				goto do_write;
			end;}
			n_run: begin
				line_code := DupeString(str_tab,ast_lv) + gen_run(symtab,icode[i+1],'p', ast_lv,TRun(icode[i])._wait);
				var_area.add(line_code);
				line_code := '';
				inc(i,2);
			end;
			n_raise: begin
				tmp_stringlist := TStringList.Create;
				Split('|', icode[i].name, tmp_stringlist);
				for temp_count := 0 to tmp_stringlist.Count-1 do begin
					//main_area.add(DupeString(str_tab,ast_lv) + fix_event_raise_name(tmp_stringlist[temp_count]) + ';' );
					line_code := DupeString(str_tab,ast_lv) + gen_run(symtab,TMethod.Create(fix_event_raise_name(tmp_stringlist[temp_count])),'p', ast_lv,TRaise(icode[i])._wait);
					var_area.add(line_code);
					line_code := '';
				end;
				tmp_stringlist.Free;
				inc(i);
			end;
			n_line_end: begin
				do_write:
					line_code := DupeString(str_tab,ast_lv) + line_code + ';';
					//var or main
					if (pre_node_type = n_variable ) then
						var_area.add(line_code)
					else
						main_area.add(line_code);
					line_code := '';
					//add level when pre code is begin
					{if (pre_node_type = n_begin) then
						ast_lv:= ast_lv+1;}
			end;
			'nothing_for_label': begin
				do_write_no_semicolon:
					line_code := DupeString(str_tab,ast_lv) + line_code;
					//var or main
					if (pre_node_type = n_variable ) then
						var_area.add(line_code)
					else
						main_area.add(line_code);
					line_code := '';
			end;
			else begin
				perror('CodeGen Error:' + icode[i].to_string());
			end;
		end;
		pre_node_type := icode[i].node_type;
		inc(i);
	until (i > icode.Count -1);
end;

function TCodeGen.gen_default_method_call(symtab:TObjectSymList; icode:TNodeList; idx:integer;var line_code:String):integer;
var
	i:integer;
begin
	i := idx;
	repeat
		case icode[i].node_type of
			n_defmethod: begin
				line_code := line_code + icode[i].name + '(';
			end;
			n_line_end: begin
				line_code := line_code + ')';
				//just return and skip this line
				exit(i-1);
			end;
			else begin
				line_code := line_code + icode[i].name;
			end;
		end;
		inc(i);
	until (i > icode.Count -1);
end;

function TCodeGen.gen_assign(symtab:TObjectSymList; icode:TNodeList; idx:integer;var line_code:String):integer;
var
	i:integer;
begin
	i := idx;
	repeat
		case icode[i].node_type of
			n_assign: begin
				line_code := line_code + icode[i].name + ' := ';
			end;
			n_new: begin
				line_code := line_code + icode[i].name + '.Create';
			end;
			n_line_end: begin
				//just return and skip this line
				exit(i-1);
			end;
			else begin
				line_code := line_code + icode[i].name;
			end;
		end;
		inc(i);
	until (i > icode.Count -1);
end;

function TCodeGen.gen_interface(symtab:TObjectSymList; icode:TNodeList; idx:integer):integer;
var
	i:integer;
	line_code:string;
begin
	i := idx;
	repeat
		case icode[i].node_type of
			n_interface: begin
				type_area.add(DupeString(str_tab,1) + icode[i].name + ' = ' + kw_interface);
				forward_type_area.add(DupeString(str_tab,1) + icode[i].name + ' = ' + kw_interface + ';');
			end;
			n_begin: begin
				ast_lv:= ast_lv+1;
				line_code := '';
			end;
			n_end: begin
				ast_lv :=ast_lv -1;
				if (ast_lv=0) then begin
					type_area.add(DupeString(str_tab,1) + kw_end + ';');
					exit(i);
				end;
				line_code := '';
			end;
			n_function: begin
				line_code := kw_func + ' ' + icode[i].name;
				if (icode[i+1].node_type = n_param) then begin
					line_code := line_code + '(' + icode[i+1].name + '):' + TFunction(icode[i]).return_type + ';';
				end;
				if (TFunction(icode[i]).poly <> '') then begin
					line_code := line_code + TFunction(icode[i]).poly + ';';
				end;
				type_area.add(DupeString(str_tab,2) + line_code);
				inc(i);
			end;
			n_procedure: begin
				line_code := kw_proc + ' ' + icode[i].name;
				if (icode[i+1].node_type = n_param) then begin
					line_code := line_code + '(' + icode[i+1].name + ');';
				end;
				if (TProc(icode[i]).poly <> '') then begin
					line_code := line_code + TProc(icode[i]).poly + ';';
				end;
				type_area.add(DupeString(str_tab,2) + line_code);
				inc(i);
			end;
			else begin
				perror('CodeGen Error:' + icode[i].to_string());
			end;
		end;
		inc(i);
	until (i > icode.Count -1);
end;

function TCodeGen.gen_class(symtab:TObjectSymList; icode:TNodeList; idx:integer):integer;
var
	class_name : string;
	varindex : integer = 0;
	publicindex : integer = 0;
	i:integer;
	line_code:string;
	pre_node_type:string = '';
	tmp_str:string;
	is_state_machine:boolean = false;
	//is_doing_event : boolean =false ;
	state_list : TStringList;
	tmp_stringlist : TStringList;
	temp_count:integer;
	machine_create_line:TIntegerList;
	//class_cs_name :string; //for doing locking
	label do_write, do_write_no_semicolon;
begin
	state_list := TStringList.create;
	machine_create_line:=TIntegerList.create;
	i := idx;
	repeat
		case icode[i].node_type of
			n_class: begin
				class_name := icode[i].name;
				//forware type
				forward_type_area.add(DupeString(str_tab,1) + class_name + ' = ' + kw_class + ';');
				// add to type
				tmp_str := '';
				line_code := icode[i].name + ' = ' + kw_class ;
				if (TClass(icode[i]).extends <> '') then begin
					tmp_str := tmp_str + TClass(icode[i]).extends;
				end
				else begin
					tmp_str := tmp_str + 'TInterfacedObject';
				end;
				if (TClass(icode[i]).implements <> '') then begin
					tmp_str := tmp_str + ',' + TClass(icode[i]).implements;
				end;
				if (tmp_str <> '') then begin
					line_code := line_code + '(' + tmp_str + ')';
				end;
				type_area.add(DupeString(str_tab,1) +line_code);
				type_area.add(DupeString(str_tab,2) + kw_public);
				publicindex := type_area.Count;
				//default var
				//class_cs_name := str_def_cs_name + '_' + class_name;
				//type_area.add(DupeString(str_tab,3) + class_cs_name + str_criticalsection); 
			end;
			n_begin: begin
				//dont show if the begin is class begin
				if not (ast_lv = 0) then begin
					line_code := DupeString(str_tab,ast_lv) + kw_begin;
					impl_area.add(line_code);
				end;
				//create lock for machine
				if (pre_node_type = n_param) then begin
					if (icode[i-2].node_type = n_constructor) then begin
						impl_area.add(DupeString(str_tab,ast_lv+1) + str_sm_lock + '_' + class_name + str_def_sm_lock_create);
						machine_create_line.add(impl_area.Count - 1);
						//create event lock for machine
						impl_area.add(DupeString(str_tab,ast_lv+1) + str_sm_trans_lock + '_' + class_name + str_def_sm_lock_create);
						machine_create_line.add(impl_area.Count - 1);
					end;
				end;
				
				{//lock event
				if (pre_node_type = n_param) then begin
					if (icode[i-2].node_type = n_event) then begin
						impl_area.add(DupeString(str_tab,ast_lv+1) + str_sm_trans_lock + '_' + class_name + str_lock + ';');
					end;
				end;}
				
				ast_lv:= ast_lv+1;
				line_code := '';
			end;
			n_end: begin
				ast_lv :=ast_lv -1;
				//add to type if end class
				if (ast_lv=0) then begin
					//check at least one constructor
					if (machine_create_line.Count = 0) then begin
						perror('Error: class '+class_name + ' requests at least one constructor.');
					end;
					//gen state machine code if it is state machine
					if (is_state_machine) then begin
						//add lock
						type_area.insert(publicindex, DupeString(str_tab,3) + str_sm_lock + '_' + class_name + str_def_sm_lock);
						type_area.insert(publicindex, DupeString(str_tab,3) + str_sm_trans_lock + '_' + class_name + str_def_sm_lock);
						gen_statemachine_lib(class_name,publicindex,state_list);
						add_uses('TomoSys');
					end
					else
					begin
						//if not, remove all added lock and createstatement
						for temp_count := machine_create_line.Count-1 downto 0 do begin
							impl_area.Delete(machine_create_line[temp_count]);
						end;
					end;
					type_area.add(DupeString(str_tab,1) + kw_end + ';');
					state_list.Free;
					machine_create_line.Free;
					exit(i);
				end;
				{if is_doing_event then begin
					impl_area.add(DupeString(str_tab,ast_lv+1) + str_sm_trans_lock + '_' + class_name + str_unlock + ';');
					is_doing_event:=false;
				end;}
				// if next node is else then do not add semicolon
				line_code := DupeString(str_tab,ast_lv) + kw_end;
				if not (icode[i+1].node_type = n_else) then begin
					line_code := line_code + ';';
				end;
				impl_area.add(line_code);
				line_code := '';
				//if level is 1 then reset varindex
				if (ast_lv = 1) then begin
					varindex :=0;
				end;
			end;
			n_variable: begin
				line_code := icode[i].name;
			end;
			n_constructor: begin
				line_code := '';
				if (icode[i+1].node_type = n_param) then begin
					line_code := line_code + '(' + icode[i+1].name + ');';
				end;
				if (TConstructor(icode[i]).poly <> '') then begin
					line_code := line_code + TConstructor(icode[i]).poly + ';';
				end;
				type_area.add(DupeString(str_tab,3) + kw_constructor + ' Create' + line_code);
				impl_area.add(DupeString(str_tab,ast_lv) + kw_constructor + ' ' + class_name + '.Create' + line_code);
				varindex := impl_area.Count;
				inc(i);
			end;
			n_function: begin
				line_code := icode[i].name;
				if (icode[i+1].node_type = n_param) then begin
					line_code := line_code + '(' + icode[i+1].name + '):' + TFunction(icode[i]).return_type + ';';
				end;
				if (TFunction(icode[i]).poly <> '') then begin
					line_code := line_code + TFunction(icode[i]).poly + ';';
				end;
				type_area.add(DupeString(str_tab,3) + kw_func + ' ' + line_code);
				impl_area.add(DupeString(str_tab,ast_lv) + kw_func + ' ' + class_name + '.' + line_code);
				varindex := impl_area.Count;
				inc(i);
			end;
			n_procedure: begin
				line_code := icode[i].name;
				if (icode[i+1].node_type = n_param) then begin
					line_code := line_code + '(' + icode[i+1].name + ');';
				end;
				if (TProc(icode[i]).poly <> '') then begin
					line_code := line_code + TProc(icode[i]).poly + ';';
				end;
				type_area.add(DupeString(str_tab,3) + kw_proc + ' ' + line_code);
				impl_area.add(DupeString(str_tab,ast_lv) + kw_proc + ' ' + class_name + '.' + line_code);
				varindex := impl_area.Count;
				inc(i);
			end;
			n_state: begin
				is_state_machine:=true;
				state_list.add(icode[i].name);
				const_area.add(DupeString(str_tab,1) + str_state+'_'+class_name+'_'+icode[i].name +'='''+icode[i].name+''';');
				line_code := str_state + '_' + icode[i].name + '();';
				type_area.add(DupeString(str_tab,3) + kw_proc + ' ' + line_code);
				impl_area.add(DupeString(str_tab,ast_lv) + kw_proc + ' ' + class_name + '.' + line_code);
				varindex := impl_area.Count;
			end;
			n_event: begin
				//is_doing_event:=true;
				is_state_machine:=true;
				line_code := str_event + '_' + icode[i].name;
				if (icode[i+1].node_type = n_param) then begin
					line_code := line_code + '(' + icode[i+1].name + ');';
				end;
				type_area.add(DupeString(str_tab,3) + kw_proc + ' ' + line_code);
				impl_area.add(DupeString(str_tab,ast_lv) + kw_proc + ' ' + class_name + '.' + line_code);
				varindex := impl_area.Count;
				inc(i);
			end;
			n_Fromto: begin
				is_state_machine:=true;
				// n_expression or not
				if (icode[i+1].node_type = n_expression) then begin
					//gen expression
					impl_area.add(DupeString(str_tab,ast_lv) + kw_if + ' ' + icode[i+1].name + ' ' + kw_then);
					impl_area.add(DupeString(str_tab,ast_lv) + kw_begin);
						//gen state case
						impl_area.add(DupeString(str_tab,ast_lv+1) + kw_if + ' (' + str_state + '=' + str_state+'_'+class_name+'_'+TFromto(icode[i])._from +') ' + kw_then);
						impl_area.add(DupeString(str_tab,ast_lv+1) + kw_begin);
						impl_area.add(DupeString(str_tab,ast_lv+2) + str_sm_trans_lock + '_' + class_name + str_lock + ';');
							//if has do func call gen it
							if (icode[i+2].node_type = n_method) then begin
								impl_area.add(DupeString(str_tab,ast_lv+2) + icode[i+2].name+ ';');
							end;
						impl_area.add(DupeString(str_tab,ast_lv+2) + 'set_state' + '(' + str_state+'_'+class_name+'_'+TFromto(icode[i])._to +');');
						//unlock event
						impl_area.add(DupeString(str_tab,ast_lv+2) + str_sm_trans_lock + '_' + class_name + str_unlock + ';');
						impl_area.add(DupeString(str_tab,ast_lv+2) + 'exit;');
						impl_area.add(DupeString(str_tab,ast_lv+1) + kw_end + ';');
					impl_area.add(DupeString(str_tab,ast_lv) + kw_end + ';');
					if (icode[i+2].node_type = n_method) then begin
						inc(i);
					end;
					inc(i,2);
				end
				else if (icode[i+1].node_type = n_method) then begin
					//if only do, no when
					//gen state case
					impl_area.add(DupeString(str_tab,ast_lv) + kw_if + ' (' + str_state + '=' + str_state+'_'+class_name+'_'+TFromto(icode[i])._from +') ' + kw_then);
					impl_area.add(DupeString(str_tab,ast_lv) + kw_begin);
					impl_area.add(DupeString(str_tab,ast_lv+2) + str_sm_trans_lock + '_' + class_name + str_lock + ';');
						impl_area.add(DupeString(str_tab,ast_lv+2) + icode[i+1].name+ ';');
					impl_area.add(DupeString(str_tab,ast_lv+1) + 'set_state' + '(' + str_state+'_'+class_name+'_'+TFromto(icode[i])._to +');');
					//unlock event
					impl_area.add(DupeString(str_tab,ast_lv+1) + str_sm_trans_lock + '_' + class_name + str_unlock + ';');
					impl_area.add(DupeString(str_tab,ast_lv+1) + 'exit;');
					impl_area.add(DupeString(str_tab,ast_lv) + kw_end + ';');
					inc(i,2);
				end
				else
				begin
					//gen state case
					impl_area.add(DupeString(str_tab,ast_lv) + kw_if + ' (' + str_state + '=' + str_state+'_'+class_name+'_'+TFromto(icode[i])._from +') ' + kw_then);
					impl_area.add(DupeString(str_tab,ast_lv) + kw_begin);
					impl_area.add(DupeString(str_tab,ast_lv+1) + str_sm_trans_lock + '_' + class_name + str_lock + ';');
					impl_area.add(DupeString(str_tab,ast_lv+1) + 'set_state' + '(' + str_state+'_'+class_name+'_'+TFromto(icode[i])._to +');');
					//unlock event
					impl_area.add(DupeString(str_tab,ast_lv+1) + str_sm_trans_lock + '_' + class_name + str_unlock + ';');
					impl_area.add(DupeString(str_tab,ast_lv+1) + 'exit;');
					impl_area.add(DupeString(str_tab,ast_lv) + kw_end + ';');
					inc(i);
				end;
			end;
			n_cstate: begin
				line_code := 'set_state' + '(' + str_state+'_'+class_name+'_'+icode[i].name +')';
			end;
			n_assign: begin
				i := gen_assign(symtab,icode,i,line_code);
			end;
			n_method: begin
				line_code := icode[i].name;
			end;
			n_defmethod: begin
				i := gen_default_method_call(symtab,icode,i,line_code);
			end;
			n_return: begin
				line_code := kw_exit;
				line_code := line_code + '(' +icode[i+1].name + ')';
				inc(i);
			end;
			n_if: begin //read one more node EXPRESSION
				line_code := kw_if;
				line_code := line_code + ' ' +icode[i+1].name + ' ' + kw_then;
				inc(i); //curr = EXPRESSION node
				goto do_write_no_semicolon;
			end;
			n_else: begin
				line_code := kw_else;
				goto do_write_no_semicolon;
			end;
			n_while: begin //read one more node EXPRESSION
				line_code := kw_while;
				line_code := line_code + ' ' +icode[i+1].name + ' ' + kw_do;
				inc(i); //curr = EXPRESSION node
				goto do_write_no_semicolon;
			end;
			n_forto: begin //read one more node assign one more node EXPRESSION 
				line_code := kw_for;
				line_code := line_code + ' ' +icode[i+1].name + ' ' + kw_to + ' ' + icode[i+2].name + ' ' + kw_do;
				inc(i,2); //curr = EXPRESSION node
				goto do_write_no_semicolon;
			end;
			n_fordownto: begin //read one more node assign one more node EXPRESSION 
				line_code := kw_for;
				line_code := line_code + ' ' +icode[i+1].name + ' ' + kw_downto + ' ' + icode[i+2].name + ' ' + kw_do;
				inc(i,2); //curr = EXPRESSION node
				goto do_write_no_semicolon;
			end;
			n_forin: begin//read one more node assign one more node EXPRESSION 
				line_code := kw_for;
				line_code := line_code + ' ' +TForin(icode[i])._var + ' ' + kw_in + ' ' + icode[i+1].name + ' ' + kw_do;
				inc(i); //curr = EXPRESSION node
				goto do_write_no_semicolon;
			end;
			n_flow: begin
				line_code := icode[i].name;
			end;
			{n_lock: begin
				line_code := str_def_cs_name + str_lock;
				impl_area.add(DupeString(str_tab,ast_lv) + line_code + ';');
				line_code := kw_try;
				inc(i);
				goto do_write_no_semicolon;
			end;
			n_unlock: begin
				impl_area.add(DupeString(str_tab,ast_lv) + kw_finally);
				line_code := str_def_cs_name + str_unlock;
				impl_area.add(DupeString(str_tab,ast_lv) + line_code + ';');
				line_code := kw_end;
				inc(i);
				goto do_write;
			end;}
			n_run: begin
				line_code := gen_run(symtab,icode[i+1],'i', ast_lv, TRun(icode[i])._wait);
				type_area.insert(publicindex,DupeString(str_tab,3) + line_code);
				line_code := '';
				inc(i,2);
			end;
			n_raise: begin
				tmp_stringlist := TStringList.Create;
				Split('|', icode[i].name, tmp_stringlist);
				for temp_count := 0 to tmp_stringlist.Count-1 do begin
					line_code := DupeString(str_tab,3) + gen_run(symtab,TMethod.Create(fix_event_raise_name(tmp_stringlist[temp_count])),'i', ast_lv, TRaise(icode[i])._wait);
					type_area.insert(publicindex,line_code);
					line_code := '';
				end;
				tmp_stringlist.Free;
				inc(i);
			end;
			n_line_end: begin
				do_write:
					line_code := line_code + ';';
					//var or main
					if (pre_node_type = n_variable ) then
					begin
						if (varindex = 0) then 
						begin
							type_area.add(DupeString(str_tab,3) + line_code);
						end
						else
						begin
							impl_area.insert(varindex,DupeString(str_tab,ast_lv) + kw_var + ' ' +line_code);
						end;
					end
					else
						impl_area.add(DupeString(str_tab,ast_lv) + line_code);
					line_code := '';
			end;
			'nothing_for_label': begin
				do_write_no_semicolon:
					line_code := line_code;
					//var or main
					if (pre_node_type = n_variable ) then
					begin
						if (varindex = 0) then 
						begin
							type_area.add(DupeString(str_tab,3) + line_code);
						end
						else
						begin
							impl_area.insert(varindex,DupeString(str_tab,ast_lv) + kw_var + ' ' +line_code);
						end;
					end
					else
						impl_area.add(DupeString(str_tab,ast_lv) + line_code);
					line_code := '';
			end;
			else begin
				perror('CodeGen Error:' + icode[i].to_string());
			end;
		end;
		pre_node_type := icode[i].node_type;
		inc(i);
	until (i > icode.Count -1);
end;

procedure TCodeGen.gen_statemachine_lib(class_name:string;publicindex:integer;state_list:TStringList);
var temp_count:integer;
begin
	//gen current state variable
	type_area.insert(publicindex, DupeString(str_tab,3) + str_state + ':string;');
	//gen get_state() string
	type_area.add(DupeString(str_tab,3) + kw_func + ' get_state():string;');
	impl_area.add(DupeString(str_tab,1) + kw_func + ' ' + class_name + '.get_state():string;');
	impl_area.add(DupeString(str_tab,1) + kw_begin);
	impl_area.add(DupeString(str_tab,2) + kw_exit + '(' + str_state + ');');
	impl_area.add(DupeString(str_tab,1) + kw_end + ';');
	//gen set_state(string) with lock protect
	type_area.add(DupeString(str_tab,3) + kw_proc + ' set_state(s:string);');
	impl_area.add(DupeString(str_tab,1) + kw_proc + ' ' + class_name +'.set_state(s:string);');
	//impl_area.add(DupeString(str_tab,1) + kw_var + ' clone_state:string;');
	impl_area.add(DupeString(str_tab,1) + kw_begin);
	impl_area.add(DupeString(str_tab,2) + str_sm_lock + '_' + class_name + str_lock + ';');
	impl_area.add(DupeString(str_tab,2) + kw_try);
	impl_area.add(DupeString(str_tab,2) + str_state + ':=s;');
	//impl_area.add(DupeString(str_tab,2) + 'clone_state:=' + str_state + ';');
		//gen auto run state action
	if (state_list.Count <> 0) then begin
		impl_area.add(DupeString(str_tab,2) + 'case '+str_state + ' of ');
		for temp_count := 0 to state_list.Count -1  do 
		begin
			impl_area.add(DupeString(str_tab,3) + str_state+'_'+class_name+'_'+state_list[temp_count]+':' + str_state + '_' + state_list[temp_count]+ '();');
		end;
		impl_area.add(DupeString(str_tab,2) + kw_end + ';');
	end;
	
	impl_area.add(DupeString(str_tab,2) + kw_finally);
	impl_area.add(DupeString(str_tab,2) + str_sm_lock + '_' + class_name +  str_unlock + ';');
	impl_area.add(DupeString(str_tab,2) + kw_end + ';');
	
	impl_area.add(DupeString(str_tab,1) + kw_end + ';');
end;

procedure TCodeGen.Split(Delimiter: Char; Str: string; ListOfStrings: TStrings) ;
begin
   ListOfStrings.Clear;
   ListOfStrings.StrictDelimiter := true;
   ListOfStrings.Delimiter := Delimiter;
   ListOfStrings.DelimitedText := Str;
end;

function TCodeGen.gen_run(symtab:TObjectSymList; inode:TNode; area:string; lv:integer; await:boolean):string ;
var
	method_node: TMethod;
	str_method_full: string;
	str_method_p1: string;
	str_method_p2: string;
	str_args: string;
	args:TStringList;
	class_name: string;
	tmp_num : integer;
	thread_type_name : string;
	thread_type_var : string;
	temp_count: integer;
	temp_str : string;
begin
	method_node := TMethod(inode);
	args := TStringList.Create;
	//if have args
	tmp_num := pos('(',method_node.name);
	if tmp_num <> Length(method_node.name) -1 then begin
		str_args := copy(method_node.name, tmp_num + 1 , Length(method_node.name) -1 - tmp_num);
		Split(',', str_args, args);
	end;
	//get method part
	str_method_full := copy(method_node.name, 1, tmp_num -1 );
	//chk has dot, if yes split to p1 p2
	tmp_num := pos('.',str_method_full);
	if tmp_num <> 0 then begin
		str_method_p1 := copy(str_method_full, 1, tmp_num - 1);
		str_method_p2 := copy(str_method_full, tmp_num + 1, Length(str_method_full) - tmp_num);
	end
	else begin //if no dot, this is class call
		str_method_p1 := 'Self';
		str_method_p2 := str_method_full;
	end;
	//get class name, remark p1 is variable name
	class_name := 'UNKNOWN;';
	if (str_method_p1 <> 'Self') then begin
		//check is array item
		tmp_num :=  pos('[',str_method_p1);
		if tmp_num <> 0 then begin
			//get type for array
			temp_str := copy(str_method_p1, 1, tmp_num - 1);
			if symtab[obj_tab_index].object_syms.look_up(temp_str) then begin
				class_name := symtab[obj_tab_index].object_syms.get_type(temp_str);
				tmp_num :=  pos(' of ',class_name);
				class_name := copy(class_name, tmp_num + 4, Length(class_name) - tmp_num - 3);
			end
			else
			begin
				for temp_count := 0 to symtab[obj_tab_index].methods.Count -1  do 
				begin
					if symtab[obj_tab_index].methods[temp_count].look_up(temp_str) then begin
						class_name := symtab[obj_tab_index].methods[temp_count].get_type(temp_str);
						tmp_num :=  pos(' of ',class_name);
						class_name := copy(class_name, tmp_num + 4, Length(class_name) - tmp_num - 3);
					end;
				end;
			end;
		end
		else begin //normal var
			if symtab[obj_tab_index].object_syms.look_up(str_method_p1) then begin
				class_name := symtab[obj_tab_index].object_syms.get_type(str_method_p1);
			end
			else
			begin
				for temp_count := 0 to symtab[obj_tab_index].methods.Count -1  do 
				begin
					if symtab[obj_tab_index].methods[temp_count].look_up(str_method_p1) then begin
						class_name := symtab[obj_tab_index].methods[temp_count].get_type(str_method_p1);
					end;
				end;
			end;
		end;
	end
	else
		class_name := symtab[obj_tab_index].object_syms.name;

	//gen thread type define
	thread_type_name := str_thread_type + '_' + IntToStr(run_thd_id_num);
	thd_type_area.add(DupeString(str_tab,1) + thread_type_name + ' = class(TThread)');
	thd_type_area.add(DupeString(str_tab,2) + kw_public);
	thd_type_area.add(DupeString(str_tab,3) + 'pptr:' + class_name + ';');
	for temp_count := 0 to args.Count -1  do 
		thd_type_area.add(DupeString(str_tab,3) + 'p' + IntToStr(temp_count) + ':Variant;');
	thd_type_area.add(DupeString(str_tab,3) + 'Constructor Create(CreateSuspended : boolean);');
	thd_type_area.add(DupeString(str_tab,3) + 'procedure Execute; override;');
	thd_type_area.add(DupeString(str_tab,1) + kw_end + ';');
	//gen thread impl
	thd_impl_area.add(DupeString(str_tab,1) + kw_constructor + ' ' + thread_type_name + '.Create(CreateSuspended : boolean);');
	thd_impl_area.add(DupeString(str_tab,1) + kw_begin);
	// only free on not wait
	if not(await) then 
		thd_impl_area.add(DupeString(str_tab,2) + 'FreeOnTerminate := True;');
	thd_impl_area.add(DupeString(str_tab,2) + 'inherited Create(CreateSuspended);');
	thd_impl_area.add(DupeString(str_tab,1) + kw_end + ';');
	thd_impl_area.add('');
	thd_impl_area.add(DupeString(str_tab,1) + kw_proc + ' ' + thread_type_name + '.Execute;');
	thd_impl_area.add(DupeString(str_tab,1) + kw_begin);
	temp_str := '';
	for temp_count := 0 to args.Count -1  do 
		temp_str := temp_str + 'p' + IntToStr(temp_count) + ',';
	if (Length(temp_str) <> 0) then begin
		temp_str:= copy(temp_str, 1, Length(temp_str) -1 );
	end;
	thd_impl_area.add(DupeString(str_tab,2) + 'pptr.' + str_method_p2 + '(' + temp_str + ');');
	thd_impl_area.add(DupeString(str_tab,2) + 'Terminate;');
	thd_impl_area.add(DupeString(str_tab,1) + kw_end + ';');
	thd_impl_area.add('');
	//gen run code p = main i = impl
	thread_type_var := str_thread_var + '_' + IntToStr(run_thd_id_num);
	if (area = 'p') then begin
		main_area.add(DupeString(str_tab,lv) + thread_type_var + ' := ' + thread_type_name + '.Create(true);');
		main_area.add(DupeString(str_tab,lv) + thread_type_var + '.pptr := ' + str_method_p1 + ';');
		for temp_count := 0 to args.Count -1  do 
			main_area.add(DupeString(str_tab,lv) + thread_type_var + '.p' + IntToStr(temp_count) + ' := ' + args[temp_count] + ';');
		main_area.add(DupeString(str_tab,lv) + thread_type_var + '.Start;');
		//if wait, gen wait thread
		if (await) then begin
			main_area.add(DupeString(str_tab,lv) + thread_type_var + '.WaitFor();');
			main_area.add(DupeString(str_tab,lv) + 'FreeAndNil(' + thread_type_var + ');');
		end;
	end;
	if (area = 'i') then begin
		impl_area.add(DupeString(str_tab,lv) + thread_type_var + ' := ' + thread_type_name + '.Create(true);');
		impl_area.add(DupeString(str_tab,lv) + thread_type_var + '.pptr := ' + str_method_p1 + ';');
		for temp_count := 0 to args.Count -1  do 
			impl_area.add(DupeString(str_tab,lv) + thread_type_var + '.p' + IntToStr(temp_count) + ' := ' + args[temp_count] + ';');
		impl_area.add(DupeString(str_tab,lv) + thread_type_var + '.Start;');
		//if wait, gen wait thread
		if (await) then begin
			impl_area.add(DupeString(str_tab,lv) + thread_type_var + '.WaitFor();');
			impl_area.add(DupeString(str_tab,lv) + 'FreeAndNil(' + thread_type_var + ');');
		end;
	end;
	result := thread_type_var + ':' + thread_type_name + ';';
	//forward class define
	forward_type_area.add(DupeString(str_tab,1) + thread_type_name + ' = ' + kw_class + ';');
    inc(run_thd_id_num);
	args.Free;
end;

function TCodeGen.fix_event_raise_name(input:string):string;
var 
	method_call:string;
	res:string;
	l_num : integer;
	sub_list : TStringList;
	i: integer;
begin
	l_num := pos('(',input);
	method_call := copy(input,1,l_num-1);
	//if have . 
	if (pos('.',method_call)<>0) then begin
		res := '';
		sub_list := TStringList.Create;
		split('.',method_call,sub_list);
		sub_list[sub_list.Count -1 ] := str_event + '_' + sub_list[sub_list.Count -1];
		for i:=0 to sub_list.Count-1 do
			res := res + sub_list[i] + '.';
		sub_list.Free;
		res := copy(res, 1, Length(res) -1 );
		exit(res + copy(input, l_num, Length(input) - l_num + 1) );
	end
	else
	begin
		exit(str_event + '_' + method_call + copy(input, l_num, Length(input) - l_num + 1) );
	end;
end;

procedure TCodeGen.write_to_file(file_name,name_only:String);
var pas: TextFile;
	temp_count : integer;
begin
	//check name same
	if (program_name <> '') then begin
		if (program_name <> name_only) then
			perror('Error: File name not same to program name.' );
	end
	else if (unit_name <> '') then begin
		if (unit_name <> name_only) then
			perror('Error: File name not same to module name.');
	end;
    	
	AssignFile(pas, file_name + '.pas');
	try  
    	Rewrite(pas);
    	
    	// program or unit
    	if (program_name <> '') then begin
    		//part program
    		writeln(pas, kw_program + ' ' + program_name + ';');
	    	writeln(pas, str_objfpc);
	    	writeln(pas,'');
    	end
    	else if (unit_name <> '') then begin
    		//part unit
    		writeln(pas, kw_unit + ' ' + unit_name + ';');
	    	writeln(pas, str_objfpc);
	    	writeln(pas,'');
	    	writeln(pas,kw_interface);
	    	writeln(pas,'');
    	end;
    	
    	//part uses 
    	writeln(pas, kw_uses);
    	writeln(pas, str_use_default);
    	for temp_count := 0 to uses_area.Count -1  do 
			write(pas, ',' + uses_area[temp_count]);
    	writeln(pas,';');
    	
    	//part const
    	if (const_area.Count <> 0) then begin
    		writeln(pas, kw_const);
    	end;
    	for temp_count := 0 to const_area.Count -1  do 
			writeln(pas, const_area[temp_count]);
		writeln(pas,'');
    	//part type forward type
    	if (forward_type_area.Count <> 0) then begin
    		writeln(pas, kw_type);
    	end;
    	for temp_count := 0 to forward_type_area.Count -1  do 
			writeln(pas, forward_type_area[temp_count]);
		writeln(pas,'');
		
		// program or unit
    	if (program_name <> '') then begin
    		//part program variable Global
			if (var_area.Count <> 0) then begin
	    		writeln(pas, kw_var);
	    	end;
	    	for temp_count := 0 to var_area.Count -1  do 
				writeln(pas, var_area[temp_count]);
			writeln(pas,'');
    	end
    	else if (unit_name <> '') then begin
    	end;
    	
    	//part type define 1
    	if (type_area.Count <> 0) then begin
    		writeln(pas, kw_type);
    	end;
    	for temp_count := 0 to type_area.Count -1  do 
			writeln(pas, type_area[temp_count]);
		writeln(pas,'');
		//part type define thd
    	if (thd_type_area.Count <> 0) then begin
    		writeln(pas, kw_type);
    	end;
    	for temp_count := 0 to thd_type_area.Count -1  do 
			writeln(pas, thd_type_area[temp_count]);
		writeln(pas,'');
		
		// program or unit
    	if (program_name <> '') then begin
    	end
    	else if (unit_name <> '') then begin
    		writeln(pas,kw_impl);
    		writeln(pas,'');
    	end;
		
		//part implementation 1
    	for temp_count := 0 to impl_area.Count -1  do 
			writeln(pas, impl_area[temp_count]);
		writeln(pas,'');
    	//part implementation thd
    	for temp_count := 0 to thd_impl_area.Count -1  do 
			writeln(pas, thd_impl_area[temp_count]);
		writeln(pas,'');
		
		
		
    	
    	// program or unit
    	if (program_name <> '') then begin
    		//part main program code
    		for temp_count := 0 to main_area.Count -1  do 
			writeln(pas, main_area[temp_count]);
    	end
    	else if (unit_name <> '') then begin
    	end;
			
		writeln(pas, kw_end + '.');
    	CloseFile(pas);
  	except
    	on E: EInOutError do
    	begin
     		Writeln(E.ClassName+'/'+E.Message);
    	end;    
  	end;
end;

end.