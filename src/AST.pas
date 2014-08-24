{ Copyright 2012-2014 Chong Cheung. All rights reserved.
Use of this source code is governed by a BSD-style license
that can be found in the LICENSE file. }
unit AST;

{$MODE OBJFPC} 

interface

uses
{$IFDEF UNIX}{$IFDEF UseCThreads}
cthreads,
{$ENDIF}{$ENDIF}
Classes, sysutils, fgl
{ you can add units after this };

const
	n_none = 'NONE';
	n_program = 'PROGRAM_DEFINE';
	n_class = 'CLASS_DEFINE';
	n_interface = 'INTERFACE_DEFINE';
	n_constructor='CONSTRUCTOR_DEFINE';
	n_function='FUNCTION_DEFINE';
	n_procedure='PROCEDURE_DEFINE';
	n_event='EVENT_DEFINE';
	n_state='STATE_DEFINE';
	n_variable='VARIABLE_DEFINE';
	n_param='PARAMETER_DEFINE';

	n_new='NEW_OBJECT';
	n_expression='EXPRESSION';
	n_defmethod='DEFAULT_METHOD_CALL';
	n_method='METHOD_CALL';
	n_mparam='METHOD_PARAMETER';
	{n_lock='LOCK';
	n_unlock='UNLOCK';}
	n_run='RUN';
	n_return='RETURN';
	n_raise='RAISE_EVENT';
	n_flow='FLOW';
	n_assign='ASSIGN';
	n_if='IF';
	n_else='ELSE';
	n_while='WHILE_LOOP';
	n_forto='FOR_TO_LOOP';
	n_fordownto='FOR_DOWNTO_LOOP';
	n_forin='FOR_IN_LOOP';
	n_begin='BEGIN';
	n_end='END';
	n_line_end='LINE_END';
	n_fromto='TRANSITION';
	n_cstate='CHANGE_STATE';

type 
	
	TUsesList = TStringList;

	TNode = class(TObject)
		public
			node_type:String;
			name:String;
			function to_string: String; Virtual; Abstract;
			constructor Create(t,n:String);
			destructor Destroy; override;
			procedure Split(Delimiter: Char; Str: string; ListOfStrings: TStrings);
	end;

	TNodeList = specialize TFPGObjectList<TNode>;

	TNodeListList = specialize TFPGObjectList<TNodeList>;

	TProgram = class(TNode)
		public
			constructor Create(n:String);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TClass = class(TNode)
		public
			extends:String;
			implements:String;
			constructor Create(n,e,i:String);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TInterface = class(TNode)
		public
			constructor Create(n:String);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TConstructor = class(TNode)
		public
			poly:String;
			constructor Create(p:String);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TFunction = class(TNode)
		public
			return_type:string;
			poly:String;
			constructor Create(n,p,r:String);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TProc = class(TNode)
		public
			poly:String;
			constructor Create(n,p:String);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TEvent = class(TNode)
		public
			constructor Create(n:String);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TVariable = class(TNode)
		public
			constructor Create(n:String);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TParameter = class(TNode)
		public
			constructor Create(n:String);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TNew= class(TNode)
		public
			constructor Create(n:String);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TExpression= class(TNode)
		public
			constructor Create(n:String);
			destructor Destroy; override;
			function to_string: String; override;
	end;
	//runtime provided method use this
	TDEFMethod = class(TNode)
		public
			constructor Create(n:String);
			destructor Destroy; override;
			function to_string: String; override;
	end;
	//line start with method call use this
	TMethod = class(TNode)
		public
			constructor Create(n:String);
			destructor Destroy; override;
			function to_string: String; override;
	end;
	//use by raise or some method
	TMParameter = class(TNode)
		public
			constructor Create(n:String);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	{TLock = class(TNode)
		public
			constructor Create();
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TUnLock = class(TNode)
		public
			constructor Create();
			destructor Destroy; override;
			function to_string: String; override;
	end;}

	TRun = class(TNode)
		public
			_wait:boolean;
			constructor Create(w:boolean);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TReturn = class(TNode)
		public
			constructor Create();
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TRaise = class(TNode)
		public
			_wait:boolean;
			constructor Create(n:String;w:boolean);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TState = class(TNode)
		public
			constructor Create(n:String);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TFlow = class(TNode)
		public
			constructor Create(n:String);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TAssign = class(TNode)
		public
			constructor Create(n:String);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TIf = class(TNode)
		public
			constructor Create();
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TElse = class(TNode)
		public
			constructor Create();
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TWhile = class(TNode)
		public
			constructor Create();
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TForto = class(TNode)
		public
			constructor Create();
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TFordownto = class(TNode)
		public
			constructor Create();
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TForin = class(TNode)
		public
			_var:String;
			constructor Create(v:string);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TBegin = class(TNode)
		public
			constructor Create();
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TEnd = class(TNode)
		public
			constructor Create();
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TLineEnd = class(TNode)
		public
			constructor Create();
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TFromto = class(TNode)
		public
			_from:string;
			_to:string;
			constructor Create(f,t:string);
			destructor Destroy; override;
			function to_string: String; override;
	end;

	TCState = class(TNode)
		public
			constructor Create(n:string);
			destructor Destroy; override;
			function to_string: String; override;
	end;

