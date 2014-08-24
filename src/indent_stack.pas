{ Copyright 2012-2014 Chong Cheung. All rights reserved.
Use of this source code is governed by a BSD-style license
that can be found in the LICENSE file. }
const STACK_SIZE = 1000;

type
	Tstack_item = record
		lineno,token,indent_level: integer;
	end;

var	
	indent_stack: array[1..STACK_SIZE] of Tstack_item;
	nil_stack_item: Tstack_item;
	stack_pointer: integer;

procedure init_stack;
begin
	stack_pointer:=0;
	nil_stack_item.lineno := 0;
	nil_stack_item.token := 0;
	nil_stack_item.indent_level := 0;
end;

function is_stack_empty: boolean;
begin
	is_stack_empty := false;
	if (stack_pointer = 0) then
		is_stack_empty := true;
end;

function is_stack_full: boolean;
begin
	is_stack_full := false;
	if ((stack_pointer+1) = STACK_SIZE) then
		is_stack_full := true;
end;

function stack_pop: Tstack_item;
begin
	stack_pop := nil_stack_item;
	if not is_stack_empty then
	begin
		stack_pop := indent_stack[stack_pointer];
		stack_pointer := stack_pointer - 1;
	end;
end;

procedure stack_push(item: Tstack_item);
begin
	if not is_stack_full then
	begin
		indent_stack[stack_pointer+1] := item;
		stack_pointer := stack_pointer + 1;
	end;
end;

function get_stack_size: integer;
begin
	get_stack_size := stack_pointer;
end;