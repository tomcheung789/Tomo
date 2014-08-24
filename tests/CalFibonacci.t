class Fibonacci
	constructor()
		super()
	function fib(i:integer) integer
		pred, res, temp:integer
		pred := 1
		res:=0
		while(i>0)
			temp := pred + res
			res := pred
			pred := temp
			i := i-1
		return res
		
program CalFibonacci
	f:Fibonacci
	f:= new Fibonacci()
	n:integer
	write('Enter a natural number: ')
	read(n)
	while(n<0)
		write('Please re-enter: ')
		read(n)
	write('fib(')
	write(n)
	write(') = ')
	writeln(f.fib(n))
	
	