implementation

//--------------
constructor TNode.Create(t,n:String);
begin
  inherited Create;
  node_type:=t;
  name:=n;
end;

destructor TNode.Destroy;
begin
  inherited Destroy;
end;

procedure TNode.Split(Delimiter: Char; Str: string; ListOfStrings: TStrings) ;
begin
   ListOfStrings.Clear;
   ListOfStrings.Delimiter := Delimiter;
   ListOfStrings.DelimitedText := Str;
end;

constructor TProgram.Create(n:String);
begin
  inherited Create(n_program,n);
end;

destructor TProgram.Destroy;
begin
  inherited Destroy;
end;

function TProgram.to_string: String;
begin
	result:= node_type + '[' + name + ']';
end;

constructor TClass.Create(n,e,i:String);
begin
  inherited Create(n_class,n);
  extends:= e;
  implements:= i;
end;

destructor TClass.Destroy;
begin
  inherited Destroy;
end;

function TClass.to_string: String;
begin
	result:= node_type + '[' + name + ']' + 'EXTENDS[' + extends + ']' + 'IMPLEMENTS[' + implements +']';
end;

constructor TInterface.Create(n:String);
begin
  inherited Create(n_interface,n);
end;

destructor TInterface.Destroy;
begin
  inherited Destroy;
end;

function TInterface.to_string: String;
begin
	result:= node_type + '[' + name +']';
end;

constructor TConstructor.Create(p:String);
begin
  inherited Create(n_constructor,'');
  poly:=p;
end;

destructor TConstructor.Destroy;
begin
  inherited Destroy;
end;

function TConstructor.to_string: String;
begin
	result:= node_type + ' POLY[' + poly +']';
end;

constructor TFunction.Create(n,p,r:String);
begin
  inherited Create(n_function,n);
  return_type:=r;
  poly:=p;
end;

destructor TFunction.Destroy;
begin
  inherited Destroy;
end;

function TFunction.to_string: String;
begin
	result:= node_type + '[' + name + ']RETURN_TYPE[' + return_type + ']POLY[' + poly +']';
end;

constructor TProc.Create(n,p:String);
begin
  inherited Create(n_procedure,n);
  poly:=p;
end;

destructor TProc.Destroy;
begin
  inherited Destroy;
end;

function TProc.to_string: String;
begin
	result:= node_type + '[' + name + ']POLY[' + poly +']';
end;

constructor TEvent.Create(n:String);
begin
  inherited Create(n_event,n);
end;

destructor TEvent.Destroy;
begin
  inherited Destroy;
end;

function TEvent.to_string: String;
begin
	result:= node_type + '[' + name + ']';
end;

constructor TVariable.Create(n:String);
begin
  inherited Create(n_variable,n);
end;

destructor TVariable.Destroy;
begin
  inherited Destroy;
end;

function TVariable.to_string: String;
begin
	result:= node_type + '[' + name + ']';
end;

constructor TParameter.Create(n:String);
begin
  inherited Create(n_param,n);
end;

destructor TParameter.Destroy;
begin
  inherited Destroy;
end;

function TParameter.to_string: String;
begin
	result:= node_type + '[' + name + ']';
end;

constructor TNew.Create(n:String);
begin
  inherited Create(n_new,n);
end;

destructor TNew.Destroy;
begin
  inherited Destroy;
end;

function TNew.to_string: String;
begin
	result:= node_type + '[' + name + ']';
end;

constructor TExpression.Create(n:String);
begin
  inherited Create(n_expression,n);
end;

destructor TExpression.Destroy;
begin
  inherited Destroy;
end;

function TExpression.to_string: String;
begin
	result:= node_type + '[' + name + ']';
end;

constructor TDEFMethod.Create(n:String);
begin
  inherited Create(n_defmethod,n);
end;

destructor TDEFMethod.Destroy;
begin
  inherited Destroy;
end;

function TDEFMethod.to_string: String;
begin
	result:= node_type + '[' + name + ']';
end;

constructor TMethod.Create(n:String);
begin
  inherited Create(n_method,n);
end;

destructor TMethod.Destroy;
begin
  inherited Destroy;
end;

function TMethod.to_string: String;
begin
	result:= node_type + '[' + name + ']';
end;

constructor TMParameter.Create(n:String);
begin
  inherited Create(n_mparam,n);
end;

destructor TMParameter.Destroy;
begin
  inherited Destroy;
end;

