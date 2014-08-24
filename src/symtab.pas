{ Copyright 2012-2014 Chong Cheung. All rights reserved.
Use of this source code is governed by a BSD-style license
that can be found in the LICENSE file. }
unit Symtab;

{$MODE OBJFPC} 

interface

uses
{$IFDEF UNIX}{$IFDEF UseCThreads}
cthreads,
{$ENDIF}{$ENDIF}
Classes, sysutils, fgl
{ you can add units after this };

const
	t_none = 'NONE';
	t_program = 'PROGRAM';
	t_interface = 'INTERFACE';
	t_class = 'CLASS';
	t_constructor='CONSTRUCTOR';
	t_function='FUNCTION';
	t_procedure='PROCEDURE';
	t_event='EVENT';
	t_state='STATE';

type 
	TIntegerList = specialize TFPGList<integer>;
	
	//level 3
	TSym = class(TObject) //variable, method call
		public
			name:String; //identifier
			data_type:String; 
			linenos:TIntegerList;
			constructor Create();
			destructor Destroy; override;
			function fix_char_len(str : String; num:integer) : String;
			procedure print;
	end;

	TSymList = specialize TFPGObjectList<TSym>;

	//level 2
	TMethodSymTable = class(TObject)
		public
			name:String; //function or procedure or event or constructor identifier
			syms:TSymList;
			table_type:String;
			constructor Create(n,t:String);
			destructor Destroy; override;
			procedure add_item(n,dtype:String;line:Integer);
			procedure append_lineno(n:String;line:Integer);
			function look_up(n:String):Boolean;
			function get_type(n:String):String;
			function fix_char_len(str : String; num:integer) : String;
			procedure print;
	end;

	TMethodSymList = specialize TFPGObjectList<TMethodSymTable>;

	//level 1
	TObjectSymTable = class(TMethodSymTable)
		public
			// from super , name:String; program or class or interface identifier
			object_syms: TMethodSymTable;
			methods: TMethodSymList;
			constructor Create(n,t:String);
			destructor Destroy; override;
			procedure print; 
	end;

	TObjectSymList = specialize TFPGObjectList<TObjectSymTable>;

implementation

//--------------
constructor TSym.Create();
begin
  inherited Create;
  linenos := TIntegerList.Create;
end;

destructor TSym.Destroy;
begin
  inherited Destroy;
  linenos.Free;
end;

function TSym.fix_char_len(str : String; num:integer) : String;
begin
	while length(str) < num do
		str := str + ' ';
	fix_char_len := str
end;

procedure TSym.print();
var i:integer;
begin
	write(fix_char_len(name,15),fix_char_len(data_type,15));
	for i := 0 to linenos.Count -1  do write(linenos[i],' ');
	writeln;
end;

//--------------
constructor TMethodSymTable.Create(n,t:String);
begin
  inherited Create;
  name:=n;
  syms:= TSymList.Create;
  table_type:=t;
end;

destructor TMethodSymTable.Destroy;
begin
  inherited Destroy;
  syms.Free;
end;

procedure TMethodSymTable.add_item(n,dtype:String;line:Integer);
var new_sym:TSym;
begin
	new_sym:= TSym.Create;
	new_sym.name:= n;
	new_sym.data_type:= dtype;
	new_sym.linenos.add(line);
	syms.add(new_sym);
end;

procedure TMethodSymTable.append_lineno(n:String;line:Integer);
var i:Integer;
begin
	for i := 0 to syms.Count -1  do 
	begin
		if (syms[i].name = n) then begin
			if (syms[i].linenos.indexof(line)= -1) then begin
				syms[i].linenos.add(line);
			end;
		end;
	end;
end;

function TMethodSymTable.look_up(n:String):Boolean;
var i:Integer;
begin
	result := false;
	for i := 0 to syms.Count -1  do 
	begin
		if (syms[i].name = n) then begin
			result := true;
		end;
	end;
end;

function TMethodSymTable.get_type(n:String):String;
var i:Integer;
begin
	result := '';
	for i := 0 to syms.Count -1  do 
	begin
		if (syms[i].name = n) then begin
			result := syms[i].data_type;
		end;
	end;
end;

function TMethodSymTable.fix_char_len(str : String; num:integer) : String;
begin
	while length(str) < num do
		str := str + ' ';
	fix_char_len := str
end;

procedure TMethodSymTable.print();
var i:integer;
begin
	writeln('**** ', table_type, ' ', name, ' ****');
	writeln;
	writeln(fix_char_len('Identifier',15), fix_char_len('Type',15), 'Line numbers');
	writeln(fix_char_len('----------',15), fix_char_len('----',15), '------------');
	for i := 0 to syms.Count -1  do syms[i].print;
	writeln;
end;

//-----------------------
constructor TObjectSymTable.Create(n,t:String);
begin
  inherited Create(n,t);
  object_syms:= TMethodSymTable.Create(n,t);
  methods:= TMethodSymList.Create;
end;

destructor TObjectSymTable.Destroy;
begin
  inherited Destroy;
  object_syms.Free;
  methods.Free;
end;

procedure TObjectSymTable.print();
var i:integer;
begin
	object_syms.print;
	for i := 0 to methods.Count -1  do methods[i].print;
end;

end.