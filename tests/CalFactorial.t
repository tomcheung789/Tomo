class Factorial
    constructor();
    function fact(i:integer) integer
        res:integer = 1
        while(i>0)
            res := res * i
            i := i-1
        return res
        
program CalFactorial
    fact:Factorial = new Factorial()
    n:integer
    write('Enter a natural number: ')
    read(n)
    while(n<0)
        write('Please re-enter: ')
        read(n)
    writeln(n, '! = ', fact.fact(n))
    
    