function TMParameter.to_string: String;
begin
	result:= node_type + '[' + name + ']';
end;

{constructor TLock.Create();
begin
  inherited Create(n_lock,'');
end;

destructor TLock.Destroy;
begin
  inherited Destroy;
end;

function TLock.to_string: String;
begin
	result:= node_type ;
end;

constructor TUnLock.Create();
begin
  inherited Create(n_unlock,'');
end;

destructor TUnLock.Destroy;
begin
  inherited Destroy;
end;

function TUnLock.to_string: String;
begin
	result:= node_type ;
end;}

constructor TRun.Create(w:boolean);
begin
  inherited Create(n_run,'');
  _wait:= w;
end;

destructor TRun.Destroy;
begin
  inherited Destroy;
end;

function TRun.to_string: String;
begin
	result:= node_type ;
end;

constructor TReturn.Create();
begin
  inherited Create(n_return,'');
end;

destructor TReturn.Destroy;
begin
  inherited Destroy;
end;

function TReturn.to_string: String;
begin
	result:= node_type ;
end;

constructor TRaise.Create(n:String;w:boolean);
begin
  inherited Create(n_raise,n);
  _wait:= w;
end;

destructor TRaise.Destroy;
begin
  inherited Destroy;
end;

function TRaise.to_string: String;
begin
	result:= node_type + '[' + name + ']';
end;

constructor TState.Create(n:String);
begin
  inherited Create(n_state,n);
end;

destructor TState.Destroy;
begin
  inherited Destroy;
end;

function TState.to_string: String;
begin
	result:= node_type + '[' + name + ']';
end;

constructor TFlow.Create(n:String);
begin
  inherited Create(n_flow,n);
end;

destructor TFlow.Destroy;
begin
  inherited Destroy;
end;

function TFlow.to_string: String;
begin
	result:= node_type + '[' + name + ']';
end;

constructor TAssign.Create(n:String);
begin
  inherited Create(n_assign,n);
end;

destructor TAssign.Destroy;
begin
  inherited Destroy;
end;

function TAssign.to_string: String;
begin
	result:= node_type + '[' + name + ']';
end;

constructor TIf.Create();
begin
  inherited Create(n_if,'');
end;

destructor TIf.Destroy;
begin
  inherited Destroy;
end;

function TIf.to_string: String;
begin
	result:= node_type ;
end;

constructor TElse.Create();
begin
  inherited Create(n_else,'');
end;

destructor TElse.Destroy;
begin
  inherited Destroy;
end;

function TElse.to_string: String;
begin
	result:= node_type ;
end;

constructor TWhile.Create();
begin
  inherited Create(n_while,'');
end;

destructor TWhile.Destroy;
begin
  inherited Destroy;
end;

function TWhile.to_string: String;
begin
	result:= node_type ;
end;

constructor TForto.Create();
begin
  inherited Create(n_forto,'');
end;

destructor TForto.Destroy;
begin
  inherited Destroy;
end;

function TForto.to_string: String;
begin
	result:= node_type ;
end;

constructor TFordownto.Create();
begin
  inherited Create(n_fordownto,'');
end;

destructor TFordownto.Destroy;
begin
  inherited Destroy;
end;

function TFordownto.to_string: String;
begin
	result:= node_type;
end;

constructor TForin.Create(v:String);
begin
  inherited Create(n_forin,'');
  _var:=v;
end;

destructor TForin.Destroy;
begin
  inherited Destroy;
end;

function TForin.to_string: String;
begin
	result:= node_type + '[' + _var + ']';
end;

constructor TBegin.Create();
begin
  inherited Create(n_begin,'');
end;

destructor TBegin.Destroy;
begin
  inherited Destroy;
end;

function TBegin.to_string: String;
begin
	result:= node_type ;
end;

constructor TEnd.Create();
begin
  inherited Create(n_end,'');
end;

destructor TEnd.Destroy;
begin
  inherited Destroy;
end;

function TEnd.to_string: String;
begin
	result:= node_type ;
end;

constructor TLineEnd.Create();
begin
  inherited Create(n_line_end,'');
end;

destructor TLineEnd.Destroy;
begin
  inherited Destroy;
end;

function TLineEnd.to_string: String;
begin
	result:= node_type ;
end;

constructor TFromto.Create(f,t:string);
begin
  inherited Create(n_fromto,'');
  _from := f;
  _to := t;
end;

destructor TFromto.Destroy;
begin
  inherited Destroy;
end;

function TFromto.to_string: String;
begin
	result:= node_type + '[' + _from + ']TO[' + _to + ']';
end;

constructor TCState.Create(n:string);
begin
  inherited Create(n_cstate,n);
end;

destructor TCState.Destroy;
begin
  inherited Destroy;
end;

function TCState.to_string: String;
begin
	result:= node_type + '[' + name + ']';
end;

end.